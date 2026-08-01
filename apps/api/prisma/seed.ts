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

  await prisma.platformSetting.upsert({
    where: { settingKey: 'sms_config' },
    update: {},
    create: {
      settingKey: 'sms_config',
      description: 'MSG91 Flow SMS configuration for OTP delivery',
      settingValue: {
        provider: 'msg91',
        enabled: false,
        auth_key: '',
        sender_id: '',
        flow_id: '',
        otp_var_name: 'OTP',
        message_template:
          'Your OTP for Smart Kiosk is --. Valid for 30 minutes. Do not share this code.',
      },
    },
  });

  await prisma.platformSetting.upsert({
    where: { settingKey: 'otp_print_config' },
    update: {},
    create: {
      settingKey: 'otp_print_config',
      description: 'OTP print challenge limits and TTL',
      settingValue: {
        ttlSeconds: 1800,
        otpLength: 6,
        maxPagesPerSession: 10,
        maxDocumentsPerSession: 5,
        maxVerifyAttempts: 5,
        maxFileSizeMb: 15,
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
