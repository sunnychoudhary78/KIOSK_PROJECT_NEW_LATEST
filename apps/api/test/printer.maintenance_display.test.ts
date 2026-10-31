import { describe, expect, it } from 'vitest';
import {
  resolvePrinterErrorHistory,
  resolvePrinterMaintenance,
  resolvePrinterRowSummary,
  resolvePrinterStatus,
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
      expect(display.title).toContain('Last successful printer poll');
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
      expect(display.title).toContain('Last successful printer poll');
    }
  });
});

describe('admin printer row summary', () => {
  it('shows unavailable when neither block was read', () => {
    expect(resolvePrinterRowSummary(null)).toEqual({ label: 'Unavailable', tone: 'muted' });
    expect(resolvePrinterRowSummary({})).toEqual({ label: 'Unavailable', tone: 'muted' });
  });

  it('shows OK when maintenance is current and there are no recorded errors', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        errorHistory: { available: true, entries: [] },
      }),
    ).toEqual({ label: 'OK', tone: 'ok' });
  });

  it('shows Stale when SNMP is down and no errors are recorded', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        snmpOk: false,
        errorHistory: { available: true, entries: [] },
      }),
    ).toEqual({ label: 'Stale', tone: 'amber' });
  });

  it('counts recorded errors and keeps a stale list amber', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        errorHistory: {
          available: true,
          entries: [{ index: 1, description: 'Cannot Print ZC' }],
        },
      }),
    ).toEqual({ label: '1 error', tone: 'alert' });
    expect(
      resolvePrinterRowSummary({
        ...verified,
        snmpOk: false,
        errorHistory: {
          available: true,
          entries: [
            { index: 1, description: 'Cannot Print ZC' },
            { index: 2, description: 'Paper jam' },
          ],
        },
      }),
    ).toEqual({ label: '2 errors', tone: 'amber' });
  });

  it('shows Ready instead of OK when the printer is idle', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        state: 'ready',
        errorHistory: { available: true, entries: [] },
      }),
    ).toEqual({ label: 'Ready', tone: 'ok' });
    expect(resolvePrinterStatus({ state: 'printing' })).toEqual({
      label: 'Printing',
      kind: 'printing',
      fault: false,
    });
  });

  it('shows Out of paper ahead of a recorded error', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        state: 'paper_out',
        errorHistory: {
          available: true,
          entries: [{ index: 1, description: 'Cannot Print ZC' }],
        },
      }),
    ).toEqual({ label: 'Out of paper', tone: 'alert' });
  });

  it('keeps a fault amber when the sample is stale', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        state: 'paper_out',
        snmpOk: false,
        errorHistory: { available: true, entries: [] },
      }),
    ).toEqual({ label: 'Out of paper', tone: 'amber' });
  });

  it('leaves the summary unchanged when state is missing', () => {
    expect(
      resolvePrinterRowSummary({
        ...verified,
        errorHistory: { available: true, entries: [] },
      }),
    ).toEqual({ label: 'OK', tone: 'ok' });
    expect(resolvePrinterStatus({})).toEqual({
      label: 'Unavailable',
      kind: 'unavailable',
      fault: false,
    });
    expect(resolvePrinterStatus({ state: 'unknown' })).toEqual({
      label: 'Unavailable',
      kind: 'unavailable',
      fault: false,
    });
  });
});