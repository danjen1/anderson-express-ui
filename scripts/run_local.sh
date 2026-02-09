#!/usr/bin/env bash
# Run Flutter against local Rust API (full CRUD enabled)
#
# Usage: ./scripts/run_local.sh

set -euo pipefail

echo "🚀 Starting Flutter in LOCAL mode..."
echo "   API: http://localhost:9000"
echo "   Demo Mode: OFF (full CRUD enabled)"
echo ""

flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:9000 \
  --dart-define=APP_ENV=development \
  --dart-define=DEMO_MODE=false
