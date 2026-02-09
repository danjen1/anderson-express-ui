#!/usr/bin/env bash
# Run Flutter against deployed Fly.io API (read-only demo mode)
#
# Usage: ./scripts/run_preview.sh

set -euo pipefail

echo "🎭 Starting Flutter in PREVIEW/DEMO mode..."
echo "   API: https://anderson-express-api.fly.dev"
echo "   Demo Mode: ON (read-only, safe to show clients)"
echo ""

flutter run -d chrome \
  --dart-define=API_BASE_URL=https://anderson-express-api.fly.dev \
  --dart-define=APP_ENV=preview \
  --dart-define=DEMO_MODE=true
