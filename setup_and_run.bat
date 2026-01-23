@echo off
echo ========================================
echo Flutter App Setup and Run Script
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not installed or not in PATH
    echo.
    echo Please install Flutter first:
    echo 1. Download from https://docs.flutter.dev/get-started/install/windows
    echo 2. Extract to C:\src\flutter (or any path without spaces)
    echo 3. Add Flutter\bin to your PATH environment variable
    echo 4. Restart this terminal and run this script again
    echo.
    echo See INSTALL_FLUTTER.md for detailed instructions
    echo.
    pause
    exit /b 1
)

echo [OK] Flutter is installed
echo.

REM Check Flutter version
echo Checking Flutter version...
flutter --version
echo.

REM Navigate to project directory
cd /d "%~dp0"
echo Current directory: %CD%
echo.

REM Get dependencies
echo Step 1: Getting Flutter dependencies...
flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to get dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Check for connected devices
echo Step 2: Checking for connected devices...
flutter devices
echo.

REM Run the app
echo Step 3: Running the app...
echo.
echo If no device is connected, you can:
echo - Connect an Android device via USB (with USB debugging enabled)
echo - Start an Android emulator from Android Studio
echo - Or run: flutter run -d windows (if Windows desktop is supported)
echo.
flutter run

pause
