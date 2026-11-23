#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
[[ -f .env.selfhost ]] || { echo "Missing .env.selfhost. Run first-run.sh." >&2; exit 1; }
set -a
# Generated .env.selfhost values are shell-safe (emails + URL-safe/random hex).
. ./.env.selfhost
set +a

# CRITICAL: override upstream helper defaults (which otherwise point at the author's production site).
export PB_URL="http://127.0.0.1:8090"
export PB_EMAIL="$PB_SUPERUSER_EMAIL"
export PB_PASSWORD="$PB_SUPERUSER_PASSWORD"
export PB_PW="$PB_SUPERUSER_PASSWORD"

python3 pocketbase/apply_schema.py
python3 pocketbase/apply_acl.py
python3 pocketbase/apply_lang_field.py

echo "PocketBase schema, ACL rules, and lang field applied to $PB_URL."
