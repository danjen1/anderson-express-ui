# cleaning_demo

Flutter UI for testing Anderson Express backends.

## Run with Backend Toggle

Use `BACKEND` to choose active API routing (`rust`, `python`, `vapor`).
Use `API_BASE_URL` to override host/port.

```bash
# Rust
flutter run -d chrome \
  --dart-define=BACKEND=rust \
  --dart-define=API_BASE_URL=http://localhost:9000

# Python
flutter run -d chrome \
  --dart-define=BACKEND=python \
  --dart-define=API_BASE_URL=http://localhost:8000

# Vapor
flutter run -d chrome \
  --dart-define=BACKEND=vapor \
  --dart-define=API_BASE_URL=http://localhost:9001
```

Default endpoints if `API_BASE_URL` is omitted:

- Rust: `http://localhost:9000` (`/healthz`, `/api/v1/employees`)
- Python: `http://localhost:8000` (`/healthz`, `/api/v1/employees`)
- Vapor: `http://localhost:9001` (`/healthz`, `/api/v1/employees`)

Employee routes require bearer auth on all three backends. Get tokens with:

```bash
curl -X POST http://localhost:9000/api/v1/auth/token -H 'Content-Type: application/x-www-form-urlencoded' --data 'username=admin@andersonexpress.com&password=dev-password'
curl -X POST http://localhost:8000/api/v1/auth/token -H 'Content-Type: application/x-www-form-urlencoded' --data 'username=admin@andersonexpress.com&password=dev-password'
curl -X POST http://localhost:9001/api/v1/auth/token -H 'Content-Type: application/x-www-form-urlencoded' --data 'username=admin@andersonexpress.com&password=dev-password'
```

In-app QA flow:
- Open `QA Smoke` from the System Status page.
- Pick backend (`Rust`, `Python`, or `Vapor`), then run `Fetch Token`, `Run Employee Smoke`, `Run Client Smoke`, `Run Location Smoke`, or `Run Cleaner Smoke`.

In-app admin locations CRUD:
- Open `Locations` from the System Status page.
- Fetch a token, then list/create/update/delete locations against the active backend.

In-app admin clients CRUD:
- Open `Clients` from the System Status page.
- Fetch a token, then list/create/update/delete clients against the active backend.

Runtime backend switch (no relaunch required):
- Open `System Status`.
- Choose backend (`Rust`, `Python`, `Vapor`), set host (for example `archlinux`), and click `Apply`.
- The active backend banner is shown globally in app bars.
- Admin, Clients, Locations, Cleaner, and QA Smoke pages use this active backend setting.

In-app cleaner dashboard:
- Open `Cleaner` from the System Status page.
- Use cleaner credentials (`john@andersonexpress.com` / `worker123`) and fetch token.
- Cleaner only sees assigned jobs and their tasks for the active backend.

In-app jobs dashboard (admin):
- Open `Jobs` from the System Status page.
- Use admin credentials and fetch token.
- Create jobs, assign employees, and inspect job tasks/assignments against the active backend.

Authorization behavior mirrored across all 3 backends:
- Admin: full CRUD on employees/clients/locations/cleaning/jobs.
- Cleaner user: assigned jobs + job tasks only.
- Client user: own locations only.

## Chrome/Web against Linux backend host

If Chrome runs on a different machine than your backend, pass the backend host IP:

```bash
flutter run -d chrome \
  --dart-define=BACKEND=rust \
  --dart-define=API_BASE_URL=http://<linux-host-ip>:9000
```

Do the same for Python (`:8000`) and Vapor (`:9001`).

If Flutter is running on a different machine than the APIs, set host once:

```bash
flutter run -d chrome \
  --dart-define=BACKEND=rust \
  --dart-define=BACKEND_HOST=archlinux
```

This makes the app target:
- Rust: `http://archlinux:9000`
- Python: `http://archlinux:8000`
- Vapor: `http://archlinux:9001`
