# Flutter Development & Deployment Scripts

Quick-start scripts for running and deploying the Anderson Express UI.

---

## 🚀 Development Scripts

### Local Development (Recommended)

```bash
./scripts/run_local.sh
```

**What it does:**
- Runs Flutter against `http://localhost:9000` (local Rust API)
- Demo Mode: **OFF** (full CRUD operations enabled)
- Backend override: **ON** (can switch backends via UI)
- Perfect for active development

**Prerequisites:**
- Local Rust API running: `cd ../../rust-api && cargo run`

**Environment variable overrides:**
```bash
# Use different port
API_BASE_URL=http://localhost:8080 ./scripts/run_local.sh

# Use Edge browser
FLUTTER_DEVICE=edge ./scripts/run_local.sh

# Pass extra flutter args
./scripts/run_local.sh --web-port=3000
```

---

### Preview Local (Test Demo Mode Locally)

```bash
./scripts/run_preview_local.sh
```

**What it does:**
- Runs Flutter against `http://localhost:9000` (local Rust API)
- Demo Mode: **ON** (read-only, disables create/edit/delete)
- Perfect for testing demo behavior without deploying

**Use when:**
- Testing demo mode UI locally
- Verifying read-only mode works correctly
- Don't want to use deployed backend

---

### Preview Mode (Client Demo)

```bash
./scripts/run_preview.sh
```

**What it does:**
- Runs Flutter against `https://anderson-express-api.fly.dev` (deployed API)
- Demo Mode: **ON** (read-only, disables create/edit/delete buttons)
- Perfect for showing clients without risk of data corruption

**Use when:**
- Demoing to clients
- Testing preview environment behavior
- Verifying read-only mode works correctly

---

### Preview Dev Mode (Test Deployed Backend)

```bash
./scripts/run_preview_dev.sh
```

**What it does:**
- Runs Flutter against `https://anderson-express-api.fly.dev` (deployed API)
- Demo Mode: **OFF** (full CRUD operations enabled)
- Perfect for testing deployed backend without local setup

**Use when:**
- Testing deployed backend changes
- Don't want to run Rust API locally
- Need to verify production behavior

---

## 📦 Deployment to Fly.io

### Deploy Backend (Rust API)

```bash
# From project root
cd rust-api
fly deploy

# Verify deployment
fly status --app anderson-express-api
fly logs --app anderson-express-api --no-tail

# Test health endpoint
curl https://anderson-express-api.fly.dev/healthz
# Should return: ok — anderson-api
```

**Deployed to:** https://anderson-express-api.fly.dev  
**App name:** `anderson-express-api`

---

### Deploy Frontend (Flutter UI)

```bash
# From project root
cd ui/anderson-express-ui
fly deploy

# Verify deployment
fly status --app anderson-express-ui
fly logs --app anderson-express-ui --no-tail

# Test in browser
open https://anderson-express-ui.fly.dev
```

**Deployed to:** https://anderson-express-ui.fly.dev  
**App name:** `anderson-express-ui`

**Note:** The UI deployed to Fly.io uses `lib/config/api_config.dart` which points to:
```dart
static const String baseUrl = 'https://anderson-express-api.fly.dev';
```

---

## 🔄 Complete Deploy Workflow

**When you make changes and want to deploy everything:**

```bash
# 1. Deploy backend first
cd rust-api
fly deploy

# 2. Test backend is healthy
curl https://anderson-express-api.fly.dev/healthz

# 3. Deploy frontend
cd ../ui/anderson-express-ui
fly deploy

# 4. Test UI in browser
open https://anderson-express-ui.fly.dev
```

---

## 🎯 Quick Reference

| Script | Backend | Demo Mode | Debug Override | Use Case |
|--------|---------|-----------|----------------|----------|
| `run_local.sh` | localhost:9000 | OFF | ON | Daily development |
| `run_preview_local.sh` | localhost:9000 | ON | OFF | Test demo mode locally |
| `run_preview.sh` | fly.dev | ON | OFF | Client demos |
| `run_preview_dev.sh` | fly.dev | OFF | ON | Test deployed backend |

**All scripts support:**
- Environment variable overrides (e.g., `API_BASE_URL=...`, `FLUTTER_DEVICE=...`)
- Extra Flutter arguments (e.g., `./script.sh --web-port=3000`)

---

## 🤔 FAQ

### Q: What's the difference between demo mode ON vs OFF?

**Demo Mode ON:**
- ✅ Login works
- ✅ View all data (jobs, clients, employees, locations)
- ✅ Search and filter
- ❌ Create buttons disabled
- ❌ Edit buttons disabled
- ❌ Delete buttons disabled

**Demo Mode OFF:**
- ✅ Full CRUD operations
- ✅ Can create/edit/delete jobs
- ✅ Can manage clients, locations, employees
- ⚠️ Changes persist to database

---

### Q: Should I use `run_preview_dev.sh` or `run_local.sh` for testing?

**Use `run_local.sh`** (recommended):
- ✅ Faster iteration (no network latency)
- ✅ See backend logs in terminal
- ✅ Easy to debug backend issues
- ✅ Can test backend changes immediately

**Use `run_preview_dev.sh`** when:
- You don't want to run Rust API locally
- Testing deployed backend specifically
- Verifying production behavior

---

### Q: How do I update the deployed UI to point to a different API?

Edit `lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'https://anderson-express-api.fly.dev';
}
```

Then redeploy: `fly deploy`

---

### Q: Can I run the UI without any backend?

No, the UI requires a backend API. Use one of:
1. Local Rust API: `cd rust-api && cargo run`
2. Deployed API: https://anderson-express-api.fly.dev

---

## 📋 Environment Variables Reference

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `API_BASE_URL` | URL string | (from api_config.dart) | Backend API endpoint |
| `APP_ENV` | development, preview | development | Environment name |
| `DEMO_MODE` | true, false | false | Read-only mode toggle |

---

## 🛠️ Troubleshooting

**UI can't connect to local API:**
```bash
# Check if Rust API is running
curl http://localhost:9000/healthz

# If not, start it
cd rust-api
cargo run
```

**UI can't connect to deployed API:**
```bash
# Check if deployed API is running
curl https://anderson-express-api.fly.dev/healthz

# Check Fly.io status
cd rust-api
fly status --app anderson-express-api
fly logs --app anderson-express-api
```

**Deployment fails:**
```bash
# Make sure you're in the right directory
cd rust-api          # For backend
cd ui/anderson-express-ui  # For UI

# Check fly.toml exists
ls -la fly.toml

# Try again
fly deploy
```
