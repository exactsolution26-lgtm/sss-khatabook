# Flutter Installation Guide (Windows)

## Step 1: Download Flutter SDK

1. Go to: https://docs.flutter.dev/get-started/install/windows
2. Download Flutter SDK (zip file)
3. Extract to a location like `C:\src\flutter` (avoid spaces in path)

## Step 2: Add Flutter to PATH

1. Press `Win + X` and select "System"
2. Click "Advanced system settings"
3. Click "Environment Variables"
4. Under "User variables", find "Path" and click "Edit"
5. Click "New" and add: `C:\src\flutter\bin` (or your Flutter path)
6. Click OK on all dialogs

## Step 3: Verify Installation

Open a NEW PowerShell/Command Prompt and run:
```bash
flutter doctor
```

## Step 4: Install Android Studio (for Android builds)

1. Download from: https://developer.android.com/studio
2. Install Android Studio
3. Open Android Studio and install Android SDK
4. Accept licenses:
```bash
flutter doctor --android-licenses
```

## Step 5: Run the App

After Flutter is installed:
```bash
cd "c:\Users\om\Desktop\sss khatabok"
flutter pub get
flutter run
```

## Quick Install Script

You can also use the automated installer:
- Download Flutter from official site
- Extract and add to PATH
- Restart your terminal
- Run `flutter doctor` to check setup
