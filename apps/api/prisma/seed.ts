import { PrismaClient, UserRole } from '@prisma/client';
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
      code: 'astrology',
      name: 'Astrology & Palm Reading',
      description: 'Vedic chart plus palm reading from the kiosk camera',
    },
    {
      code: 'quick_print',
      name: 'Quick Print',
      description: 'Scan a QR on the kiosk and upload documents from a phone browser',
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

  console.info('Seed complete', { tenantId: tenant.id, siteId: ensuredSite.id });
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
