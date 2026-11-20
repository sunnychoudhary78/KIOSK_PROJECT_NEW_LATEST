import { describe, expect, it, beforeEach } from 'vitest';
import { promises as fs } from 'node:fs';
import { isAppError } from '../src/shared/errors.js';
import {
  docxToPdf,
  resetDocxConvertSlotsForTests,
  type DocxExecFile,
} from '../src/modules/printing/docx_to_pdf.js';

const SAMPLE_DOCX = Buffer.from('PK\x03\x04fake-docx-bytes');

beforeEach(() => {
  resetDocxConvertSlotsForTests();
});

describe('docxToPdf', () => {
  it('returns PDF bytes when LibreOffice write succeeds', async () => {
    const execFile: DocxExecFile = async (_bin, args) => {
      const outDirIndex = args.indexOf('--outdir');
      const outDir = args[outDirIndex + 1];
      await fs.writeFile(`${outDir}/input.pdf`, Buffer.from('%PDF-1.4 mock'));
      return { stdout: '', stderr: '' };
    };

    const pdf = await docxToPdf(SAMPLE_DOCX, {
      bin: 'soffice',
      timeoutMs: 5_000,
      maxConcurrent: 2,
      execFile,
    });
    expect(pdf.subarray(0, 5).toString('ascii')).toBe('%PDF-');
  });

  it('maps missing binary to docx_convert_unavailable', async () => {
    const execFile: DocxExecFile = async () => {
      const err = new Error('not found') as NodeJS.ErrnoException;
      err.code = 'ENOENT';
      throw err;
    };

    try {
      await docxToPdf(SAMPLE_DOCX, {
        bin: '/missing/soffice',
        timeoutMs: 5_000,
        maxConcurrent: 1,
        execFile,
      });
      expect.fail('expected AppError');
    } catch (error) {
      expect(isAppError(error)).toBe(true);
      if (isAppError(error)) {
        expect(error.code).toBe('docx_convert_unavailable');
        expect(error.message).toContain('Word conversion is temporarily unavailable');
      }
    }
  });

  it('maps timeout / convert failure to docx_convert_failed', async () => {
    const execFile: DocxExecFile = async () => {
      const err = new Error('killed') as NodeJS.ErrnoException & { killed?: boolean };
      err.killed = true;
      throw err;
    };

    try {
      await docxToPdf(SAMPLE_DOCX, {
        bin: 'soffice',
        timeoutMs: 1,
        maxConcurrent: 1,
        execFile,
      });
      expect.fail('expected AppError');
    } catch (error) {
      expect(isAppError(error)).toBe(true);
      if (isAppError(error)) {
        expect(error.code).toBe('docx_convert_failed');
        expect(error.message).toContain('Could not convert this Word file');
      }
    }
  });

  it('fails when convert output is not a PDF', async () => {
    const execFile: DocxExecFile = async (_bin, args) => {
      const outDirIndex = args.indexOf('--outdir');
      const outDir = args[outDirIndex + 1];
      await fs.writeFile(`${outDir}/input.pdf`, Buffer.from('not-a-pdf'));
      return { stdout: '', stderr: '' };
    };

    try {
      await docxToPdf(SAMPLE_DOCX, {
        bin: 'soffice',
        timeoutMs: 5_000,
        maxConcurrent: 1,
        execFile,
      });
      expect.fail('expected AppError');
    } catch (error) {
      expect(isAppError(error)).toBe(true);
      if (isAppError(error)) {
        expect(error.code).toBe('docx_convert_failed');
      }
    }
  });
});
