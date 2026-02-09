#!/usr/bin/env bash
# Build Flutter for production deployment (demo mode, deployed backend)
#
# This builds the Flutter web app with settings suitable for Fly.io deployment:
# - Points to deployed backend (fly.dev)
# - Demo mode ON (read-only, safe for public)
# - No debug backend override
#
# Usage: ./scripts/build_production.sh

set -euo pipefail

echo "🏗️  Building Flutter for PRODUCTION deployment..."
echo "   Backend: https://anderson-express-api.fly.dev"
echo "   Demo Mode: ON (read-only)"
echo "   Target: build/web/"
echo ""

flutter build web \
  --release \
  --dart-define=API_BASE_URL=https://anderson-express-api.fly.dev \
  --dart-define=APP_ENV=preview \
  --dart-define=DEMO_MODE=true \
  --dart-define=DEBUG_BACKEND_OVERRIDE=false

echo ""
echo "✅ Production build complete!"
echo ""
echo "📦 Next: Deploy to Fly.io"
echo "   fly deploy"
