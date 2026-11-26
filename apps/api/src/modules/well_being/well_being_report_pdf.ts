import { buildReportPdf, type ReportLine } from '../printing/report_pdf.js';
import type { WellBeingPrintBody } from './well_being.schemas.js';

const HEALTH_DISCLAIMER =
  'This printout is for personal wellness reference only. It is not a medical diagnosis. Seek professional care for health concerns.';

function reportMeta(mode: WellBeingPrintBody['mode']): { title: string; subtitle: string } {
  switch (mode) {
    case 'oxi':
      return { title: 'Health Report', subtitle: 'Heart rate & oxygen saturation' };
    case 'temp':
      return { title: 'Health Report', subtitle: 'Temperature reading' };
    case 'color_vision':
      return { title: 'Color Vision Screening', subtitle: 'Wellness color vision test' };
  }
}

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
  } else if (input.mode === 'temp') {
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
  } else {
    lines.push({ kind: 'heading', text: 'Color vision screening' });
    lines.push({
      kind: 'kv',
      label: 'Result',
      value: input.colorVisionTitle?.trim() || outcomeLabel(input.colorVisionOutcome),
    });
    if (input.colorVisionCorrectCount != null && input.colorVisionTotalPlates != null) {
      lines.push({
        kind: 'kv',
        label: 'Score',
        value: `${input.colorVisionCorrectCount} / ${input.colorVisionTotalPlates} plates correct`,
      });
    }
    if (input.colorVisionSummary?.trim()) {
      lines.push({ kind: 'spacer', height: 8 });
      lines.push({ kind: 'muted', text: input.colorVisionSummary.trim() });
    }
    if (input.colorVisionAdvice?.trim()) {
      lines.push({ kind: 'spacer', height: 6 });
      lines.push({ kind: 'muted', text: input.colorVisionAdvice.trim() });
    }
  }

  lines.push({ kind: 'spacer', height: 12 });
  lines.push({
    kind: 'muted',
    text: `Measured at ${measuredAt.toISOString().replace('T', ' ').slice(0, 19)} UTC`,
  });

  const meta = reportMeta(input.mode);
  return buildReportPdf({
    title: meta.title,
    subtitle: meta.subtitle,
    lines,
    disclaimer: HEALTH_DISCLAIMER,
    generatedAt: measuredAt,
  });
}

function outcomeLabel(
  outcome: WellBeingPrintBody['colorVisionOutcome'],
): string {
  switch (outcome) {
    case 'normal':
      return 'Normal screening result';
    case 'possible_deficiency':
      return 'Possible color vision deficiency';
    case 'inconclusive':
      return 'Inconclusive screening';
    default:
      return 'Screening complete';
  }
}
