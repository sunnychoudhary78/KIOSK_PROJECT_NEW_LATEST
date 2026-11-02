import ExcelJS from 'exceljs';
import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../src/infrastructure/database/prisma.js';
import type { AuditService } from '../src/modules/audit/audit.service.js';
import { SocietyPhonesService } from '../src/modules/society_phones/society_phones.service.js';

function memoryService(initial: string[] = []) {
  const phones = new Set(initial);
  const db = {
    societyPhone: {
      findMany: vi.fn(async (args?: { where?: { phone?: { in?: string[] } } }) => {
        const allowed = args?.where?.phone?.in;
        const rows = [...phones].filter((phone) => !allowed || allowed.includes(phone));
        return rows.map((phone) => ({ phone }));
      }),
      createMany: vi.fn(async (args: { data: Array<{ phone: string }> }) => {
        let count = 0;
        for (const item of args.data) {
          if (phones.has(item.phone)) continue;
          phones.add(item.phone);
          count += 1;
        }
        return { count };
      }),
    },
  };
  const audit = { record: vi.fn(async () => undefined) };
  const service = new SocietyPhonesService(
    db as unknown as DbClient,
    audit as unknown as AuditService,
  );
  return { service, phones };
}

describe('SocietyPhonesService.importFile', () => {
  it('normalizes numbers, skips duplicates, and reports invalid rows', async () => {
    const { service, phones } = memoryService(['+919876543210']);
    const csv = [
      'phone',
      '9999999999',
      '+91 99999 99999',
      '9876543210',
      'not-a-phone',
      '',
    ].join('\n');

    const result = await service.importFile(
      { originalname: 'society.csv', buffer: Buffer.from(csv) },
      'admin-1',
    );

    expect(result.added).toBe(1);
    expect(result.duplicate).toBe(2);
    expect(result.invalidCount).toBe(1);
    expect(result.invalid).toEqual([
      { row: 5, value: 'not-a-phone', reason: 'invalid_phone' },
    ]);
    expect(phones.has('+919999999999')).toBe(true);
    expect(phones.has('+919876543210')).toBe(true);
  });

  it('reads the first worksheet of an xlsx file', async () => {
    const { service, phones } = memoryService();
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('numbers');
    sheet.addRow(['mobile']);
    sheet.addRow([9999999999]);
    const buffer = Buffer.from(await workbook.xlsx.writeBuffer());

    const result = await service.importFile(
      { originalname: 'society.xlsx', buffer },
      'admin-1',
    );

    expect(result.added).toBe(1);
    expect(result.duplicate).toBe(0);
    expect(result.invalidCount).toBe(0);
    expect([...phones]).toEqual(['+919999999999']);
  });

  it('rejects legacy xls files', async () => {
    const { service } = memoryService();
    await expect(
      service.importFile({ originalname: 'society.xls', buffer: Buffer.from('phone') }, 'admin-1'),
    ).rejects.toMatchObject({ code: 'invalid_file' });
  });
});
