import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_hopping_app/services/bluetooth/bluetooth_service.dart';

/// Test for debug mode detailed metrics
/// 
/// Requirement 8.5: Debug mode enables detailed logging
void main() {
  // Ensure Flutter bindings are initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BluetoothService Debug Mode', () {
    late BluetoothService service;

    setUp(() {
      service = BluetoothService();
    });

    test('debug mode enables detailed logging', () {
      // Initially debug mode should be disabled
      expect(service.debugMode, isFalse);

      // Get statistics in normal mode
      final normalStats = service.getConnectionStatistics();
      expect(normalStats['debug_mode'], isFalse);
      expect(normalStats.containsKey('endpoint_metrics'), isFalse);
      expect(normalStats.containsKey('attempt_details'), isFalse);

      // Enable debug mode
      service.enableDebugMode();
      expect(service.debugMode, isTrue);

      // Get statistics in debug mode
      final debugStats = service.getConnectionStatistics();
      expect(debugStats['debug_mode'], isTrue);
      
      // Debug mode should include detailed metrics
      expect(debugStats.containsKey('endpoint_metrics'), isTrue);
      expect(debugStats.containsKey('attempt_details'), isTrue);
      expect(debugStats.containsKey('event_count_by_type'), isTrue);
      expect(debugStats.containsKey('connected_devices'), isTrue);
      expect(debugStats.containsKey('is_advertising'), isTrue);
      expect(debugStats.containsKey('is_discovering'), isTrue);

      // Disable debug mode
      service.disableDebugMode();
      expect(service.debugMode, isFalse);

      // Statistics should return to normal mode
      final normalStatsAgain = service.getConnectionStatistics();
      expect(normalStatsAgain['debug_mode'], isFalse);
      expect(normalStatsAgain.containsKey('endpoint_metrics'), isFalse);
      expect(normalStatsAgain.containsKey('attempt_details'), isFalse);
    });

    test('debug mode logs connection quality checks', () {
      // Enable debug mode
      service.enableDebugMode();

      // Log connection quality with various signal strengths
      service.logConnectionQuality('endpoint1', -50); // Strong - quality_check
      service.logConnectionQuality('endpoint2', -65); // Moderate - quality_check
      service.logConnectionQuality('endpoint3', -75); // Weak - quality_degradation
      service.logConnectionQuality('endpoint4', -85); // Very weak - quality_degradation
      service.logConnectionQuality('endpoint5', null); // Unknown - quality_check

      // Get detailed statistics
      final stats = service.getConnectionStatistics();
      expect(stats['debug_mode'], isTrue);

      // Should have recorded events (2 quality_check + 2 quality_degradation + 1 quality_check = 5 endpoints)
      final eventCountByType = stats['event_count_by_type'] as Map<String, dynamic>;
      // Strong and moderate log quality_check, weak and very_weak log quality_degradation
      expect(eventCountByType.containsKey('quality_check'), isTrue);
      expect(eventCountByType['quality_check'], equals(3)); // endpoint1, endpoint2, endpoint5
    });

    test('connection quality degradation is logged for weak signals', () {
      // Create a fresh service instance for this test
      final testService = BluetoothService();
      
      // Log weak signal (should trigger degradation logging)
      testService.logConnectionQuality('endpoint_weak_test', -75);

      // Get statistics
      final stats = testService.getConnectionStatistics();
      final endpointMetrics = stats['endpoint_metrics'] as Map<String, dynamic>;
      
      // Should have logged quality degradation for this endpoint
      expect(endpointMetrics.containsKey('endpoint_weak_test'), isTrue);
      final endpointData = endpointMetrics['endpoint_weak_test'] as Map<String, dynamic>;
      expect(endpointData['last_event_type'], equals('quality_degradation'));
    });

    test('connection quality degradation is logged for very weak signals', () {
      // Create a fresh service instance for this test
      final testService = BluetoothService();
      
      // Log very weak signal (should trigger degradation logging)
      testService.logConnectionQuality('endpoint_very_weak_test', -90);

      // Get statistics
      final stats = testService.getConnectionStatistics();
      final endpointMetrics = stats['endpoint_metrics'] as Map<String, dynamic>;
      
      // Should have logged quality degradation for this endpoint
      expect(endpointMetrics.containsKey('endpoint_very_weak_test'), isTrue);
      final endpointData = endpointMetrics['endpoint_very_weak_test'] as Map<String, dynamic>;
      expect(endpointData['last_event_type'], equals('quality_degradation'));
    });

    test('strong signal does not trigger quality degradation logging', () {
      // Create a fresh service instance for this test
      final testService = BluetoothService();
      
      // Enable debug mode to check endpoint metrics
      testService.enableDebugMode();
      
      // Log strong signal (should NOT trigger degradation logging)
      testService.logConnectionQuality('endpoint_strong_unique', -50);

      // Get statistics
      final stats = testService.getConnectionStatistics();
      final endpointMetrics = stats['endpoint_metrics'] as Map<String, dynamic>;
      
      // Should have logged quality_check (not quality_degradation) for strong signal
      expect(endpointMetrics.containsKey('endpoint_strong_unique'), isTrue);
      final endpointData = endpointMetrics['endpoint_strong_unique'] as Map<String, dynamic>;
      expect(endpointData['last_event_type'], equals('quality_check'));
    });

    test('moderate signal does not trigger quality degradation logging', () {
      // Create a fresh service instance for this test
      final testService = BluetoothService();
      
      // Enable debug mode to check endpoint metrics
      testService.enableDebugMode();
      
      // Log moderate signal (should NOT trigger degradation logging)
      testService.logConnectionQuality('endpoint_moderate_unique', -65);

      // Get statistics
      final stats = testService.getConnectionStatistics();
      final endpointMetrics = stats['endpoint_metrics'] as Map<String, dynamic>;
      
      // Should have logged quality_check (not quality_degradation) for moderate signal
      expect(endpointMetrics.containsKey('endpoint_moderate_unique'), isTrue);
      final endpointData = endpointMetrics['endpoint_moderate_unique'] as Map<String, dynamic>;
      expect(endpointData['last_event_type'], equals('quality_check'));
    });
  });
}
