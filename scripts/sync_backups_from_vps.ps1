# Sync Supabase Backups & Fiscal Archives from VPS to Local Machine
param (
    [string]$VpsHost = "87.106.13.170",
    [string]$VpsUser = "deploy",
    [string]$LocalBackupDir = "$PSScriptRoot\..\backups_external"
)

Write-Host "==> Starting backup sync from VPS ($VpsHost) to $LocalBackupDir..." -ForegroundColor Cyan

if (-not (Test-Path $LocalBackupDir)) {
    New-Item -ItemType Directory -Path $LocalBackupDir -Force | Out-Null
}

# 1. Sync Fiscal Archives (Legal 6-year French tax records)
Write-Host "--> Syncing Fiscal Archives..." -ForegroundColor Yellow
scp -r "${VpsUser}@${VpsHost}:/home/deploy/backups/supabase/fiscal_archives" "$LocalBackupDir/"

# 2. Sync Latest Full System Snapshot (Database, Config, Storage)
Write-Host "--> Syncing Latest System Snapshot..." -ForegroundColor Yellow
scp -r "${VpsUser}@${VpsHost}:/home/deploy/backups/supabase/latest" "$LocalBackupDir/"

Write-Host "==> Backup sync completed successfully!" -ForegroundColor Green
Get-ChildItem -Recurse $LocalBackupDir | Select-Object Name, Length, LastWriteTime
