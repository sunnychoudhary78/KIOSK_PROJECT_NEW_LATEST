import { describe, expect, it } from 'vitest';
import {
  resolvePrinterErrorHistory,
  resolvePrinterMaintenance,
} from '../../admin/src/features/kiosks/printerMaintenance.ts';

const verified = {
  snmpOk: true,
  lastSuccessAt: '2026-10-26T12:00:00.000Z',
  maintenance: {
    available: true,
    toner: { blackPercent: 90, cyanPercent: 100, magentaPercent: 100, yellowPercent: 100 },
    pages: { total: 64, color: 47, blackAndWhite: 17 },
    parts: { beltRemainingPages: 49882, fuserRemainingPages: 49936 },
  },
};

describe('admin printer maintenance display', () => {
  it('shows unavailable when maintenance was not read', () => {
    expect(resolvePrinterMaintenance(null)).toEqual({ status: 'unavailable' });
    expect(resolvePrinterMaintenance({})).toEqual({ status: 'unavailable' });
    expect(
      resolvePrinterMaintenance({
        snmpOk: false,
        maintenance: { available: false },
      }),
    ).toEqual({ status: 'unavailable' });
  });

  it('keeps the last numbers and marks them stale when SNMP is down', () => {
    const display = resolvePrinterMaintenance({
      ...verified,
      snmpOk: false,
    });
    expect(display.status).toBe('stale');
    if (display.status === 'stale') {
      expect(display.title).toContain('Last successful SNMP poll');
      expect(display.toner.black).toBe('90%');
      expect(display.pages.total).toBe((64).toLocaleString());
      expect(display.parts.belt).toBe((49882).toLocaleString());
    }
  });

  it('renders a reported zero and leaves a missing metric blank', () => {
    const display = resolvePrinterMaintenance({
      snmpOk: true,
      maintenance: {
        available: true,
        toner: { blackPercent: 0 },
        pages: { total: 0, color: 47 },
        parts: { fuserRemainingPages: 0 },
      },
    });
    expect(display.status).toBe('current');
    if (display.status === 'current') {
      expect(display.toner.black).toBe('0%');
      expect(display.toner.cyan).toBe('—');
      expect(display.pages.total).toBe('0');
      expect(display.pages.blackAndWhite).toBe('—');
      expect(display.parts.belt).toBe('—');
      expect(display.parts.fuser).toBe('0');
    }
  });

  it('does not show an out-of-range percent as a toner level', () => {
    const display = resolvePrinterMaintenance({
      snmpOk: true,
      maintenance: {
        available: true,
        toner: { blackPercent: 101, cyanPercent: 90.5 },
      },
    });
    expect(display.status).toBe('current');
    if (display.status === 'current') {
      expect(display.toner.black).toBe('—');
      expect(display.toner.cyan).toBe('—');
    }
  });
});

describe('admin printer error history display', () => {
  it('shows unavailable when the walk has not succeeded', () => {
    expect(resolvePrinterErrorHistory(null)).toEqual({ status: 'unavailable' });
    expect(resolvePrinterErrorHistory({ errorHistory: { available: false } })).toEqual({
      status: 'unavailable',
    });
  });

  it('shows an empty successful walk instead of inventing errors', () => {
    expect(
      resolvePrinterErrorHistory({
        snmpOk: true,
        errorHistory: { available: true, entries: [] },
      }),
    ).toEqual({ status: 'empty' });
  });

  it('shows the one non-empty description', () => {
    const display = resolvePrinterErrorHistory({
      snmpOk: true,
      errorHistory: {
        available: true,
        entries: [{ index: 1, description: 'Cannot Print ZC' }],
      },
    });
    expect(display).toEqual({
      status: 'current',
      entries: [{ index: 1, description: 'Cannot Print ZC' }],
    });
  });

  it('marks a previous error list stale when SNMP is down', () => {
    const display = resolvePrinterErrorHistory({
      snmpOk: false,
      lastSuccessAt: '2026-10-26T12:00:00.000Z',
      errorHistory: {
        available: true,
        entries: [{ index: 1, description: 'Cannot Print ZC' }],
      },
    });
    expect(display.status).toBe('stale');
    if (display.status === 'stale') {
      expect(display.entries).toEqual([{ index: 1, description: 'Cannot Print ZC' }]);
      expect(display.title).toContain('Last successful SNMP poll');
    }
  });
});