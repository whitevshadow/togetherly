#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[[ -f "$ROOT/.env.selfhost" ]] || { echo "Missing .env.selfhost. Run ./scripts/selfhost/first-run.sh first." >&2; exit 1; }
exec docker compose --env-file "$ROOT/.env.selfhost" -f "$ROOT/docker-compose.selfhost.yml" "$@"
