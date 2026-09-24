import { OtpChallengeStatus } from '@prisma/client';
import { describe, expect, it } from 'vitest';
import { quoteOtpPrintPages } from '../src/modules/otp_print/otp_print.quote.js';
import { OtpPrintService } from '../src/modules/otp_print/otp_print.service.js';

describe('OTP is deferred until payment for extra pages', () => {
  it('requires payment (and therefore no OTP) when extra pages exist', () => {
    const quote = quoteOtpPrintPages(8, {
      freePagesPerSession: 5,
      extraPageChargeRupees: 10,
      freeColorPagesPerSession: 0,
      extraColorPageChargeRupees: 20,
    });
    expect(quote.paymentRequired).toBe(true);
  });

  it('maps awaiting_payment challenges as unpaid with otpSent false', () => {
    const service = Object.create(OtpPrintService.prototype) as OtpPrintService;
    const quote = quoteOtpPrintPages(8, {
      freePagesPerSession: 5,
      extraPageChargeRupees: 10,
      freeColorPagesPerSession: 0,
      extraColorPageChargeRupees: 20,
    });
    const expiresAt = new Date('2026-08-26T12:00:00.000Z');
    const publicChallenge = service.toPublicChallenge(
      {
        id: '11111111-1111-1111-1111-111111111111',
        userId: '22222222-2222-2222-2222-222222222222',
        codeHash: null,
        codeHint: null,
        documentLabel: 'Certificates',
        pageCount: 8,
        printColorMode: 'bw',
        attemptCount: 0,
        status: OtpChallengeStatus.awaiting_payment,
        expiresAt,
        redeemedAt: null,
        deviceId: null,
        printJobId: null,
        createdAt: expiresAt,
        updatedAt: expiresAt,
        documents: [
          {
            id: '33333333-3333-3333-3333-333333333333',
            challengeId: '11111111-1111-1111-1111-111111111111',
            fileName: 'a.pdf',
            storagePath: '/tmp/a.pdf',
            contentType: 'application/pdf',
            pageCount: 8,
            byteSize: 100,
            sortOrder: 0,
            createdAt: expiresAt,
          },
        ],
        payment: null,
      },
      quote,
    );

    expect(publicChallenge.paymentRequired).toBe(true);
    expect(publicChallenge.otpSent).toBe(false);
    expect(publicChallenge.status).toBe('awaiting_payment');
  });

  it('is idempotent in the public mapping once OTP is pending', () => {
    const service = Object.create(OtpPrintService.prototype) as OtpPrintService;
    const quote = quoteOtpPrintPages(8, {
      freePagesPerSession: 5,
      extraPageChargeRupees: 10,
      freeColorPagesPerSession: 0,
      extraColorPageChargeRupees: 20,
    });
    const expiresAt = new Date('2026-08-26T12:00:00.000Z');
    const publicChallenge = service.toPublicChallenge(
      {
        id: '11111111-1111-1111-1111-111111111111',
        userId: '22222222-2222-2222-2222-222222222222',
        codeHash: 'abc',
        codeHint: '12',
        documentLabel: 'Certificates',
        pageCount: 8,
        printColorMode: 'bw',
        attemptCount: 0,
        status: OtpChallengeStatus.pending,
        expiresAt,
        redeemedAt: null,
        deviceId: null,
        printJobId: null,
        createdAt: expiresAt,
        updatedAt: expiresAt,
        documents: [],
        payment: null,
      },
      quote,
    );

    expect(publicChallenge.otpSent).toBe(true);
    expect(publicChallenge.paymentRequired).toBe(false);
  });
});
