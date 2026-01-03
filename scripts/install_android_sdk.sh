#!/usr/bin/env bash
# Simple helper to install Android SDK Platform 34 via sdkmanager
set -e
if [ -z "$ANDROID_SDK_ROOT" ]; then
  echo "Please set ANDROID_SDK_ROOT (e.g. export ANDROID_SDK_ROOT=\$HOME/Android/Sdk)"
  exit 1
fi
SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  echo "sdkmanager not found at $SDKMANAGER. Ensure Android cmdline-tools are installed."
  exit 1
fi
echo "Installing Android SDK Platform 34 and build-tools..."
"$SDKMANAGER" "platforms;android-34" "build-tools;34.0.0" --verbose
echo "Done. Run: flutter clean && flutter pub get && flutter run"
