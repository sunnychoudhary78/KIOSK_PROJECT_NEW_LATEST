import {
  DeviceStatus,
  PrismaClient,
  SupportQueryStatus,
  SupportResolution,
  UserRole,
} from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
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

  const demoDeviceSecretHash = await bcrypt.hash('DemoDeviceSecret@12345', 10);
  const demoDevice = await prisma.device.upsert({
    where: { deviceKey: 'demo-kiosk-lobby' },
    update: {
      name: 'Demo Kiosk — Lobby',
      status: DeviceStatus.active,
    },
    create: {
      tenantId: tenant.id,
      siteId: ensuredSite.id,
      name: 'Demo Kiosk — Lobby',
      deviceKey: 'demo-kiosk-lobby',
      deviceSecretHash: demoDeviceSecretHash,
      status: DeviceStatus.active,
      address: 'Demo Site lobby',
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
      description: 'Free print quota for phones on the society list',
      settingValue: {
        period: 'daily',
        freeBwPages: 5,
        freeColorPages: 0,
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

  const demoSupportCount = await prisma.supportQuery.count({
    where: {
      deviceId: demoDevice.id,
      message: { startsWith: '[Demo]' },
    },
  });
  if (demoSupportCount === 0) {
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

  console.info('Seed complete', {
    tenantId: tenant.id,
    siteId: ensuredSite.id,
    demoDeviceId: demoDevice.id,
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
