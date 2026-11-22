#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${HOME}/supabase-project"
BACKUP_ROOT="${HOME}/backups/supabase"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
WORK_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
FISCAL_DIR="${BACKUP_ROOT}/fiscal_archives/$(date -u +%Y-%m)"

mkdir -p "${WORK_DIR}/db" "${WORK_DIR}/storage" "${WORK_DIR}/config" "${FISCAL_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found on PATH" >&2
  exit 1
fi

if [ ! -d "${BASE_DIR}" ]; then
  echo "supabase project directory not found: ${BASE_DIR}" >&2
  exit 1
fi

echo "[$(date -u +%FT%TZ)] starting full system backup in ${WORK_DIR}"

# 1. Full Database Dump (Postgres custom format)
docker exec supabase-db pg_dump -U postgres -d postgres -Fc \
  > "${WORK_DIR}/db/postgres.dump"

# Compute SHA-256 for tamper-evidence
sha256sum "${WORK_DIR}/db/postgres.dump" > "${WORK_DIR}/db/postgres.dump.sha256"

# 2. Dedicated French POS Fiscal Audit Backup (Article L. 102 B LPF - 6-Year Retention)
echo "[$(date -u +%FT%TZ)] extracting POS fiscal tables for legal archive..."
docker exec supabase-db pg_dump -U postgres -d postgres \
  --table="public.restaurant_orders" \
  --table="public.restaurant_pos_z_reports" \
  --table="public.restaurant_stores" \
  --table="public.restaurant_staff" \
  --table="public.restaurant_items" \
  --data-only --inserts | gzip -9 > "${FISCAL_DIR}/fiscal_pos_${TIMESTAMP}.sql.gz"

sha256sum "${FISCAL_DIR}/fiscal_pos_${TIMESTAMP}.sql.gz" > "${FISCAL_DIR}/fiscal_pos_${TIMESTAMP}.sha256"

# 3. Storage & Config Backup
tar -C "${BASE_DIR}" -czf "${WORK_DIR}/storage/storage.tar.gz" volumes/storage
tar -C "${BASE_DIR}" -czf "${WORK_DIR}/config/config.tar.gz" .env docker-compose.yml volumes/functions

# 4. Manifest
cat > "${WORK_DIR}/manifest.txt" <<EOM
timestamp=${TIMESTAMP}
hostname=$(hostname)
base_dir=${BASE_DIR}
retention_days=${RETENTION_DAYS}
fiscal_archive=${FISCAL_DIR}/fiscal_pos_${TIMESTAMP}.sql.gz
legal_basis=Article 286 I-3 bis CGI & Article L. 102 B LPF (Conservation 6 ans)
EOM

# 5. Prune only standard timestamped rolling directories (exclude fiscal_archives, logs, daily)
find "${BACKUP_ROOT}" -maxdepth 1 -name "20[0-9][0-9]-*" -type d -mtime +"${RETENTION_DAYS}" -exec rm -rf {} +

# Fiscal archives are pruned only after 6 years (2192 days)
find "${BACKUP_ROOT}/fiscal_archives" -mindepth 1 -name "*.sql.gz" -mtime +2192 -exec rm -f {} + 2>/dev/null || true

# 6. Update latest symlink
LATEST_LINK="${BACKUP_ROOT}/latest"
rm -f "${LATEST_LINK}"
ln -s "${WORK_DIR}" "${LATEST_LINK}"

echo "[$(date -u +%FT%TZ)] backup complete successfully. Fiscal archive saved in ${FISCAL_DIR}"
