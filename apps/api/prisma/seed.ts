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

  const extraServices = await prisma.platformService.findMany({
    where: { code: { in: ['astrology', 'quick_print'] } },
    select: { id: true, code: true },
  });
  if (extraServices.length) {
    const devices = await prisma.device.findMany({ select: { id: true, tenantId: true } });
    for (const device of devices) {
      for (const extra of extraServices) {
        await prisma.serviceEnablement.upsert({
          where: {
            deviceId_serviceId: {
              deviceId: device.id,
              serviceId: extra.id,
            },
          },
          update: {},
          create: {
            tenantId: device.tenantId,
            deviceId: device.id,
            serviceId: extra.id,
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
