# Implementation Plan

- [x] 1. Create new data models and constants





  - Create ReconnectionEntry model with retry tracking
  - Create ConnectionAttempt model for metrics
  - Create ConnectionEvent model for logging
  - Add new constants to BluetoothConstants for reconnection, adaptive strategy, and connection limits
  - _Requirements: 3.1, 3.2, 5.1, 7.1_

- [x] 1.1 Write property test for ReconnectionEntry model






  - **Property 9: Exhausted retries remove from queue**
  - **Validates: Requirements 3.4**

- [x] 2. Implement ConnectionMetrics manager





  - Create ConnectionMetrics class with attempt tracking
  - Implement recordAttempt() method to store connection outcomes
  - Implement calculateSuccessRate() for sliding window calculation
  - Implement getRecommendedTimeout() with threshold logic
  - Implement updateTimeout() to adjust based on success rate
  - Implement recordEvent() for detailed logging
  - Implement getStatistics() for debugging
  - _Requirements: 5.1, 5.2, 5.3, 8.1, 8.2, 8.3, 8.4_

- [x] 2.1 Write property test for connection attempt recording






  - **Property 15: Connection attempts are recorded**
  - **Validates: Requirements 5.1**

- [x] 2.2 Write unit tests for success rate calculation






  - Test with various success/failure patterns
  - Test edge cases (empty list, all success, all failure)
  - _Requirements: 5.1_

- [x] 2.3 Write example tests for timeout adaptation


  - Test low success rate (< 50%) increases timeout
  - Test high success rate (> 80%) decreases timeout
  - _Requirements: 5.2, 5.3_

- [x] 2.4 Write property test for event logging






  - **Property 23: State changes trigger logging**
  - **Validates: Requirements 8.1**

- [x] 3. Implement ReconnectionManager





  - Create ReconnectionManager class with queue management
  - Implement addToQueue() to add disconnected endpoints
  - Implement removeFromQueue() for successful reconnections
  - Implement startReconnectionLoop() with periodic timer
  - Implement attemptReconnections() to process queue
  - Implement shouldAttemptReconnection() with backoff logic
  - Add callbacks for reconnection events
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 3.1 Write property test for queue addition on disconnection





  - **Property 6: Disconnection triggers reconnection queue**
  - **Validates: Requirements 3.1**

- [x] 3.2 Write property test for reconnection timing





  - **Property 7: Reconnection attempt timing**
  - **Validates: Requirements 3.2**

- [x] 3.3 Write property test for successful reconnection removal






  - **Property 8: Successful reconnection removes from queue**
  - **Validates: Requirements 3.3**

- [ ] 3.4 Write unit tests for backoff calculation









  - Test exponential backoff timing
  - Test max retry limit enforcement
  - _Requirements: 3.2, 3.4_


- [x] 4. Enhance ConnectionManager with new features




  - Add maxConnections field and canAcceptNewConnection() method
  - Add consecutiveErrors counter and error tracking methods
  - Implement restartDiscovery() to refresh scan
  - Implement performFullReset() for error recovery
  - Add discovery restart timing logic
  - Integrate with ConnectionMetrics for attempt recording
  - _Requirements: 2.4, 2.5, 5.4, 7.1, 10.5_

- [x] 4.1 Write example test for connection limit enforcement


  - Test that 9th connection is rejected
  - _Requirements: 7.1_


- [x] 4.2 Write property test for discovery restart preserving connections





  - **Property 16: Discovery restart preserves connections**
  - **Validates: Requirements 5.5**

- [x] 4.3 Write example test for full reset on consecutive errors

  - Test that 3 errors trigger reset
  - _Requirements: 10.5_


- [x] 4.4 Write property test for automatic connection initiation





  - **Property 4: Automatic connection initiation**
  - **Validates: Requirements 2.4**

- [x] 4.5 Write property test for connection retry scheduling




  - **Property 5: Connection retry scheduling**
  - **Validates: Requirements 2.5**


- [x] 5. Enhance BluetoothService with manager integration


  - Initialize ReconnectionManager in _initializeManagers()
  - Initialize ConnectionMetrics in _initializeManagers()
  - Wire up callbacks between managers
  - Integrate metrics recording in connection callbacks
  - Integrate reconnection queue in disconnection handler
  - Add getConnectionStatistics() method for debugging
  - _Requirements: 3.1, 5.1, 8.1, 8.2, 8.3, 8.4_

- [x] 5.1 Write property test for metrics integration






  - **Property 24: Connection failures trigger error logging**
  - **Validates: Requirements 8.2**

- [x] 5.2 Write property test for reconnection integration






  - **Property 13: Stale removal triggers reconnection**
  - **Validates: Requirements 4.4**


- [x] 6. Implement health check enhancements



  - Modify verifyAndCleanConnections() to use ConnectionMetrics
  - Add stale connection detection with 2-second timeout
  - Integrate with ReconnectionManager for stale connections
  - Add health check count logging
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 8.3_


- [x] 6.1 Write property test for health check verification





  - **Property 10: Health check verifies all devices**
  - **Validates: Requirements 4.1**

- [x] 6.2 Write property test for timeout marking stale






  - **Property 11: Timeout marks connection stale**
  - **Validates: Requirements 4.2**


- [x] 6.3 Write property test for stale triggering disconnection





  - **Property 12: Stale connections trigger disconnection**
  - **Validates: Requirements 4.3**


- [x] 6.4 Write property test for health check scheduling





  - **Property 14: Health check scheduling with connections**
  - **Validates: Requirements 4.5**


- [x] 7. Implement adaptive discovery frequency


  - Add logic to check connection count in discovery
  - Implement high-frequency discovery when connections = 0
  - Implement normal-frequency discovery when connections > 0
  - Add discovery restart on low device count
  - _Requirements: 2.6, 5.4_


- [x] 7.1 Write example test for zero connections increasing frequency




  - Test that frequency changes when count reaches zero
  - _Requirements: 2.6_


- [x] 7.2 Write example test for discovery restart on low count


  - Test that < 2 devices in 30s triggers restart
  - _Requirements: 5.4_


- [x] 8. Implement app lifecycle handling



  - Add AppLifecycleState listener in BluetoothService
  - Implement handleAppLifecycleChange() method
  - Add background transition logic to maintain connections
  - Add foreground transition logic to verify health
  - _Requirements: 6.1, 6.2_

- [x] 8.1 Write property test for background preserving connections





  - **Property 17: Background transition preserves connections**
  - **Validates: Requirements 6.1**




- [x] 8.2 Write example test for foreground health check




  - Test that foreground return triggers verification
  - _Requirements: 6.2_

- [x] 9. Implement Bluetooth state monitoring





  - Add Bluetooth state change listener
  - Implement handleBluetoothStateChange() method
  - Add pause logic for Bluetooth disabled
  - Add resume logic for Bluetooth enabled
  - Add user notification for Bluetooth disabled
  - _Requirements: 6.3, 6.4_

- [x] 9.1 Write example test for Bluetooth disable pause






  - Test that disable pauses operations
  - _Requirements: 6.3_


- [x] 9.2 Write example test for Bluetooth enable resume





  - Test that enable resumes operations
  - _Requirements: 6.4_


- [x] 10. Implement enhanced error handling







  - Add STATUS_ALREADY_ADVERTISING handling in startAdvertising()
  - Add STATUS_ALREADY_DISCOVERING handling in startDiscovery()
  - Add unexpected error handling with retry logic
  - Add stop operation error handling
  - Integrate error counter with full reset logic
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 10.1 Write example test for ALREADY_ADVERTISING handling


  - Test that error is treated as success
  - _Requirements: 10.1_

- [x] 10.2 Write example test for ALREADY_DISCOVERING handling




  - Test that error is treated as success
  - _Requirements: 10.2_


- [x] 10.3 Write property test for unexpected error retry









  - **Property 32: Unexpected errors trigger retry**
  - **Validates: Requirements 10.3**

- [x] 10.4 Write property test for stop failure state update



  - **Property 33: Stop operation failures trigger state update**
  - **Validates: Requirements 10.4**

- [ ] 11. Implement advertising and discovery persistence

  - Add checks in all operations to maintain advertising
  - Add checks in all operations to maintain discovery
  - Add automatic restart if advertising stops unexpectedly
  - Add automatic restart if discovery stops unexpectedly
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 11.1 Write example test for receiver mode initialization




  - Test that both advertising and discovery start
  - _Requirements: 2.1_


- [x] 11.2 Write property test for advertising persistence




  - **Property 2: Advertising persistence**
  - **Validates: Requirements 2.2**

- [x] 11.3 Write property test for discovery persistence






  - **Property 3: Discovery persistence**
  - **Validates: Requirements 2.3**

- [x] 12. Enhance send operation with retry and health check





  - Modify _sendToAllDevices() to use enhanced retry logic
  - Add health check marking for exhausted retries
  - Integrate with ConnectionMetrics for send tracking
  - _Requirements: 7.3, 7.4, 7.5_

- [x] 12.1 Write property test for parallel send






  - **Property 20: Parallel send to all devices**
  - **Validates: Requirements 7.3**

- [x] 12.2 Write property test for send retry






  - **Property 21: Failed send triggers retry**
  - **Validates: Requirements 7.4**

- [x] 12.3 Write property test for exhausted retry health check






  - **Property 22: Exhausted send retries trigger health check**
  - **Validates: Requirements 7.5**

- [x] 13. Implement connection quality logging





  - Add signal strength logging when available
  - Add connection quality event logging
  - Add debug mode detailed metrics
  - _Requirements: 1.4, 8.5_

- [x] 13.1 Write property test for quality degradation logging











  - **Property 1: Connection quality degradation triggers logging**
  - **Validates: Requirements 1.4**

- [x] 13.2 Write example test for debug mode metrics



  - Test that debug mode enables detailed logging
  - _Requirements: 8.5_



- [x] 14. Implement connection establishment flow enhancements






  - Add parallel processing for multiple discoveries
  - Add 2-second acceptance timeout
  - Add immediate callback registration after acceptance
  - Add verification ping after confirmation
  - Add establishment marking after successful ping
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 14.1 Write property test for parallel connection processing






  - **Property 27: Multiple discoveries trigger parallel connections**
  - **Validates: Requirements 9.1**

- [x] 14.2 Write property test for acceptance timing





  - **Property 28: Connection acceptance timing**
  - **Validates: Requirements 9.2**

- [x] 14.3 Write property test for callback registration






  - **Property 29: Acceptance triggers callback registration**
  - **Validates: Requirements 9.3**

- [x] 14.4 Write property test for confirmation ping





  - **Property 30: Confirmed connection triggers ping**
  - **Validates: Requirements 9.4**

- [x] 14.5 Write property test for ping establishment





  - **Property 31: Successful ping marks establishment**
  - **Validates: Requirements 9.5**

- [x] 15. Implement discovery device logging





  - Add endpoint logging in _handleEndpointFound()
  - Add service ID validation logging
  - Integrate with ConnectionMetrics event logging
  - _Requirements: 8.4_

- [ ]* 15.1 Write property test for discovery logging
  - **Property 26: Discovery triggers device logging**
  - **Validates: Requirements 8.4**


- [x] 16. Implement connection limit at discovery




  - Add connection limit check in _handleEndpointFound()
  - Skip connection request if at limit
  - Log when limit prevents new connections
  - _Requirements: 7.1, 7.2_

- [x] 16.1 Write property test for limit maintaining connections







  - **Property 19: Connection limit maintains existing connections**
  - **Validates: Requirements 7.2**

- [x] 17. Add health check count logging





  - Modify health check to count active vs stale
  - Add logging of counts after health check
  - _Requirements: 8.3_

- [x] 17.1 Write property test for health check logging



  - **Property 25: Health check triggers count logging**
  - **Validates: Requirements 8.3**

- [x] 18. Implement Bluetooth error logging and recovery






  - Add error logging in all Bluetooth operations
  - Add recovery attempt logging
  - Integrate with ConnectionMetrics
  - _Requirements: 6.5, 8.2_

- [x] 18.1 Write property test for error logging and recovery





  - **Property 18: Bluetooth errors trigger logging and recovery**
  - **Validates: Requirements 6.5**

- [x] 19. Add configuration for range optimization





  - Document P2P_CLUSTER strategy usage
  - Add comments about timeout configuration for range
  - Document retry logic benefits for range
  - _Requirements: 1.1_

- [x] 19.1 Write example test for initialization configuration

  - Test that service initializes with correct parameters
  - _Requirements: 1.1_

- [x] 19.2 Write example test for transmit power configuration

  - Test that power configuration is attempted on supported platforms
  - _Requirements: 1.5_

- [x] 20. Final checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.

- [x] 21. Create integration tests




  - Write reconnection flow integration test
  - Write adaptive strategy flow integration test
  - Write health check flow integration test
  - Write lifecycle flow integration test
  - Write error recovery flow integration test
  - _Requirements: All_

- [x] 22. Update documentation





  - Update ARCHITECTURE.md with new components
  - Update README.md with new features
  - Add usage examples for new functionality
  - Document configuration options
  - _Requirements: All_
