import { describe, expect, it } from 'vitest';
import {
  EAADHAAR_SYNTHETIC_URI,
  buildSimpleTextPdf,
  eaadhaarXmlToPdf,
  looksLikeAadhaarDoc,
  parseEaadhaarXmlFields,
} from '../src/infrastructure/external/digilocker.eaadhaar.js';

describe('digilocker eaadhaar helpers', () => {
  it('detects aadhaar-like documents', () => {
    expect(looksLikeAadhaarDoc({ name: 'Aadhaar Card' })).toBe(true);
    expect(looksLikeAadhaarDoc({ doctype: 'ADHAR' })).toBe(true);
    expect(looksLikeAadhaarDoc({ name: 'Driving Licence', doctype: 'DRVLC' })).toBe(false);
  });

  it('parses eaadhaar xml attributes and builds a pdf', () => {
    const xml = `<KycRes><Poi name="Test User" dob="01011990" gender="M" /><Poa house="12" vtc="City" state="ST" pc="110001" /></KycRes>`;
    const fields = parseEaadhaarXmlFields(xml);
    expect(fields.name).toBe('Test User');
    expect(fields.dob).toBe('01011990');
    expect(fields.address).toContain('City');

    const pdf = eaadhaarXmlToPdf(xml);
    expect(pdf.subarray(0, 5).toString('utf8')).toBe('%PDF-');
    expect(EAADHAAR_SYNTHETIC_URI).toBe('eaadhaar:xml');
  });

  it('builds a minimal text pdf', () => {
    const pdf = buildSimpleTextPdf('Title', ['Line 1', 'Line 2']);
    expect(pdf.includes(Buffer.from('%PDF-'))).toBe(true);
  });
});
