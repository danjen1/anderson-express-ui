#!/usr/bin/env bash
# Run Flutter against deployed Fly.io API with full CRUD (for testing deployed backend)
#
# Usage: ./scripts/run_preview_dev.sh

set -euo pipefail

echo "🔧 Starting Flutter in PREVIEW DEV mode..."
echo "   API: https://anderson-express-api.fly.dev"
echo "   Demo Mode: OFF (full CRUD against deployed API)"
echo ""

flutter run -d chrome \
  --dart-define=API_BASE_URL=https://anderson-express-api.fly.dev \
  --dart-define=APP_ENV=development \
  --dart-define=DEMO_MODE=false
