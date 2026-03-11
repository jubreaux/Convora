# Convora Flutter App

A basic Flutter application scaffold for learning mobile development with Flutter.

## Prerequisites

- **Flutter 3.35+** installed and in your PATH
- **Dart 3.9+** (comes with Flutter)
- A supported IDE (Android Studio, VS Code, or Xcode)

Check versions:
```bash
flutter --version
dart --version
```

## Project Setup

### 1. Install Dependencies
```bash
cd frontend
flutter pub get
```

### 2. Run on iOS (macOS only)
```bash
flutter run -d macos
```

### 3. Run on Android Emulator
```bash
# Start emulator first, then:
flutter run
```

### 4. Run on Web
```bash
flutter run -d web
```

### 5. Run on Windows
```bash
flutter run -d windows
```

## Project Structure

```
frontend/
├── lib/
│   └── main.dart          # App entry point with default counter example
├── test/
│   └── widget_test.dart   # Widget tests
├── pubspec.yaml           # Dependencies and project config
├── android/               # Android-specific code
├── ios/                   # iOS-specific code
├── web/                   # Web build files
├── windows/               # Windows-specific code
└── macos/                 # macOS-specific code
```

## Key Learning Points

- **Hot Reload**: Press `r` in the terminal to reload code without restarting
- **Hot Restart**: Press `R` for a full app restart
- **StatefulWidget** vs **StatelessWidget**: See `MyHomePage` for state management
- **Material Design**: The app uses Flutter's Material Design package

## Next Steps

1. Modify `lib/main.dart` to build your UI
2. Add packages to `pubspec.yaml` as needed
3. Run `flutter pub get` after changes to pubspec
4. Use `flutter test` to run widget tests

## Useful Commands

| Command | Purpose |
|---------|---------|
| `flutter run` | Run the app (chooses device/emulator) |
| `flutter run -d <device>` | Run on specific device |
| `flutter devices` | List available devices |
| `flutter pub get` | Install dependencies |
| `flutter pub upgrade` | Upgrade packages |
| `flutter clean` | Clean build artifacts |
| `flutter format lib/` | Format code |
| `flutter analyze` | Lint check |
| `flutter test` | Run tests |

## Learn More

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Flutter API Reference](https://api.flutter.dev/)
