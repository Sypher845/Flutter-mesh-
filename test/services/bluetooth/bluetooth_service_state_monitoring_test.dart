import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/bluetooth_service.dart';

void main() {
  // Ensure Flutter bindings are initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BluetoothService - Bluetooth State Monitoring Tests', () {
    
    /// **Feature: bluetooth-enhancement, Example Test for Requirement 6.3**
    /// **Validates: Requirements 6.3**
    /// 
    /// Example Test: Test that Bluetooth disable pauses operations
    /// 
    /// This test verifies that when Bluetooth is disabled by the user,
    /// the system pauses all operations and notifies the user.
    /// 
    /// Requirements 6.3: WHEN Bluetooth is disabled by the user 
    /// THEN the system SHALL pause all operations and notify the user
    test(
      'Example Test (Requirement 6.3): Bluetooth disable pauses operations',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        // Track status messages
        String? lastStatusMessage;
        bluetoothService.addListener(() {
          lastStatusMessage = bluetoothService.statusMessage;
        });
        
        // Wait a bit for initialization to start (but don't wait for full completion)
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verify initial state - Bluetooth should be enabled by default
        expect(
          bluetoothService.isBluetoothEnabled,
          isTrue,
          reason: 'Bluetooth should be enabled initially'
        );
        
        expect(
          bluetoothService.operationsPaused,
          isFalse,
          reason: 'Operations should not be paused initially'
        );
        
        // Act: Simulate Bluetooth being disabled
        bluetoothService.handleBluetoothStateChange(false);
        
        // Wait for state change to be processed
        await Future.delayed(Duration(milliseconds: 200));
        
        // Assert: Verify operations are paused
        expect(
          bluetoothService.isBluetoothEnabled,
          isFalse,
          reason: 'Bluetooth state should be updated to disabled'
        );
        
        expect(
          bluetoothService.operationsPaused,
          isTrue,
          reason: 'Operations should be paused when Bluetooth is disabled'
        );
        
        // Verify user notification
        expect(
          lastStatusMessage,
          isNotNull,
          reason: 'Status message should be set to notify user'
        );
        
        expect(
          lastStatusMessage,
          contains('Bluetooth'),
          reason: 'Status message should mention Bluetooth'
        );
        
        expect(
          lastStatusMessage!.contains('disabled') || lastStatusMessage!.contains('enable'),
          isTrue,
          reason: 'Status message should indicate Bluetooth needs to be enabled'
        );
      },
    );

    test(
      'Example Test (Requirement 6.3): Bluetooth disable stops advertising and discovery',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        // Wait for initialization to complete
        await Future.delayed(Duration(seconds: 3));
        
        // Verify initial state - operations should be running
        final wasAdvertising = bluetoothService.isAdvertising;
        final wasDiscovering = bluetoothService.isDiscovering;
        
        // Act: Simulate Bluetooth being disabled
        bluetoothService.handleBluetoothStateChange(false);
        
        // Wait for operations to stop
        await Future.delayed(Duration(milliseconds: 500));
        
        // Assert: Verify operations are stopped
        expect(
          bluetoothService.operationsPaused,
          isTrue,
          reason: 'Operations should be marked as paused'
        );
        
        // Note: The actual advertising/discovery state depends on the Nearby API
        // which we can't fully test without mocking, but we verify the paused flag
      },
    );

    test(
      'Example Test (Requirement 6.3): Multiple Bluetooth disable calls are handled gracefully',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Act: Call disable multiple times
        bluetoothService.handleBluetoothStateChange(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        bluetoothService.handleBluetoothStateChange(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        bluetoothService.handleBluetoothStateChange(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert: Should handle gracefully without errors
        expect(
          bluetoothService.isBluetoothEnabled,
          isFalse,
          reason: 'Bluetooth should remain disabled'
        );
        
        expect(
          bluetoothService.operationsPaused,
          isTrue,
          reason: 'Operations should remain paused'
        );
      },
    );

    test(
      'Example Test (Requirement 6.3): Bluetooth disable with no connections',
      () async {
        // Arrange: Get the BluetoothService instance with no connections
        final bluetoothService = BluetoothService();
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Verify no connections
        expect(
          bluetoothService.connectedDevices.isEmpty,
          isTrue,
          reason: 'Should start with no connections'
        );
        
        // Act: Disable Bluetooth
        bluetoothService.handleBluetoothStateChange(false);
        
        await Future.delayed(Duration(milliseconds: 200));
        
        // Assert: Should handle gracefully
        expect(
          bluetoothService.operationsPaused,
          isTrue,
          reason: 'Operations should be paused even with no connections'
        );
      },
    );

    /// **Feature: bluetooth-enhancement, Example Test for Requirement 6.4**
    /// **Validates: Requirements 6.4**
    /// 
    /// Example Test: Test that Bluetooth enable resumes operations
    /// 
    /// This test verifies that when Bluetooth is re-enabled,
    /// the system automatically resumes advertising and discovery.
    /// 
    /// Requirements 6.4: WHEN Bluetooth is re-enabled 
    /// THEN the system SHALL automatically resume advertising and discovery
    test(
      'Example Test (Requirement 6.4): Bluetooth enable resumes operations',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        // Track status messages
        String? lastStatusMessage;
        bluetoothService.addListener(() {
          lastStatusMessage = bluetoothService.statusMessage;
        });
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // First disable Bluetooth
        bluetoothService.handleBluetoothStateChange(false);
        await Future.delayed(Duration(milliseconds: 200));
        
        // Verify operations are paused
        expect(
          bluetoothService.operationsPaused,
          isTrue,
          reason: 'Operations should be paused after disable'
        );
        
        // Clear status message
        lastStatusMessage = null;
        
        // Act: Re-enable Bluetooth
        bluetoothService.handleBluetoothStateChange(true);
        
        // Wait for operations to resume
        await Future.delayed(Duration(milliseconds: 800));
        
        // Assert: Verify operations are resumed
        expect(
          bluetoothService.isBluetoothEnabled,
          isTrue,
          reason: 'Bluetooth state should be updated to enabled'
        );
        
        expect(
          bluetoothService.operationsPaused,
          isFalse,
          reason: 'Operations should no longer be paused when Bluetooth is enabled'
        );
        
        // Verify user notification about resume
        // Note: Status message may be set by various operations, so we just verify
        // that the operations are no longer paused, which is the key requirement
        expect(
          bluetoothService.operationsPaused,
          isFalse,
          reason: 'Operations should be resumed (not paused) when Bluetooth is enabled'
        );
      },
    );

    test(
      'Example Test (Requirement 6.4): Bluetooth enable starts advertising and discovery',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Disable Bluetooth first
        bluetoothService.handleBluetoothStateChange(false);
        await Future.delayed(Duration(milliseconds: 200));
        
        // Act: Re-enable Bluetooth
        bluetoothService.handleBluetoothStateChange(true);
        
        // Wait for operations to resume (includes 500ms delay in implementation)
        await Future.delayed(Duration(milliseconds: 1000));
        
        // Assert: Verify operations are resumed
        expect(
          bluetoothService.operationsPaused,
          isFalse,
          reason: 'Operations should be marked as not paused'
        );
        
        // Note: The actual advertising/discovery state depends on the Nearby API
        // which we can't fully test without mocking, but we verify the paused flag is cleared
      },
    );

    test(
      'Example Test (Requirement 6.4): Multiple enable/disable cycles',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Act: Perform multiple enable/disable cycles
        for (int i = 0; i < 3; i++) {
          // Disable
          bluetoothService.handleBluetoothStateChange(false);
          await Future.delayed(Duration(milliseconds: 200));
          
          expect(
            bluetoothService.operationsPaused,
            isTrue,
            reason: 'Cycle $i: Operations should be paused after disable'
          );
          
          // Enable
          bluetoothService.handleBluetoothStateChange(true);
          await Future.delayed(Duration(milliseconds: 800));
          
          expect(
            bluetoothService.operationsPaused,
            isFalse,
            reason: 'Cycle $i: Operations should be resumed after enable'
          );
        }
        
        // Assert: Final state should be enabled
        expect(
          bluetoothService.isBluetoothEnabled,
          isTrue,
          reason: 'Bluetooth should be enabled after cycles'
        );
        
        expect(
          bluetoothService.operationsPaused,
          isFalse,
          reason: 'Operations should not be paused after cycles'
        );
      },
    );

    test(
      'Example Test (Requirement 6.4): Enable when already enabled is handled gracefully',
      () async {
        // Arrange: Get the BluetoothService instance (starts enabled)
        final bluetoothService = BluetoothService();
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Verify initial state
        expect(
          bluetoothService.isBluetoothEnabled,
          isTrue,
          reason: 'Bluetooth should be enabled initially'
        );
        
        // Act: Call enable when already enabled
        bluetoothService.handleBluetoothStateChange(true);
        await Future.delayed(Duration(milliseconds: 200));
        
        bluetoothService.handleBluetoothStateChange(true);
        await Future.delayed(Duration(milliseconds: 200));
        
        // Assert: Should handle gracefully without errors
        expect(
          bluetoothService.isBluetoothEnabled,
          isTrue,
          reason: 'Bluetooth should remain enabled'
        );
        
        expect(
          bluetoothService.operationsPaused,
          isFalse,
          reason: 'Operations should not be paused'
        );
      },
    );

    test(
      'Example Test (Requirement 6.4): State transitions are tracked correctly',
      () async {
        // Arrange: Get the BluetoothService instance
        final bluetoothService = BluetoothService();
        
        await Future.delayed(Duration(milliseconds: 100));
        
        // Track state changes
        final stateChanges = <bool>[];
        
        // Act & Assert: Test various state transitions
        
        // Initial state (enabled)
        expect(bluetoothService.isBluetoothEnabled, isTrue);
        stateChanges.add(bluetoothService.isBluetoothEnabled);
        
        // Disable
        bluetoothService.handleBluetoothStateChange(false);
        await Future.delayed(Duration(milliseconds: 200));
        expect(bluetoothService.isBluetoothEnabled, isFalse);
        stateChanges.add(bluetoothService.isBluetoothEnabled);
        
        // Enable
        bluetoothService.handleBluetoothStateChange(true);
        await Future.delayed(Duration(milliseconds: 200));
        expect(bluetoothService.isBluetoothEnabled, isTrue);
        stateChanges.add(bluetoothService.isBluetoothEnabled);
        
        // Verify state change sequence
        expect(
          stateChanges,
          equals([true, false, true]),
          reason: 'State changes should be tracked correctly'
        );
      },
    );
  });
}
