# Togetherly self-host + Android build kit

This is an **overlay kit** for the upstream Togetherly repository. It does not contain a fork or a copy of the app source.

## Install into the repository

1. Clone your own fork of `https://github.com/THET1ME-1/Togetherly` (or open your fork in GitHub Codespaces).
2. Extract the contents of this ZIP into the **root of the Togetherly checkout**. Keep the folder structure. Allow the new kit files to be added; do not replace existing application source files.
3. Open a terminal at the Togetherly repository root.
4. Run:

   ```bash
   chmod +x scripts/selfhost/*.sh selfhost/pocketbase-entrypoint.sh
   ./scripts/selfhost/first-run.sh
   ```

The first run creates a private `.env.selfhost` with random secrets and a generated PocketBase superuser password, builds and starts PocketBase + Centrifugo, waits for PocketBase, then applies the repository's schema, ACL rules, and `lang` field.

The generated credentials are stored in `.env.selfhost` (mode 600). **Do not commit this file.**

## Configure GitHub Codespaces ports

The services listen on:

- PocketBase API/dashboard: port `8090`
- Centrifugo HTTP/WebSocket: port `8443` (container port 8000)

In the Codespaces **Ports** tab, set both ports to **Public** only when you are ready for the two phones to connect. Public forwarding makes the endpoints reachable by anyone who knows the URLs; PocketBase still requires accounts, but do not share the PocketBase superuser password. A private forwarded port is not suitable for the girlfriend's phone unless she can authenticate to your Codespace.

Use the forwarded HTTPS URLs to fill `.app.env`:

```dotenv
PB_URL=https://<your-codespace>-8090.app.github.dev
CENTRIFUGO_WS=wss://<your-codespace>-8443.app.github.dev/connection/websocket
KINOPOISK_TOKEN=
STORE=
```

Use the actual hostnames shown in the Ports tab. Do not use the internal Docker hostname `pocketbase` or `centrifugo` in the mobile app.

## Build the Android APK

After `.app.env` contains your public forwarded URLs:

```bash
./scripts/selfhost/build-apk.sh
```

The script runs Flutter in `ghcr.io/cirruslabs/flutter:stable`, injects `PB_URL` and `CENTRIFUGO_WS` as Dart defines, and writes the APK under `build/app/outputs/flutter-apk/`.

Optional `.app.env` values:

- `KINOPOISK_TOKEN` enables Kinopoisk movie/series lookup.
- `STORE=rustore` selects the RuStore build flavor; omit it for the normal Android build.

## Day-to-day commands

```bash
./scripts/selfhost/start.sh       # start services
./scripts/selfhost/status.sh      # show service status and recent logs
./scripts/selfhost/apply-backend.sh # re-apply schema + access rules + lang field
./scripts/selfhost/stop.sh         # stop services; keeps data
./scripts/selfhost/build-apk.sh   # build app with .app.env endpoints
```

PocketBase data is kept under `.selfhost-data/pb_data`. `stop.sh` does not delete it. Do not run `docker compose down -v` unless you intend to delete persistent data.

## Important feature notes

This kit deploys the Togetherly core self-hosted backend described by the repository: PocketBase (auth/data/media/hooks) and Centrifugo (realtime). It copies the current `pocketbase/pb_hooks` and `pocketbase/pb_public` into the PocketBase image and applies the repository's own `collections_schema.json`, `apply_schema.py`, `apply_acl.py`, and `apply_lang_field.py`.

It does **not** automatically provision every third-party provider. Features that depend on provider credentials or platform services still need their own setup (for example Google/Apple OAuth provider configuration, push-notification credentials, optional Kinopoisk token, or store billing). A successful APK build does not prove every optional integration is enabled. Test sign-up, invite/pairing, chat, memories/media, live location, and realtime updates on both phones before relying on it.

## Security and availability

- GitHub Codespaces forwarding is intended for testing/development, not always-on production hosting. A Codespace may stop or be deleted, and its forwarded endpoint can change.
- Do not publish the Centrifugo API key or JWT HMAC secret. The kit exposes only the Centrifugo client WebSocket/API listener on forwarded port 8443; the PocketBase hook reaches Centrifugo over the private Docker network.
- The PocketBase dashboard (`/_/`) is reachable through the forwarded PocketBase URL. Use a unique strong admin password and never give it to your partner.
- Back up `.selfhost-data/pb_data` before upgrading PocketBase or changing deployment settings. Keep backups private.
- The app repository is GPL-3.0. Review the upstream license and keep the required notices when redistributing your fork.

## Troubleshooting

- `apply_schema.py` errors: verify PocketBase is healthy at `http://127.0.0.1:8090/api/health`, then check `.env.selfhost` admin credentials and rerun `apply-backend.sh`.
- Realtime does not work: verify port 8443 is forwarded and Public, `.app.env` uses `wss://.../connection/websocket`, and both Centrifugo secrets in `.env.selfhost` are unchanged.
- A Codespaces URL changes: update `.app.env` and rebuild the APK.
- If the upstream repository changes the schema scripts or hook environment variables, re-check `CONTRIBUTING.md` and `pocketbase/pb_hooks/centrifugo.pb.js` before deploying an updated source checkout.
