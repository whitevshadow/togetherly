#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

for required in pubspec.yaml pocketbase/collections_schema.json pocketbase/apply_schema.py pocketbase/apply_acl.py pocketbase/apply_lang_field.py pocketbase/pb_hooks pocketbase/pb_public; do
  [[ -e "$required" ]] || { echo "Missing $required. Extract this kit into the root of the Togetherly repository." >&2; exit 1; }
done

if [[ ! -f .env.selfhost ]]; then
  read -r -p "PocketBase admin email [admin@example.com]: " ADMIN_EMAIL
  ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
  export ADMIN_EMAIL
  umask 077
  python3 - <<'PY'
import os, secrets
email = os.environ["ADMIN_EMAIL"].strip()
if not email or "@" not in email:
    raise SystemExit("Please enter a valid email address.")
values = {
    "PB_VERSION": "0.42.3",
    "CENTRIFUGO_IMAGE": "centrifugo/centrifugo:v6.9.7",
    "PB_SUPERUSER_EMAIL": email,
    "PB_SUPERUSER_PASSWORD": secrets.token_urlsafe(30),
    "PB_ENCRYPTION_KEY": secrets.token_hex(32),
    "CENTRIFUGO_TOKEN_HMAC": secrets.token_hex(32),
    "CENTRIFUGO_API_KEY": secrets.token_urlsafe(36),
    "MOD_SECRET": secrets.token_hex(32),
    "FB_WEB_API_KEY": "",
}
with open(".env.selfhost", "w", encoding="utf-8") as f:
    for k, v in values.items():
        f.write(f"{k}={v}\n")
os.chmod(".env.selfhost", 0o600)
print("Created .env.selfhost with private random secrets.")
print("PocketBase admin email:", email)
print("PocketBase admin password:", values["PB_SUPERUSER_PASSWORD"])
print("Save the password securely. It is also stored in .env.selfhost.")
PY
else
  echo ".env.selfhost already exists; keeping your current secrets."
fi

if [[ ! -f .app.env ]]; then
  cp .app.env.example .app.env
  chmod 600 .app.env
  echo "Created .app.env. Add your public Codespaces URLs after forwarding ports."
fi

# Ensure private runtime data and local env files are ignored by Git.
python3 - <<'PY'
from pathlib import Path
p = Path(".gitignore")
existing = p.read_text(encoding="utf-8") if p.exists() else ""
entries = [".env.selfhost", ".app.env", ".selfhost-data/", "build/"]
missing = [x for x in entries if x not in existing.splitlines()]
if missing:
    with p.open("a", encoding="utf-8") as f:
        if existing and not existing.endswith("\n"):
            f.write("\n")
        f.write("\n# Togetherly self-host kit (private secrets/data)\n")
        f.write("\n".join(missing) + "\n")
PY

mkdir -p .selfhost-data/pb_data
"$ROOT/scripts/selfhost/compose.sh" up -d --build

printf "Waiting for PocketBase health"
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8090/api/health >/dev/null 2>&1; then
    echo " OK"
    break
  fi
  printf "."
  sleep 2
done
if ! curl -fsS http://127.0.0.1:8090/api/health >/dev/null 2>&1; then
  echo "\nPocketBase did not become healthy. Inspect: ./scripts/selfhost/status.sh" >&2
  exit 1
fi

"$ROOT/scripts/selfhost/apply-backend.sh"

echo
echo "Backend is running."
echo "PocketBase:   http://127.0.0.1:8090"
echo "Centrifugo:   ws://127.0.0.1:8443/connection/websocket"
echo "Next: make Codespaces ports 8090 and 8443 Public, then edit .app.env with their HTTPS/WSS URLs."
echo "Build: ./scripts/selfhost/build-apk.sh"
