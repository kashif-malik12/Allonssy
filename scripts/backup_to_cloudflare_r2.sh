#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Automated Offsite Backup to Cloudflare R2 for Allonssy & Tradister
# ==============================================================================

RCLONE_CONFIG_FILE="${HOME}/.config/rclone/rclone.conf"
BACKUP_TMP_DIR="/tmp/r2_backup_bundle"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
DATE_MONTH="$(date -u +%Y-%m)"

if ! [ -f "${RCLONE_CONFIG_FILE}" ]; then
  echo "[ERROR] rclone config not found at ${RCLONE_CONFIG_FILE}."
  echo "Please configure your Cloudflare R2 credentials first."
  exit 1
fi

rm -rf "${BACKUP_TMP_DIR}"
mkdir -p "${BACKUP_TMP_DIR}/allonssy" "${BACKUP_TMP_DIR}/tradister"

echo "[$(date -u +%FT%TZ)] Starting offsite backup to Cloudflare R2..."

# 1. First trigger the local database and fiscal backup
/home/deploy/bin/backup_supabase_vps.sh

# 2. Package Allonssy Database & Fiscal Archives
echo "--> Bundling Allonssy database & 6-year fiscal archives..."
if [ -d "${HOME}/backups/supabase/latest" ]; then
  cp -r "${HOME}/backups/supabase/latest" "${BACKUP_TMP_DIR}/allonssy/latest"
fi
if [ -d "${HOME}/backups/supabase/fiscal_archives" ]; then
  cp -r "${HOME}/backups/supabase/fiscal_archives" "${BACKUP_TMP_DIR}/allonssy/fiscal_archives"
fi

# Package Allonssy Web Code
echo "--> Bundling Allonssy Web assets..."
tar -C "/var/www" -czf "${BACKUP_TMP_DIR}/allonssy/allonssy_web_${TIMESTAMP}.tar.gz" local_social_web

# 3. Package Tradister
echo "--> Bundling Tradister Compte & Tradister Plan..."
tar -C "${HOME}" -czf "${BACKUP_TMP_DIR}/tradister/tradister_compte_${TIMESTAMP}.tar.gz" tradister-compte
tar -C "${HOME}" -czf "${BACKUP_TMP_DIR}/tradister/tradister_plan_${TIMESTAMP}.tar.gz" tradister-plan

# 4. Upload to Cloudflare R2 using rclone
echo "--> Syncing to Cloudflare R2 bucket: allonssy-backups..."
/home/deploy/bin/rclone copy "${BACKUP_TMP_DIR}/allonssy/" "r2:allonssy-backups/allonssy/${DATE_MONTH}/" --stats 10s
/home/deploy/bin/rclone copy "${BACKUP_TMP_DIR}/tradister/" "r2:allonssy-backups/tradister/${DATE_MONTH}/" --stats 10s

# Keep a "latest" copy in R2 root
/home/deploy/bin/rclone sync "${BACKUP_TMP_DIR}/" "r2:allonssy-backups/latest/" --stats 10s

# 5. Clean temporary bundle
rm -rf "${BACKUP_TMP_DIR}"

echo "[$(date -u +%FT%TZ)] Offsite backup to Cloudflare R2 completed successfully!"
