#!/bin/bash

# Build Script for Oxford Pronunciation Mobile Apps

echo "=========================================="
echo "  Building for Mobile (iOS & Android)"
echo "=========================================="

echo "Step 1: Building Web App..."
npm run build

if [ $? -ne 0 ]; then
  echo "Error: Web build failed."
  exit 1
fi

echo ""
echo "Step 2: Syncing to Capacitor..."
npx cap sync

echo ""
echo "=========================================="
echo "  Build & Sync Complete!"
echo "=========================================="
echo "To run on iOS Simulator:"
echo "  npx cap open ios"
echo ""
echo "To run on Android Emulator:"
echo "  npx cap open android"
