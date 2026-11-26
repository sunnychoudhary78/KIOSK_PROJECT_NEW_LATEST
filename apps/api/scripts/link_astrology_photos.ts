import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { PrismaClient } from '@prisma/client';

const ids = [
  'b0000000-0000-4000-8000-000000000001',
  'b0000000-0000-4000-8000-000000000002',
  'b0000000-0000-4000-8000-000000000003',
  'b0000000-0000-4000-8000-000000000004',
  'b0000000-0000-4000-8000-000000000005',
  'b0000000-0000-4000-8000-000000000006',
  'b0000000-0000-4000-8000-000000000007',
  'b0000000-0000-4000-8000-000000000008',
  'b0000000-0000-4000-8000-000000000009',
  'b0000000-0000-4000-8000-000000000010',
  'b0000000-0000-4000-8000-000000000011',
  'b0000000-0000-4000-8000-000000000012',
  'b0000000-0000-4000-8000-000000000013',
  'b0000000-0000-4000-8000-000000000014',
  'b0000000-0000-4000-8000-000000000015',
  'b0000000-0000-4000-8000-000000000016',
  'b0000000-0000-4000-8000-000000000017',
  'b0000000-0000-4000-8000-000000000018',
];

async function main() {
  const prisma = new PrismaClient();
  const dir = join(process.cwd(), 'uploads', 'astrology-contacts');
  let linked = 0;
  for (const id of ids) {
    const path = join(dir, `${id}.png`);
    if (!existsSync(path)) continue;
    await prisma.astrologyContact.update({
      where: { id },
      data: { photoStoragePath: path },
    });
    linked += 1;
  }
  console.log(`Linked ${linked} astrology photos`);
  await prisma.$disconnect();
}

main().catch(async (error) => {
  console.error(error);
  process.exitCode = 1;
});
