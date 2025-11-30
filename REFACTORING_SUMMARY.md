# Hazard Reporter - Refactoring Summary

## Overview
Successfully refactored the Bluetooth Hopping App into a structured Hazard Reporter application with modular components and enhanced data model.

## Major Changes

### 1. Data Model Transformation
**From:** `TicketModel` → **To:** `ReportModel`

New report structure includes:
- `title` - Report title
- `description` - Detailed description
- `imagePath` - Local file path to captured photo
- `location` - Position object with latitude/longitude
- `hazardType` - Type of hazard (enum with 7 types)
- `imageFile` - File object for image
- `createdAt` - Timestamp
- `status` - Report status

### 2. New Features

#### Hazard Types
- Pothole 🕳️
- Broken Street Light 💡
- Flooding 🌊
- Debris on Road 🚧
- Sign Damage 🚸
- Road Damage 🛣️
- Other ⚠️

#### Location Support
- `LocationData` model with latitude, longitude, accuracy
- Location capture UI (currently mock data - needs geolocator package)
- Location display in reports

### 3. File Structure

#### New Models
- `lib/models/report_model.dart` - Complete report data model with location and hazard types

#### Updated Services
- `lib/services/data_sync_service.dart` - Now handles reports instead of tickets
- `lib/services/local_storage_service.dart` - Updated database schema for reports
- `lib/services/bluetooth_service.dart` - Sends/receives report data

#### New Widgets
- `lib/widgets/title_section.dart` - Report title input
- `lib/widgets/hazard_type_selector.dart` - Hazard type selection chips
- `lib/widgets/location_section.dart` - Location capture and display
- `lib/widgets/description_section.dart` - Description input
- `lib/widgets/image_section.dart` - Image upload
- `lib/widgets/bluetooth_controls.dart` - Bluetooth controls
- `lib/widgets/received_data_section.dart` - Received data display
- `lib/widgets/received_data_item.dart` - Individual received report item
- `lib/widgets/tickets_list.dart` - Reports list (renamed from tickets)
- `lib/widgets/status_messages.dart` - Status messages
- `lib/widgets/emulator_warning.dart` - Emulator warning

#### Utilities
- `lib/utils/image_helper.dart` - Image compression helper

### 4. Bluetooth Transmission

**Data Format:** Base64-encoded image inside UTF-8 encoded JSON

Payload structure:
```json
{
  "type": "report_data",
  "payloadId": 1234567890,
  "senderId": "device_1234567890",
  "senderName": "My Device",
  "timestamp": "2025-11-30T...",
  "report": {
    "id": "...",
    "title": "...",
    "description": "...",
    "hazardType": "HazardType.pothole",
    "location": {
      "latitude": 37.7749,
      "longitude": -122.4194,
      "accuracy": 10.0,
      "timestamp": "..."
    },
    "imageBase64": "...",
    "createdAt": "..."
  }
}
```

### 5. Database Schema

New `reports` table:
- id, title, description
- imagePath
- latitude, longitude, locationAccuracy, locationTimestamp
- hazardType
- createdAt, status, retryCount

### 6. UI Improvements
- Cleaner, more modular component structure
- Better visual hierarchy
- Hazard type selection with icons
- Location display with coordinates
- Report title field
- Updated app name: "Hazard Reporter"
- Orange theme color

## TODO
- Implement actual location fetching with `geolocator` package
- Add location permissions handling
- Consider adding map view for location selection
- Add validation for location accuracy

## Backward Compatibility
The app can still receive old "ticket_data" messages and will process them as reports for compatibility.
