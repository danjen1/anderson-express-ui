# Anderson Express UI

Flutter web interface for the Anderson Express cleaning management system.

> 📖 **See the [main README](../../README.md) for complete setup instructions, authentication, and backend configuration.**

## Quick Start

```bash
# Default (connects to http://localhost:9000)
flutter run -d chrome --web-port=3000

# Override API endpoint
flutter run -d chrome --web-port=3000 \
  --dart-define=API_BASE_URL=http://localhost:9000

# Connect to remote backend
flutter run -d chrome --web-port=3000 \
  --dart-define=BACKEND_HOST=archlinux
```

## Features

**In-app QA Testing:**
- Open `QA Smoke` from System Status
- Run automated smoke tests for employees, clients, locations, cleaners

**Admin Dashboards:**
- **Jobs**: Create jobs, assign employees, manage tasks
- **Locations**: CRUD operations for client locations
- **Clients**: Client management
- **Employees**: Employee management

**Cleaner Dashboard:**
- View assigned jobs
- Update job task statuses

## Configuration

**Debug Backend Override** (hidden by default):
```bash
flutter run -d chrome --web-port=3000 \
  --dart-define=DEBUG_BACKEND_OVERRIDE=true
```
Enables runtime host switching via System Status UI.

**Port 3000 Required**: Invite email links use `FRONTEND_REGISTER_URL` (default `http://localhost:3000/#/register`). Always use `--web-port=3000` for proper invite flow.

## Authentication

Default dev credentials (seeded by backend):
- Admin: `admin@andersonexpress.com` / `dev-password`
- Employee: `john@andersonexpress.com` / `worker123`
- Client: `contact@techstartup.com` / `client123`
