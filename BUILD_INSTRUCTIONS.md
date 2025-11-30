# Build Instructions

## Issue Fixed
The build was failing due to insufficient Java heap space. I've updated `android/gradle.properties` with the following changes:

### Changes Made
```properties
# Increased heap size from 1536M to 4096M
org.gradle.jvmargs=-Xmx4096M -XX:MaxMetaspaceSize=1024m -XX:+HeapDumpOnOutOfMemoryError

# Disabled Jetifier (not needed since we're using AndroidX)
android.enableJetifier=false

# Enabled performance optimizations
org.gradle.daemon=true
org.gradle.parallel=true
org.gradle.configureondemand=true
```

## Build Commands

### Option 1: Clean Build (Recommended)
```bash
# Clean previous build artifacts
flutter clean

# Get dependencies
flutter pub get

# Build APK with split per ABI (smaller file sizes)
flutter build apk --split-per-abi
```

### Option 2: Build Single APK (Universal)
```bash
flutter clean
flutter pub get
flutter build apk
```

### Option 3: Build App Bundle (For Play Store)
```bash
flutter clean
flutter pub get
flutter build appbundle
```

## If Build Still Fails

### 1. Clear Gradle Cache
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --split-per-abi
```

### 2. Increase Heap Size Further (if needed)
Edit `android/gradle.properties` and change:
```properties
org.gradle.jvmargs=-Xmx6144M -XX:MaxMetaspaceSize=1024m -XX:+HeapDumpOnOutOfMemoryError
```

### 3. Build with Verbose Output
```bash
flutter build apk --split-per-abi --verbose
```

## Output Location
After successful build, APKs will be located at:
```
build/app/outputs/flutter-apk/
```

Files:
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM - most modern devices)
- `app-x86_64-release.apk` (64-bit x86 - emulators)

## Recommended APK for Testing
Use `app-arm64-v8a-release.apk` for most modern Android devices.

## Build Size Optimization
The `--split-per-abi` flag creates separate APKs for different CPU architectures, resulting in smaller file sizes:
- Universal APK: ~50-60 MB
- Split APKs: ~20-25 MB each

## Troubleshooting

### Error: "Java heap space"
- Increase heap size in `android/gradle.properties`
- Close other applications to free up RAM
- Restart your computer if needed

### Error: "Execution failed for task"
- Run `flutter clean`
- Delete `android/.gradle` folder
- Run `flutter pub get`
- Try building again

### Error: "SDK location not found"
- Set ANDROID_HOME environment variable
- Or create `android/local.properties` with:
  ```
  sdk.dir=C:\\Users\\YourUsername\\AppData\\Local\\Android\\Sdk
  ```

## Next Steps After Build
1. Transfer APK to Android device
2. Enable "Install from Unknown Sources" in device settings
3. Install and test the app
4. Test Bluetooth functionality between two devices
