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
    case 'bmi':
      return { title: 'BMI Wellness Report', subtitle: 'Body mass index screening' };
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
  } else if (input.mode === 'color_vision') {
    lines.push({ kind: 'heading', text: 'Color vision screening' });
    lines.push({
      kind: 'kv',
      label: 'Result',
      value: input.colorVisionTitle?.trim() || colorVisionOutcomeLabel(input.colorVisionOutcome),
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
  } else {
    lines.push({ kind: 'heading', text: 'Body mass index' });
    lines.push({
      kind: 'kv',
      label: 'BMI',
      value: input.bmiValue == null ? '-' : input.bmiValue.toFixed(1),
    });
    lines.push({
      kind: 'kv',
      label: 'Category',
      value: input.bmiCategory
        ? `${bmiCategoryLabel(input.bmiCategory)} (${bmiCategoryRange(input.bmiCategory)})`
        : '-',
    });
    if (input.bmiHeightCm != null) {
      lines.push({ kind: 'kv', label: 'Height', value: `${input.bmiHeightCm.toFixed(0)} cm` });
    }
    if (input.bmiWeightKg != null) {
      lines.push({ kind: 'kv', label: 'Weight', value: `${input.bmiWeightKg.toFixed(0)} kg` });
    }
    if (input.bmiHeightCm != null) {
      const meters = input.bmiHeightCm / 100;
      const idealMin = 18.5 * meters * meters;
      const idealMax = 24.9 * meters * meters;
      lines.push({
        kind: 'kv',
        label: 'Healthy weight band',
        value: `${Math.round(idealMin)} – ${Math.round(idealMax)} kg for this height`,
      });
    }
    if (input.bmiTitle?.trim()) {
      lines.push({ kind: 'spacer', height: 8 });
      lines.push({ kind: 'muted', text: input.bmiTitle.trim() });
    }
    if (input.bmiSummary?.trim()) {
      lines.push({ kind: 'spacer', height: 6 });
      lines.push({ kind: 'muted', text: input.bmiSummary.trim() });
    }
    lines.push({ kind: 'spacer', height: 10 });
    lines.push({ kind: 'heading', text: 'Adult BMI reference' });
    lines.push({ kind: 'kv', label: 'Underweight', value: 'Below 18.5' });
    lines.push({ kind: 'kv', label: 'Normal', value: '18.5 – 24.9' });
    lines.push({ kind: 'kv', label: 'Overweight', value: '25.0 – 29.9' });
    lines.push({ kind: 'kv', label: 'Obese', value: '30.0 and above' });
    if (input.bmiAdvice?.trim()) {
      lines.push({ kind: 'spacer', height: 8 });
      lines.push({ kind: 'muted', text: input.bmiAdvice.trim() });
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

function colorVisionOutcomeLabel(
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

function bmiCategoryLabel(category: NonNullable<WellBeingPrintBody['bmiCategory']>): string {
  switch (category) {
    case 'underweight':
      return 'Underweight';
    case 'normal':
      return 'Normal';
    case 'overweight':
      return 'Overweight';
    case 'obese':
      return 'Obese';
  }
}

function bmiCategoryRange(category: NonNullable<WellBeingPrintBody['bmiCategory']>): string {
  switch (category) {
    case 'underweight':
      return 'Below 18.5';
    case 'normal':
      return '18.5 – 24.9';
    case 'overweight':
      return '25.0 – 29.9';
    case 'obese':
      return '30.0 and above';
  }
}
