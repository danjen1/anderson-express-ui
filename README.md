# cleaning_demo

Flutter UI for the Rust backend.

## Run

Use `API_BASE_URL` to override host/port (defaults to `http://localhost:9000`).

```bash
flutter run -d chrome \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:9000
```

Default endpoint if `API_BASE_URL` is omitted:
- Rust: `http://localhost:9000` (`/healthz`, `/api/v1/employees`)

Token endpoint:

```bash
curl -X POST http://localhost:9000/api/v1/auth/token -H 'Content-Type: application/x-www-form-urlencoded' --data 'username=admin@andersonexpress.com&password=dev-password'
```

In-app QA flow:
- Open `QA Smoke` from System Status.
- Run `Fetch Token`, `Run Employee Smoke`, `Run Client Smoke`, `Run Location Smoke`, or `Run Cleaner Smoke`.

In-app dashboards:
- `Locations`: list/create/update/delete locations.
- `Clients`: list/create/update/delete clients.
- `Cleaner`: assigned jobs + job tasks.
- `Jobs`: create jobs, assign employees, inspect tasks/assignments.

Runtime host switch (no relaunch required):
- Open `System Status`.
- Set host (for example `archlinux`) and click `Apply`.
- Hidden by default. Enable host override controls with:
  - `--dart-define=DEBUG_BACKEND_OVERRIDE=true`

If Flutter runs on a different machine than the backend:

```bash
flutter run -d chrome \
  --web-port=3000 \
  --dart-define=API_BASE_URL=http://<linux-host-ip>:9000
```

Or set host once:

```bash
flutter run -d chrome \
  --web-port=3000 \
  --dart-define=BACKEND_HOST=archlinux
```

Invite links use `FRONTEND_REGISTER_URL` from backend env (default `http://localhost:3000/#/register`), so `--web-port=3000` is required for invite links to open correctly.
