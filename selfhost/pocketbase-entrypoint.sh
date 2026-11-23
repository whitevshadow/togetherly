#!/bin/sh
set -eu

: "${PB_SUPERUSER_EMAIL:?PB_SUPERUSER_EMAIL is required}"
: "${PB_SUPERUSER_PASSWORD:?PB_SUPERUSER_PASSWORD is required}"
: "${PB_ENCRYPTION_KEY:?PB_ENCRYPTION_KEY is required}"

mkdir -p /pb/pb_data

# Keep the admin account reproducible from the private deployment env file.
# `upsert` creates it on first boot and applies the same configured password on restart.
/pb/pocketbase --dir=/pb/pb_data --encryptionEnv=PB_ENCRYPTION_KEY \
  superuser upsert "$PB_SUPERUSER_EMAIL" "$PB_SUPERUSER_PASSWORD"

exec /pb/pocketbase serve \
  --http=0.0.0.0:8090 \
  --dir=/pb/pb_data \
  --hooksDir=/pb/pb_hooks \
  --publicDir=/pb/pb_public \
  --encryptionEnv=PB_ENCRYPTION_KEY
