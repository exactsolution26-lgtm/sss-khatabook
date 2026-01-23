# Offline Khata App

A Flutter application for offline financial tracking with work timer functionality.

## Features

- **Accounts Management**: Create accounts with opening balances
- **Expense Tracking**: Record and track expenses by account
- **Income Tracking**: Record and track income by account
- **Work Timer**: Track daily work hours with timer functionality
- **Financial Analysis**: View summaries and account details

## Project Structure

```
offline_khata_app/
├── lib/
│   ├── main.dart                // App entry point
│   ├── app.dart                 // MaterialApp wrapper
│   ├── core/                    // Core utilities
│   ├── database/                // SQLite database
│   ├── models/                  // Data models
│   ├── features/                // Feature modules
│   ├── widgets/                 // Reusable widgets
│   └── routes/                  // App routes
├── assets/                      // Icons and images
└── pubspec.yaml                 // Dependencies
```

## Setup

1. Install Flutter: https://flutter.dev/docs/get-started/install
2. Get dependencies: `flutter pub get`
3. Run the app: `flutter run`
4. Build APK: `flutter build apk --release`

## Dependencies

- `sqflite`: SQLite database
- `path`: Path manipulation
- `intl`: Internationalization
- `flutter_local_notifications`: Local notifications
