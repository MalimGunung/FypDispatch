@echo off
if "%ANDROID_SDK_ROOT%"=="" (
  echo Please set ANDROID_SDK_ROOT, e.g. set ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk
  exit /b 1
)
set SDKMANAGER=%ANDROID_SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat
if not exist "%SDKMANAGER%" (
  echo sdkmanager not found at %SDKMANAGER%. Ensure Android cmdline-tools are installed.
  exit /b 1
)
echo Installing Android SDK Platform 34 and build-tools...
"%SDKMANAGER%" "platforms;android-34" "build-tools;34.0.0"
echo Done. Run: flutter clean && flutter pub get && flutter run
