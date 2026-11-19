import { PDFDocument } from 'pdf-lib';

export function isPdf(file: File): boolean {
  const name = file.name.toLowerCase();
  const type = file.type.toLowerCase();
  return type === 'application/pdf' || name.endsWith('.pdf');
}

export function isImage(file: File): boolean {
  const name = file.name.toLowerCase();
  const type = file.type.toLowerCase();
  return (
    type === 'image/jpeg' ||
    type === 'image/png' ||
    name.endsWith('.jpg') ||
    name.endsWith('.jpeg') ||
    name.endsWith('.png')
  );
}

/** Client-side page count for upload preview. Images are 1 page. */
export async function countUploadPages(file: File): Promise<number> {
  if (isImage(file)) {
    return 1;
  }
  if (!isPdf(file)) {
    throw new Error('Unsupported file type');
  }
  const bytes = await file.arrayBuffer();
  const doc = await PDFDocument.load(bytes, { ignoreEncryption: true });
  const pages = doc.getPageCount();
  if (!Number.isFinite(pages) || pages < 1) {
    throw new Error('Could not read page count');
  }
  return pages;
}
