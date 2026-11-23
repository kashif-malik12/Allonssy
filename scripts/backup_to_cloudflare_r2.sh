#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Automated Offsite Backup to Cloudflare R2 for Allonssy & Tradister
# ==============================================================================

RCLONE_CONFIG_FILE="${HOME}/.config/rclone/rclone.conf"
BACKUP_TMP_DIR="/tmp/r2_backup_bundle"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
DATE_MONTH="$(date -u +%Y-%m)"

# ------------------------------------------------------------------------------
# 🛡️ HARD SPEND CAP / SAFETY GUARD (Free Tier is 10 GB, we cap at 5 GB)
# ------------------------------------------------------------------------------
MAX_R2_BYTES=5368709120 # 5 GiB strict safety ceiling

if ! [ -f "${RCLONE_CONFIG_FILE}" ]; then
  echo "[ERROR] rclone config not found at ${RCLONE_CONFIG_FILE}."
  echo "Please configure your Cloudflare R2 credentials first."
  exit 1
fi

echo "[$(date -u +%FT%TZ)] Checking Cloudflare R2 bucket usage against free tier limit..."
CURRENT_R2_BYTES=$(/home/deploy/bin/rclone size r2:allonssy-backups --json 2>/dev/null | grep -o '"bytes":[0-9]*' | cut -d: -f2 || echo 0)
CURRENT_R2_MB=$(( CURRENT_R2_BYTES / 1024 / 1024 ))

echo "[$(date -u +%FT%TZ)] Current R2 storage: ${CURRENT_R2_MB} MB / 5120 MB (Limit: 5 GB of 10 GB Free Tier)"

if [ "${CURRENT_R2_BYTES}" -ge "${MAX_R2_BYTES}" ]; then
  echo "[FATAL GUARD TRIGGERED] R2 bucket size (${CURRENT_R2_MB} MB) has reached the 5 GB safety threshold!"
  echo "Aborting upload to guarantee your Cloudflare account is NEVER billed a single cent."
  exit 1
fi

# Auto-prune rolling web & server tarballs older than 30 days from R2 to keep usage permanently low
# (Fiscal archives are preserved for 6 years as they only take ~4 KB each)
echo "--> Pruning non-fiscal rolling archives older than 30 days in Cloudflare R2..."
/home/deploy/bin/rclone delete "r2:allonssy-backups/allonssy/" --min-age 30d --include "allonssy_web_*.tar.gz" 2>/dev/null || true
/home/deploy/bin/rclone delete "r2:allonssy-backups/tradister/" --min-age 30d --include "*.tar.gz" 2>/dev/null || true

rm -rf "${BACKUP_TMP_DIR}"
mkdir -p "${BACKUP_TMP_DIR}/allonssy" "${BACKUP_TMP_DIR}/tradister"

echo "[$(date -u +%FT%TZ)] Starting offsite backup to Cloudflare R2..."

# 1. First trigger the local database and fiscal backup
/home/deploy/bin/backup_supabase_vps.sh

# 2. Package Allonssy Database & Fiscal Archives
echo "--> Bundling Allonssy database & 6-year fiscal archives..."
if [ -d "${HOME}/backups/supabase/latest" ]; then
  # Dereference symlink to copy actual database dump, storage and config
  cp -rL "${HOME}/backups/supabase/latest" "${BACKUP_TMP_DIR}/allonssy/system_recovery_snapshot"
fi
if [ -d "${HOME}/backups/supabase/fiscal_archives" ]; then
  cp -r "${HOME}/backups/supabase/fiscal_archives" "${BACKUP_TMP_DIR}/allonssy/fiscal_archives"
fi

# Package Allonssy Web Code (excluding transient caches)
echo "--> Bundling Allonssy Web assets..."
tar -C "/var/www" --exclude='.git' -czf "${BACKUP_TMP_DIR}/allonssy/allonssy_web_${TIMESTAMP}.tar.gz" local_social_web

# 3. Package Tradister (excluding redundant local PHP backups)
echo "--> Bundling Tradister Compte & Tradister Plan..."
tar -C "${HOME}" --exclude='tradister-compte/backups' --exclude='.git' -czf "${BACKUP_TMP_DIR}/tradister/tradister_compte_${TIMESTAMP}.tar.gz" tradister-compte
tar -C "${HOME}" --exclude='.git' -czf "${BACKUP_TMP_DIR}/tradister/tradister_plan_${TIMESTAMP}.tar.gz" tradister-plan

# 4. Upload to Cloudflare R2 using rclone
echo "--> Syncing to Cloudflare R2 bucket: allonssy-backups..."
/home/deploy/bin/rclone copy -L "${BACKUP_TMP_DIR}/allonssy/" "r2:allonssy-backups/allonssy/${DATE_MONTH}/" --stats 10s
/home/deploy/bin/rclone copy -L "${BACKUP_TMP_DIR}/tradister/" "r2:allonssy-backups/tradister/${DATE_MONTH}/" --stats 10s

# Keep a "latest" copy in R2 root
/home/deploy/bin/rclone sync -L "${BACKUP_TMP_DIR}/" "r2:allonssy-backups/latest/" --stats 10s

# 5. Clean temporary bundle
rm -rf "${BACKUP_TMP_DIR}"

echo "[$(date -u +%FT%TZ)] Offsite backup to Cloudflare R2 completed successfully!"
