# Flutter Deployment Quick Reference

## ✅ **The Answer to Your Question:**

**When building for Fly.io/production, the build script automatically points Flutter to the production backend!**

You don't need to manually change anything - just run the build script before deploying:

```bash
./scripts/build_production.sh
```

This script automatically sets:
- `API_BASE_URL=https://anderson-express-api.fly.dev`
- `DEMO_MODE=true` (read-only for safety)
- `APP_ENV=preview`

---

## 🚀 **Quick Commands**

### Local Development (Daily Work)
```bash
./scripts/run_local.sh
# ✅ Points to: http://localhost:9000
# ✅ Demo mode: OFF (full CRUD)
# ✅ Requires: Local Rust API running
```

### Deploy to Production
```bash
# 1. Build with production settings
./scripts/build_production.sh

# 2. Deploy to Fly.io
fly deploy

# 3. Open in browser
open https://anderson-express-ui.fly.dev
```

**That's it!** The build script handles all environment configuration automatically.

---

## 🎯 **How It Works**

### The Config File (lib/config/api_config.dart)
```dart
class ApiConfig {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:9000', // Default for dev
  );

  static String get baseUrl => _defaultBaseUrl;
}
```

### Build-Time Environment Variables

**For local dev:**
```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:9000
```

**For production:**
```bash
flutter build web \
  --release \
  --dart-define=API_BASE_URL=https://anderson-express-api.fly.dev
```

The `--dart-define` flag sets compile-time constants that can't be changed after build!

---

## 📋 **All Available Scripts**

| Script | Backend | Purpose |
|--------|---------|---------|
| `run_local.sh` | localhost | Daily development |
| `run_preview.sh` | fly.dev | Client demos (read-only) |
| `run_preview_dev.sh` | fly.dev | Test production backend |
| `build_production.sh` | fly.dev | Build for deployment |

---

## ⚠️ **Common Mistakes to Avoid**

### ❌ **DON'T DO THIS:**
```bash
# This will use the wrong API URL!
flutter build web --release
fly deploy
```

### ✅ **DO THIS INSTEAD:**
```bash
# Use the build script which sets the right environment
./scripts/build_production.sh
fly deploy
```

---

## 🔄 **Complete Production Deployment**

```bash
# 1. Deploy backend (if you made changes)
cd rust-api
fly deploy
curl https://anderson-express-api.fly.dev/healthz  # Verify

# 2. Build UI with production settings
cd ../ui/anderson-express-ui
./scripts/build_production.sh

# 3. Deploy UI
fly deploy

# 4. Test
open https://anderson-express-ui.fly.dev
```

---

## 🧪 **Testing Different Environments**

### Test Production Backend Locally
```bash
./scripts/run_preview_dev.sh
# Uses fly.dev backend, but runs locally
# Good for testing without deploying
```

### Test Demo Mode Locally
```bash
./scripts/run_preview_local.sh
# Uses local backend, but in read-only mode
# Good for verifying demo UX
```

---

## 🔧 **Custom API URL (Advanced)**

If you need a custom API URL:

```bash
# Option 1: Override environment variable
API_BASE_URL=https://staging.example.com ./scripts/run_local.sh

# Option 2: Modify build_production.sh
# Edit line 21:
--dart-define=API_BASE_URL=https://your-custom-url.com
```

---

## 📝 **Summary**

**For development:** Just run `./scripts/run_local.sh` (points to localhost automatically)

**For production:** Run `./scripts/build_production.sh` then `fly deploy` (points to fly.dev automatically)

**Never manually edit `api_config.dart`** - the scripts handle everything!

---

## 🆘 **Need Help?**

- Full docs: `scripts/README.md`
- Backend logs: `fly logs --app anderson-express-api`
- UI logs: `fly logs --app anderson-express-ui`
- Health check: `curl https://anderson-express-api.fly.dev/healthz`
