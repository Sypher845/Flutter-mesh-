# Offline Sync App

A Flutter application that allows users to upload images with descriptions and sync data either directly to a backend (when internet is available) or via Bluetooth hopping to nearby devices (when offline).

## Features

- **Image Upload**: Take photos or select from gallery
- **Offline Support**: Works without internet connection
- **Bluetooth Hopping**: Uses Google Nearby Connections for device-to-device data transfer
- **Auto Sync**: Automatically syncs to backend when internet becomes available
- **Local Storage**: Stores pending tickets locally using SQLite
- **Real-time Status**: Shows connection status and sync progress

## Architecture

### Services
- **ConnectivityService**: Monitors internet connection status
- **DataSyncService**: Handles backend synchronization and local storage
- **BluetoothService**: Manages Nearby Connections for Bluetooth hopping
- **LocalStorageService**: SQLite database operations

### Models
- **TicketModel**: Data structure for tickets with image and description

## Setup

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Configure Backend URL**:
   Update the `_backendUrl` in `lib/services/data_sync_service.dart`:
   ```dart
   static const String _backendUrl = 'https://your-backend-api.com/tickets';
   ```

3. **Android Permissions**:
   The app requires several permissions for Bluetooth and camera access. These are already configured in `android/app/src/main/AndroidManifest.xml`.

4. **Run the App**:
   ```bash
   flutter run
   ```

## How It Works

### With Internet Connection
1. User uploads image and enters description
2. Data is sent directly to backend API
3. Success message is shown to user

### Without Internet Connection
1. User uploads image and enters description
2. Data is stored locally in SQLite database
3. App starts Bluetooth advertising and discovery
4. When nearby devices are found, data is sent via Bluetooth hopping
5. Receiving devices continue the hopping process until reaching a device with internet
6. Device with internet sends data to backend

## Bluetooth Hopping Process

The app uses Google Nearby Connections API which provides:
- **Multi-protocol support**: Bluetooth, BLE, and Wi-Fi Direct
- **Mesh topology**: Automatic device discovery and connection
- **Offline operation**: No internet required for device-to-device communication
- **Cross-platform**: Works on Android devices

## Dependencies

- `nearby_connections`: Google Nearby Connections for Bluetooth hopping
- `connectivity_plus`: Network connectivity monitoring
- `image_picker`: Camera and gallery access
- `sqflite`: Local SQLite database
- `http`: HTTP requests to backend
- `provider`: State management
- `permission_handler`: Runtime permissions

## Backend API Expected Format

The app sends POST requests to the backend with:
- `id`: Unique ticket identifier
- `description`: Text description
- `createdAt`: ISO timestamp
- `image`: Multipart file upload (if image selected)

## Notes

- Bluetooth hopping requires location permissions on Android
- The app automatically retries failed uploads when internet becomes available
- Images are stored locally until successfully uploaded
- All Bluetooth operations are handled automatically by Nearby Connections