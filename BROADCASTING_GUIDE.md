# Bluetooth Broadcasting Guide

## Overview
The app now supports **data broadcasting** where the advertiser can send data to all connected devices, and those devices will display the received data in real-time.

## How Broadcasting Works

### 1. **Advertiser Role** (Data Sender)
- Device that starts "Advertising"
- Can broadcast data to ALL connected devices simultaneously
- Has access to "Broadcast Message" button when devices are connected

### 2. **Discoverer Role** (Data Receiver)
- Devices that start "Discovery" and connect to advertiser
- Automatically receive all broadcasted data
- Display received data in "Received Data" section

## Data Flow

```
Advertiser Device (Sender)
    ↓ Broadcasts Data
    ├── Connected Device 1 (Receiver)
    ├── Connected Device 2 (Receiver)
    └── Connected Device N (Receiver)
```

## New Features

### 📡 **Broadcasting System**
1. **Ticket Broadcasting**: When advertiser submits a ticket, it's sent to all connected devices
2. **Custom Message Broadcasting**: Advertiser can send custom messages via "Broadcast Message" button
3. **Structured Data**: All broadcasts include sender info, timestamp, and data type

### 📥 **Received Data Display**
1. **Real-time Updates**: Received data appears immediately in the UI
2. **Sender Information**: Shows who sent the data and when
3. **Data Preview**: Smart preview of different data types
4. **History Management**: Keeps last 10 received items, with clear option

### 🔍 **Enhanced Logging**
- Detailed broadcast logs showing success/failure for each device
- Received data logs with sender information
- Data type identification and handling

## Testing the Broadcasting System

### Setup (Requires 2+ Physical Devices)

#### Device A (Advertiser/Sender):
1. Open the app
2. Tap "Start Advertising"
3. Wait for other devices to connect
4. Once connected, you'll see "Broadcast Message" button

#### Device B, C, etc. (Receivers):
1. Open the app
2. Tap "Find Devices"
3. Should discover and connect to Device A
4. Will automatically receive any broadcasts from Device A

### Test Scenarios

#### 1. **Ticket Broadcasting**
- **On Advertiser**: Create and submit a ticket
- **Expected**: All connected devices receive the ticket data
- **Check**: "Received Data" section shows the ticket

#### 2. **Custom Message Broadcasting**
- **On Advertiser**: Tap "Broadcast Message" → Enter message → Send
- **Expected**: All connected devices receive the message
- **Check**: "Received Data" section shows the message

#### 3. **Multiple Device Broadcasting**
- **Setup**: Connect 3+ devices to one advertiser
- **Test**: Send broadcasts from advertiser
- **Expected**: ALL connected devices receive the same data simultaneously

## UI Elements

### For Advertisers (Senders)
- **"Broadcast Message" Button**: Appears when advertising and devices are connected
- **Connection Count**: Shows number of connected devices in button text
- **Broadcast Status**: Status messages show successful broadcast count

### For Receivers
- **"Received Data" Section**: Shows all received broadcasts
- **Sender Information**: Each item shows sender name and timestamp
- **Data Preview**: Smart preview based on data type
- **Clear Button**: Remove all received data history

## Data Types Supported

### 1. **Ticket Data**
```json
{
  "type": "ticket_data",
  "senderId": "advertiser_123456789",
  "senderName": "Advertiser Device",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "ticket": {
    "id": "ticket_123",
    "description": "Sample ticket",
    "createdAt": "2024-01-01T12:00:00.000Z"
  }
}
```

### 2. **Custom Messages**
```json
{
  "type": "custom_data",
  "senderId": "advertiser_123456789",
  "senderName": "Advertiser Device", 
  "timestamp": "2024-01-01T12:00:00.000Z",
  "data": {
    "message": "Hello from advertiser!"
  }
}
```

## Debugging

### Broadcast Logs (Advertiser)
```
📡 BLUETOOTH DEBUG: Broadcasting ticket data to 2 devices
✅ BLUETOOTH DEBUG: Successfully sent to device: endpoint_1
✅ BLUETOOTH DEBUG: Successfully sent to device: endpoint_2
📡 Broadcasted data to 2/2 devices
```

### Receive Logs (Receivers)
```
📥 BLUETOOTH DEBUG: RECEIVED DATA!
  - From Endpoint: endpoint_advertiser
  - Data Type: custom_data
  - Sender: Advertiser Device
  - Timestamp: 2024-01-01T12:00:00.000Z
📥 Received custom_data from Advertiser Device
```

## Key Points

1. **One-to-Many**: Only advertisers can broadcast to multiple devices
2. **Real-time**: Data appears immediately on receiving devices
3. **Reliable**: Individual device failures don't affect other broadcasts
4. **Structured**: All data includes metadata for proper handling
5. **Visual Feedback**: Clear UI indication of sent/received data

## Troubleshooting

### No "Broadcast Message" Button
- **Cause**: Not advertising or no connected devices
- **Solution**: Start advertising and wait for devices to connect

### Data Not Received
- **Check**: Devices are properly connected (check connection count)
- **Check**: Receiving device is in foreground
- **Check**: Console logs for transmission errors

### Partial Broadcast Success
- **Normal**: Some devices may fail to receive due to connection issues
- **Check**: Status message shows "Broadcasted to X/Y devices"
- **Action**: Failed devices will need to reconnect

This broadcasting system enables true mesh-like data distribution where one device can efficiently share information with multiple connected devices simultaneously!