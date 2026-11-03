import { buildReportPdf, type ReportLine } from '../printing/report_pdf.js';
import type { WellBeingPrintBody } from './well_being.schemas.js';

const HEALTH_DISCLAIMER =
  'This printout is for personal wellness reference only. It is not a medical diagnosis. Seek professional care for health concerns.';

export async function buildHealthReportPdf(input: WellBeingPrintBody): Promise<Buffer> {
  const lines: ReportLine[] = [];
  const measuredAt = input.measuredAt ? new Date(input.measuredAt) : new Date();

  if (input.mode === 'oxi') {
    lines.push({ kind: 'heading', text: 'Pulse oximetry' });
    lines.push({
      kind: 'kv',
      label: 'Heart rate',
      value:
        input.heartRate == null
          ? '-'
          : `${Math.round(input.heartRate)} BPM${input.heartRateInterpretation ? ` | ${input.heartRateInterpretation}` : ''}`,
    });
    lines.push({
      kind: 'kv',
      label: 'SpO2',
      value:
        input.spo2 == null
          ? '-'
          : `${Math.round(input.spo2)}%${input.spo2Interpretation ? ` | ${input.spo2Interpretation}` : ''}`,
    });
  } else {
    lines.push({ kind: 'heading', text: 'Body temperature' });
    lines.push({
      kind: 'kv',
      label: 'Temperature',
      value:
        input.tempC == null
          ? '-'
          : `${input.tempC.toFixed(1)} deg C${
              input.tempF != null ? ` (${input.tempF.toFixed(1)} deg F)` : ''
            }${input.temperatureInterpretation ? ` | ${input.temperatureInterpretation}` : ''}`,
    });
  }

  lines.push({ kind: 'spacer', height: 12 });
  lines.push({
    kind: 'muted',
    text: `Measured at ${measuredAt.toISOString().replace('T', ' ').slice(0, 19)} UTC`,
  });

  return buildReportPdf({
    title: 'Health Report',
    subtitle: input.mode === 'oxi' ? 'Heart rate & oxygen saturation' : 'Temperature reading',
    lines,
    disclaimer: HEALTH_DISCLAIMER,
    generatedAt: measuredAt,
  });
}
