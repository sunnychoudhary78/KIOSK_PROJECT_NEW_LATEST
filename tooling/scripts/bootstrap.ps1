# Bootstrap Smart Kiosk Platform local development
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "../..")
Set-Location $Root

Write-Host "==> Installing workspace dependencies"
pnpm install

Write-Host "==> Starting Postgres"
pnpm docker:up

Write-Host "==> Preparing API env"
$envExample = Join-Path $Root "apps/api/.env.example"
$envFile = Join-Path $Root "apps/api/.env"
if (-not (Test-Path $envFile)) {
  Copy-Item $envExample $envFile
  Write-Host "Created apps/api/.env from .env.example"
}

Write-Host "==> Generating Prisma client"
pnpm --filter @skp/api prisma:generate

Write-Host "==> Flutter pub get (kiosk + mobile)"
Push-Location (Join-Path $Root "apps/kiosk"); flutter pub get; Pop-Location
Push-Location (Join-Path $Root "apps/mobile"); flutter pub get; Pop-Location

Write-Host "Bootstrap complete. Run: pnpm --filter @skp/api prisma:migrate && pnpm dev:api"
