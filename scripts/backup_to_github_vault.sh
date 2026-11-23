#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Automated Offsite Backup to Private GitHub Vault (100% Free, Zero Overages)
# ==============================================================================

VAULT_DIR="${HOME}/github_backup_vault"
GIT_REMOTE="git@github.com:kashif-malik12/allonssy-vault-backups.git"
TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"

echo "[$(date -u +%FT%TZ)] Starting offsite backup to Private GitHub Vault..."

# 1. Trigger the local database and fiscal backup
/home/deploy/bin/backup_supabase_vps.sh

# 2. Prepare Vault Directory
if [ ! -d "${VAULT_DIR}/.git" ]; then
  echo "--> Initializing local git vault..."
  mkdir -p "${VAULT_DIR}"
  cd "${VAULT_DIR}"
  git init -b main
  git config user.name "Allonssy Vault Backup Bot"
  git config user.email "deploy@allonssy.com"
  git remote add origin "${GIT_REMOTE}" || true
else
  cd "${VAULT_DIR}"
fi

# 3. Copy 6-Year French Tax Fiscal Archives
echo "--> Syncing 6-Year French POS fiscal archives..."
mkdir -p "${VAULT_DIR}/fiscal_archives"
if [ -d "${HOME}/backups/supabase/fiscal_archives" ]; then
  cp -r "${HOME}/backups/supabase/fiscal_archives"/* "${VAULT_DIR}/fiscal_archives/"
fi

# 4. Copy Database Recovery Dump
echo "--> Syncing Database recovery dump..."
mkdir -p "${VAULT_DIR}/database"
if [ -f "${HOME}/backups/supabase/latest/db/postgres.dump" ]; then
  cp "${HOME}/backups/supabase/latest/db/postgres.dump" "${VAULT_DIR}/database/"
  cp "${HOME}/backups/supabase/latest/db/postgres.dump.sha256" "${VAULT_DIR}/database/"
fi
if [ -f "${HOME}/backups/supabase/latest/manifest.txt" ]; then
  cp "${HOME}/backups/supabase/latest/manifest.txt" "${VAULT_DIR}/database/"
fi

# 5. Copy Tradister Applications (Clean source & configs)
echo "--> Syncing Tradister Compte & Plan..."
mkdir -p "${VAULT_DIR}/tradister"
rsync -a --delete --exclude='backups/' --exclude='.git/' "${HOME}/tradister-compte" "${VAULT_DIR}/tradister/"
rsync -a --delete --exclude='.git/' "${HOME}/tradister-plan" "${VAULT_DIR}/tradister/"

# 6. Documentation Manifest
cat > "${VAULT_DIR}/README.md" <<EOF
# Allonssy & Tradister Private Backup Vault
**Automated Offsite Backup (GitHub Private Repository)**

* **Last Sync:** ${TIMESTAMP}
* **Legal Retention:** French POS Fiscal Archives (Art. 286 I-3° bis CGI & Art. L. 102 B LPF - 6 Years)
* **Components:**
  - \`fiscal_archives/\`: Daily Z-reports, chained receipts, and official Dossier Technique.
  - \`database/\`: Compressed PostgreSQL dump and SHA-256 seal.
  - \`tradister/\`: Tradister Compte (ledger & reminders) and Tradister Plan.

*To restore database on a new server:*
\`\`\`bash
docker exec -i supabase-db pg_restore -U postgres -d postgres -c < database/postgres.dump
\`\`\`
EOF

# 7. Commit and Push to Private GitHub Vault
cd "${VAULT_DIR}"
git add -A
if git diff --staged --quiet; then
  echo "--> No changes detected since last backup. Everything up to date."
else
  git commit -m "backup(vault): automated daily sync ${TIMESTAMP}"
  echo "--> Pushing to GitHub private vault..."
  git push -u origin main --force
  echo "[$(date -u +%FT%TZ)] Successfully backed up to Private GitHub Vault!"
fi
