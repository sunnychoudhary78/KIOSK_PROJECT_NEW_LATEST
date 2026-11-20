import { execFile as nodeExecFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promises as fs } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { AppError } from '../../shared/errors.js';

const defaultExecFile = promisify(nodeExecFile);

export type DocxExecFile = (
  file: string,
  args: readonly string[],
  options: { timeout: number; maxBuffer: number },
) => Promise<{ stdout: string | Buffer; stderr: string | Buffer }>;

export type DocxConvertOptions = {
  bin: string;
  timeoutMs: number;
  maxConcurrent: number;
  /** Injectable for tests. */
  execFile?: DocxExecFile;
};

let activeConverts = 0;
const waitQueue: Array<() => void> = [];

async function withConvertSlot<T>(maxConcurrent: number, fn: () => Promise<T>): Promise<T> {
  const limit = Math.max(1, maxConcurrent);
  if (activeConverts >= limit) {
    await new Promise<void>((resolve) => {
      waitQueue.push(resolve);
    });
  }
  activeConverts += 1;
  try {
    return await fn();
  } finally {
    activeConverts -= 1;
    const next = waitQueue.shift();
    next?.();
  }
}

/** Reset in-process convert slot state (tests only). */
export function resetDocxConvertSlotsForTests(): void {
  activeConverts = 0;
  waitQueue.length = 0;
}

/**
 * Convert a .docx buffer to PDF via LibreOffice headless.
 * Always cleans the temp working directory.
 */
export async function docxToPdf(
  bytes: Buffer | Uint8Array,
  options: DocxConvertOptions,
): Promise<Buffer> {
  const input = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
  if (input.length === 0) {
    throw new AppError('invalid_file_type', 'Empty file', 400);
  }

  return withConvertSlot(options.maxConcurrent, async () => {
    const workDir = join(tmpdir(), `skp-docx-${randomUUID()}`);
    const inputPath = join(workDir, 'input.docx');
    const execFile = options.execFile ?? defaultExecFile;

    try {
      await fs.mkdir(workDir, { recursive: true });
      await fs.writeFile(inputPath, input);

      try {
        await execFile(
          options.bin,
          [
            '--headless',
            '--nologo',
            '--nofirststartwizard',
            '--convert-to',
            'pdf',
            '--outdir',
            workDir,
            inputPath,
          ],
          {
            timeout: options.timeoutMs,
            maxBuffer: 16 * 1024 * 1024,
          },
        );
      } catch (error) {
        const err = error as NodeJS.ErrnoException & { killed?: boolean; code?: string | number };
        if (err.code === 'ENOENT') {
          throw new AppError(
            'docx_convert_unavailable',
            'Word conversion is temporarily unavailable. Upload a PDF instead.',
            503,
          );
        }
        if (err.killed || err.code === 'ETIMEDOUT') {
          throw new AppError(
            'docx_convert_failed',
            'Could not convert this Word file. Try exporting to PDF.',
            400,
          );
        }
        throw new AppError(
          'docx_convert_failed',
          'Could not convert this Word file. Try exporting to PDF.',
          400,
        );
      }

      const pdfPath = join(workDir, 'input.pdf');
      let pdfBytes: Buffer;
      try {
        pdfBytes = await fs.readFile(pdfPath);
      } catch {
        throw new AppError(
          'docx_convert_failed',
          'Could not convert this Word file. Try exporting to PDF.',
          400,
        );
      }

      if (pdfBytes.length < 5 || pdfBytes.subarray(0, 5).toString('ascii') !== '%PDF-') {
        throw new AppError(
          'docx_convert_failed',
          'Could not convert this Word file. Try exporting to PDF.',
          400,
        );
      }

      return pdfBytes;
    } finally {
      await fs.rm(workDir, { recursive: true, force: true }).catch(() => undefined);
    }
  });
}
