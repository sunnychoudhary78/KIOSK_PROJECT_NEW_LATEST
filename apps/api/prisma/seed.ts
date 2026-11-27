import {
  DeviceStatus,
  PrismaClient,
  SupportQueryStatus,
  SupportResolution,
  UserRole,
} from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

/** Fake contacts / geo / support tickets — never for staging or production. */
function allowLocalDemoData(): boolean {
  const env = process.env.SKP_NODE_ENV ?? 'local';
  return env === 'local' || env === 'dev' || env === 'test';
}

async function main() {
  const seedLocalDemo = allowLocalDemoData();
  if (!seedLocalDemo) {
    console.info(
      `Skipping local-only demo data (SKP_NODE_ENV=${process.env.SKP_NODE_ENV ?? 'unset'}).`,
    );
  }

  const tenant = await prisma.tenant.upsert({
    where: { code: 'default' },
    update: {},
    create: {
      name: 'Default Operator',
      code: 'default',
    },
  });

  const site = await prisma.site.findFirst({
    where: { tenantId: tenant.id, name: 'Demo Site' },
  });

  const ensuredSite =
    site ??
    (await prisma.site.create({
      data: {
        tenantId: tenant.id,
        name: 'Demo Site',
      },
    }));

  const demoDeviceSecret = 'DemoDeviceSecret@12345';
  const demoDeviceSecretHash = await bcrypt.hash(demoDeviceSecret, 10);
  const demoDevice = await prisma.device.upsert({
    where: { deviceKey: 'demo-kiosk-lobby' },
    update: {
      name: 'Demo Kiosk — Lobby',
      status: DeviceStatus.active,
      deviceSecret: demoDeviceSecret,
      deviceSecretHash: demoDeviceSecretHash,
      ...(seedLocalDemo
        ? {
            latitude: 28.606,
            longitude: 77.43,
            address: 'Gaur City 2, Greater Noida West',
          }
        : {}),
    },
    create: {
      tenantId: tenant.id,
      siteId: ensuredSite.id,
      name: 'Demo Kiosk — Lobby',
      deviceKey: 'demo-kiosk-lobby',
      deviceSecretHash: demoDeviceSecretHash,
      deviceSecret: demoDeviceSecret,
      status: DeviceStatus.active,
      ...(seedLocalDemo
        ? {
            latitude: 28.606,
            longitude: 77.43,
            address: 'Gaur City 2, Greater Noida West',
          }
        : {}),
    },
  });

  const adminHash = await bcrypt.hash('Admin@12345', 10);
  const citizenHash = await bcrypt.hash('Citizen@12345', 10);

  await prisma.user.upsert({
    where: { email: 'admin@smartkiosk.local' },
    update: {},
    create: {
      email: 'admin@smartkiosk.local',
      displayName: 'Platform Admin',
      passwordHash: adminHash,
      role: UserRole.admin,
      tenantId: tenant.id,
    },
  });

  await prisma.user.upsert({
    where: { phone: '+919999999999' },
    update: {},
    create: {
      phone: '+919999999999',
      displayName: 'Demo Citizen',
      passwordHash: citizenHash,
      role: UserRole.citizen,
      tenantId: tenant.id,
    },
  });

  for (const service of [
    {
      code: 'print',
      name: 'Print Documents',
      description: 'Phone, OTP, or DigiLocker printing on the kiosk home screen',
    },
    {
      code: 'otp_print',
      name: 'OTP Print',
      description: 'Print documents using OTP from the mobile app',
    },
    {
      code: 'digilocker_print',
      name: 'DigiLocker Print',
      description: 'Access DigiLocker and print documents from the kiosk',
    },
    {
      code: 'quick_print',
      name: 'Quick Print',
      description: 'Scan a QR on the kiosk and upload documents from a phone browser',
    },
    {
      code: 'astrology',
      name: 'Astrology & Palm Reading',
      description: 'Vedic chart plus palm reading from the kiosk camera',
    },
    {
      code: 'fuel_stations',
      name: 'Fuel stations',
      description: 'Nearby petrol, diesel, CNG, and EV stations',
    },
    {
      code: 'local_services',
      name: 'Find Services',
      description: 'Local trades and contacts shown on the kiosk Find Services screen',
    },
    {
      code: 'well_being',
      name: 'Well Being',
      description: 'Heart rate, blood oxygen, and temperature on the kiosk',
    },
    {
      code: 'phone_charging',
      name: 'Phone Charging',
      description: 'Phone charging session on the kiosk',
    },
  ]) {
    await prisma.platformService.upsert({
      where: { code: service.code },
      update: {
        name: service.name,
        description: service.description,
        isActive: true,
      },
      create: service,
    });
  }

  const homeServiceCodes = [
    'print',
    'otp_print',
    'digilocker_print',
    'quick_print',
    'astrology',
    'fuel_stations',
    'local_services',
    'well_being',
    'phone_charging',
  ];
  const homeServices = await prisma.platformService.findMany({
    where: { code: { in: homeServiceCodes } },
    select: { id: true, code: true },
  });
  if (homeServices.length) {
    const devices = await prisma.device.findMany({ select: { id: true, tenantId: true } });
    for (const device of devices) {
      for (const home of homeServices) {
        await prisma.serviceEnablement.upsert({
          where: {
            deviceId_serviceId: {
              deviceId: device.id,
              serviceId: home.id,
            },
          },
          update: {},
          create: {
            tenantId: device.tenantId,
            deviceId: device.id,
            serviceId: home.id,
            enabled: true,
          },
        });
      }
    }
  }

  await prisma.platformSetting.upsert({
    where: { settingKey: 'otp_print_config' },
    update: {},
    create: {
      settingKey: 'otp_print_config',
      description: 'OTP print challenge limits and TTL',
      settingValue: {
        ttlSeconds: 1800,
        otpLength: 6,
        maxDocumentsPerSession: 5,
        maxVerifyAttempts: 5,
        maxFileSizeMb: 15,
      },
    },
  });

  await prisma.platformSetting.upsert({
    where: { settingKey: 'quick_print_config' },
    update: {},
    create: {
      settingKey: 'quick_print_config',
      description: 'Walk-up Quick Print session TTL',
      settingValue: {
        ttlSeconds: 600,
      },
    },
  });

  await prisma.platformSetting.upsert({
    where: { settingKey: 'citizen_auth_config' },
    update: {},
    create: {
      settingKey: 'citizen_auth_config',
      description: 'Citizen phone OTP login settings',
      settingValue: {
        ttlSeconds: 300,
        otpLength: 6,
        maxVerifyAttempts: 5,
        requestCooldownSeconds: 60,
      },
    },
  });

  await prisma.platformSetting.upsert({
    where: { settingKey: 'print_free_quota_config' },
    update: {},
    create: {
      settingKey: 'print_free_quota_config',
      description: 'Global per-phone free print page quota',
      settingValue: {
        period: 'daily',
        freeBwPages: 5,
        freeColorPages: 0,
      },
    },
  });

  await prisma.platformSetting.upsert({
    where: { settingKey: 'society_free_quota_config' },
    update: {},
    create: {
      settingKey: 'society_free_quota_config',
      description: 'Combined free print pages (B/W + color) for phones on the society list',
      settingValue: {
        period: 'daily',
        freePages: 5,
        freeBwPages: 5,
        freeColorPages: 5,
        combined: true,
      },
    },
  });

  await prisma.platformSetting.upsert({
    where: { settingKey: 'ads_config' },
    update: {},
    create: {
      settingKey: 'ads_config',
      description: 'Global idle ad attract delay for all kiosks',
      settingValue: {
        idleTimeoutSeconds: 18,
      },
    },
  });

  const existingAdvertiser = await prisma.advertiser.findFirst({
    where: { tenantId: tenant.id, name: 'Demo Advertiser' },
  });
  if (!existingAdvertiser) {
    await prisma.advertiser.create({
      data: {
        tenantId: tenant.id,
        name: 'Demo Advertiser',
        contactEmail: 'ads@example.com',
      },
    });
  }

  const demoSupportCount = seedLocalDemo
    ? await prisma.supportQuery.count({
        where: {
          deviceId: demoDevice.id,
          message: { startsWith: '[Demo]' },
        },
      })
    : 1;
  if (seedLocalDemo && demoSupportCount === 0) {
    const now = Date.now();
    const minutesAgo = (mins: number) => new Date(now - mins * 60_000);

    await prisma.supportQuery.createMany({
      data: [
        {
          deviceId: demoDevice.id,
          category: 'print',
          phone: '9876543210',
          message: '[Demo] Paper jammed after the third page. Need help clearing the tray.',
          amountPaise: 0,
          status: SupportQueryStatus.open,
          createdAt: minutesAgo(12),
        },
        {
          deviceId: demoDevice.id,
          category: 'payment',
          phone: '9123456789',
          message: '[Demo] Payment succeeded on my phone but the kiosk still shows pending.',
          amountPaise: 2000,
          razorpayOrderId: 'order_demo_support_pay_001',
          paymentReference: 'pay_demo_ref_001',
          failureReason: 'UI still pending after webhook',
          status: SupportQueryStatus.open,
          createdAt: minutesAgo(45),
        },
        {
          deviceId: demoDevice.id,
          category: 'charging',
          phone: '9988776655',
          message: '[Demo] Charging bay B is powered but my phone never starts charging.',
          amountPaise: 0,
          status: SupportQueryStatus.open,
          createdAt: minutesAgo(90),
        },
        {
          deviceId: demoDevice.id,
          category: 'sensors',
          phone: '9012345678',
          message: '[Demo] Motion sensor keeps beeping even when the lobby is empty.',
          amountPaise: 0,
          status: SupportQueryStatus.resolved,
          resolution: SupportResolution.no_action,
          createdAt: minutesAgo(180),
          resolvedAt: minutesAgo(120),
        },
        {
          deviceId: demoDevice.id,
          category: 'other',
          phone: '9765432109',
          message: '[Demo] Screen brightness is too low to read the receipt instructions.',
          amountPaise: 0,
          status: SupportQueryStatus.resolved,
          resolution: SupportResolution.no_action,
          createdAt: minutesAgo(360),
          resolvedAt: minutesAgo(300),
        },
      ],
    });
  }

  if (seedLocalDemo) {
    const astrologyDemoContacts = [
      {
        id: 'b0000000-0000-4000-8000-000000000001',
        kind: 'astrologer' as const,
        name: 'Acharya Rahul Sharma',
        phone: '9876543210',
        rating: 5,
        sortOrder: 1,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000002',
        kind: 'astrologer' as const,
        name: 'Pandit Amit Joshi',
        phone: '9876501234',
        rating: 4.5,
        sortOrder: 2,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000003',
        kind: 'astrologer' as const,
        name: 'Acharya Vikram Mishra',
        phone: '9876512345',
        rating: 4.5,
        sortOrder: 3,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000004',
        kind: 'astrologer' as const,
        name: 'Pandit Rohan Tiwari',
        phone: '9876523456',
        rating: 4,
        sortOrder: 4,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000005',
        kind: 'astrologer' as const,
        name: 'Acharya Suresh Pandey',
        phone: '9876534567',
        rating: 4,
        sortOrder: 5,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000006',
        kind: 'astrologer' as const,
        name: 'Jyotish Neha Verma',
        phone: '9876556789',
        rating: 4.8,
        sortOrder: 6,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000007',
        kind: 'pandit' as const,
        name: 'Pandit Mohan Shastri',
        phone: '9876501234',
        rating: 5,
        sortOrder: 1,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000008',
        kind: 'pandit' as const,
        name: 'Pandit Rajesh Tiwari',
        phone: '9876512345',
        rating: 4.5,
        sortOrder: 2,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000009',
        kind: 'pandit' as const,
        name: 'Pandit Sunil Sharma',
        phone: '9876523456',
        rating: 4.5,
        sortOrder: 3,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000010',
        kind: 'pandit' as const,
        name: 'Pandit Anil Tripathi',
        phone: '9876534567',
        rating: 4,
        sortOrder: 4,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000011',
        kind: 'pandit' as const,
        name: 'Pandit Deepak Mishra',
        phone: '9876545678',
        rating: 4,
        sortOrder: 5,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000012',
        kind: 'pandit' as const,
        name: 'Pandit Ramesh Dubey',
        phone: '9876567890',
        rating: 3.5,
        sortOrder: 6,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000013',
        kind: 'numerology' as const,
        name: 'Numerologist Kavita Rao',
        phone: '9876601234',
        rating: 5,
        sortOrder: 1,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000014',
        kind: 'numerology' as const,
        name: 'Acharya Manish Gupta',
        phone: '9876612345',
        rating: 4.5,
        sortOrder: 2,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000015',
        kind: 'numerology' as const,
        name: 'Jyotish Priya Nair',
        phone: '9876623456',
        rating: 4.5,
        sortOrder: 3,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000016',
        kind: 'numerology' as const,
        name: 'Numerologist Arjun Mehta',
        phone: '9876634567',
        rating: 4,
        sortOrder: 4,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000017',
        kind: 'numerology' as const,
        name: 'Guru Seema Kapoor',
        phone: '9876645678',
        rating: 4,
        sortOrder: 5,
      },
      {
        id: 'b0000000-0000-4000-8000-000000000018',
        kind: 'numerology' as const,
        name: 'Numerologist Vivek Shah',
        phone: '9876656789',
        rating: 3.5,
        sortOrder: 6,
      },
    ];

    for (const contact of astrologyDemoContacts) {
      await prisma.astrologyContact.upsert({
        where: { id: contact.id },
        update: {
          kind: contact.kind,
          name: contact.name,
          phone: contact.phone,
          rating: contact.rating,
          sortOrder: contact.sortOrder,
        },
        create: contact,
      });
    }

    // Find Services demo Top 5 / rating / geo cluster (Gaur City area).
    const localServiceDemoEnrich = [
      {
        id: 'c0000000-0000-4000-8000-000000000005',
        topRank: 1,
        rating: 4.0,
        address: 'Shop 14, Gaur City 2 Market',
        latitude: 28.6285,
        longitude: 77.43,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000006',
        topRank: 2,
        rating: 3.5,
        address: 'Near Hajipur Crossing',
        latitude: 28.64,
        longitude: 77.43,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000001',
        topRank: null,
        rating: 3.0,
        address: 'Gaur City 1, Tower 5 area',
        latitude: 28.609,
        longitude: 77.43,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000003',
        topRank: null,
        rating: 4.8,
        address: 'Sector 16C, Noida Extension',
        latitude: 28.614,
        longitude: 77.43,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000004',
        topRank: null,
        rating: 4.9,
        address: 'Main Market, Chiranjiv Vihar',
        latitude: 28.6195,
        longitude: 77.43,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000002',
        topRank: null,
        rating: 4.2,
        address: 'Opp. Gaur City Mall',
        latitude: 28.622,
        longitude: 77.432,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000007',
        topRank: null,
        rating: 2.5,
        address: 'Bisrakh Road workshop',
        latitude: 28.635,
        longitude: 77.43,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000110',
        topRank: 1,
        rating: 4.7,
        address: 'Gaur City 2 plumbing hub',
        latitude: 28.6105,
        longitude: 77.4285,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000111',
        topRank: null,
        rating: 4.5,
        address: 'Sector 4, Greater Noida West',
        latitude: 28.612,
        longitude: 77.431,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000112',
        topRank: null,
        rating: 3.8,
        address: 'Near City Park',
        latitude: 28.618,
        longitude: 77.429,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000056',
        topRank: 1,
        rating: 4.6,
        address: 'Electrical mart, GC-2',
        latitude: 28.611,
        longitude: 77.4295,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000057',
        topRank: null,
        rating: 4.3,
        address: 'Tower circle shop',
        latitude: 28.6075,
        longitude: 77.4305,
      },
      {
        id: 'c0000000-0000-4000-8000-000000000058',
        topRank: null,
        rating: 3.9,
        address: 'Hajipur service lane',
        latitude: 28.62,
        longitude: 77.428,
      },
    ];

    for (const row of localServiceDemoEnrich) {
      await prisma.localServiceContact.updateMany({
        where: { id: row.id },
        data: {
          topRank: row.topRank,
          rating: row.rating,
          address: row.address,
          latitude: row.latitude,
          longitude: row.longitude,
        },
      });
    }
  }

  console.info('Seed complete', {
    tenantId: tenant.id,
    siteId: ensuredSite.id,
    demoDeviceId: demoDevice.id,
    localDemoData: seedLocalDemo,
  });
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
