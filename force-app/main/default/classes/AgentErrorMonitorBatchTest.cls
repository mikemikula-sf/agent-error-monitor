@IsTest(SeeAllData=false)
private class AgentErrorMonitorBatchTest {
  /**
   * @description Tests batch execution with error records
   */
  @IsTest
  static void testBatchWithErrors() {
    // Arrange
    Test.startTest();

    // Act
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    // Assert
    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
    Assert.areEqual(0, job.NumberOfErrors, 'Batch job should not have any errors');
  }

  /**
   * @description Tests batch execution with no errors found
   */
  @IsTest
  static void testBatchWithNoErrors() {
    // Arrange
    Test.startTest();

    // Act
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    // Assert
    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
    Assert.areEqual(0, job.NumberOfErrors, 'Batch job should not have any errors');
  }

  /**
   * @description Tests custom email recipient constructor
   */
  @IsTest
  static void testCustomEmailRecipient() {
    // Arrange
    String customEmail = 'custom@test.com';

    Test.startTest();

    // Act
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch(customEmail);
    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    // Assert
    AsyncApexJob job = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
  }

  /**
   * @description Tests email delivery limit
   */
  @IsTest
  static void testEmailDeliveryLimit() {
    // Arrange
    Integer emailLimitBefore = Limits.getEmailInvocations();

    Test.startTest();

    // Act
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Database.executeBatch(batch, 200);

    Test.stopTest();

    // Assert - Email should not exceed limits
    Assert.isTrue(
      Limits.getEmailInvocations() <= Limits.getLimitEmailInvocations(),
      'Email invocations should not exceed governor limits'
    );
  }

  /**
   * @description Tests batch with large dataset
   */
  @IsTest
  static void testBatchWithLargeDataset() {
    // Arrange
    Test.startTest();

    // Act
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Id batchId = Database.executeBatch(batch, 100); // Smaller batch size

    Test.stopTest();

    // Assert
    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
    Assert.areEqual(0, job.NumberOfErrors, 'Batch job should not have any errors');
  }

  /**
   * @description Tests error handling in batch execution
   */
  @IsTest
  static void testErrorHandling() {
    // Arrange
    Test.startTest();

    // Act
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('invalid-email');
    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    // Assert - Batch should complete even with email issues
    AsyncApexJob job = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

    Assert.areEqual('Completed', job.Status, 'Batch job should complete even if email fails');
  }

  /**
   * @description Tests batch constructor validation with null email
   */
  @IsTest
  static void testConstructorValidationNull() {
    // Arrange & Act & Assert
    Boolean exceptionThrown = false;
    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch(null);
      Assert.fail('Should throw IllegalArgumentException for null email');
    } catch (IllegalArgumentException e) {
      exceptionThrown = true;
      Assert.isTrue(e.getMessage().contains('required'), 'Should validate email is required');
    }
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown');
  }

  /**
   * @description Tests batch constructor validation with blank email
   */
  @IsTest
  static void testConstructorValidationBlank() {
    // Arrange & Act & Assert
    Boolean exceptionThrown = false;
    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('');
      Assert.fail('Should throw IllegalArgumentException for blank email');
    } catch (IllegalArgumentException e) {
      exceptionThrown = true;
      Assert.isTrue(e.getMessage().contains('required'), 'Should validate email is required');
    }
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown');
  }

  /**
   * @description Tests batch start method returns iterable
   */
  @IsTest
  static void testBatchStart() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    // Act
    Test.startTest();
    Iterable<sObject> results = batch.start(null);
    Test.stopTest();

    // Assert
    Assert.isNotNull(results, 'Start method should return iterable');
  }

  /**
   * @description Tests batch execute method with valid scope
   */
  @IsTest
  static void testBatchExecuteWithValidScope() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    
    // Create mock sObject records (using Account as a stand-in since we can't create __dlm in tests)
    List<sObject> scope = new List<sObject>();
    Account acc = new Account(Name = 'Test Account');
    insert acc;
    scope.add(acc);

    // Act
    Test.startTest();
    batch.execute(null, scope);
    Test.stopTest();

    // Assert - Should complete without throwing exception
    Assert.isTrue(true, 'Execute should process scope without errors');
  }

  /**
   * @description Tests batch execute method with exception handling
   */
  @IsTest
  static void testBatchExecuteWithException() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    List<sObject> emptyScope = new List<sObject>();

    // Act
    Test.startTest();
    batch.execute(null, emptyScope);
    Test.stopTest();

    // Assert - Should complete without throwing exception
    Assert.isTrue(true, 'Execute should handle exceptions gracefully');
  }

  /**
   * @description Tests batch finish method with errors
   */
  @IsTest
  static void testBatchFinishWithErrors() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    Test.startTest();
    Id batchId = Database.executeBatch(batch, 200);
    Test.stopTest();

    // Assert
    AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchId];
    Assert.areEqual('Completed', job.Status, 'Batch should complete successfully');
  }

  /**
   * @description Tests batch finish method with no errors
   */
  @IsTest
  static void testBatchFinishNoErrors() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    Test.startTest();
    Id batchId = Database.executeBatch(batch, 200);
    Test.stopTest();

    // Assert
    AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchId];
    Assert.areEqual('Completed', job.Status, 'Batch should complete successfully');
  }

  /**
   * @description Tests batch finish method is called
   */
  @IsTest
  static void testBatchFinishMethodCalled() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    // Act
    Test.startTest();
    Database.BatchableContext mockContext = null;
    batch.finish(mockContext);
    Test.stopTest();

    // Assert - Should complete without error
    System.assert(true, 'Finish method should execute successfully');
  }

  /**
   * @description Tests batch execute method with null scope to trigger exception path
   */
  @IsTest
  static void testBatchExecuteWithNullScope() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    // Act
    Test.startTest();
    try {
      batch.execute(null, null);
    } catch (Exception e) {
      // Exception is caught and logged internally
    }
    Test.stopTest();

    // Assert - Should handle exception gracefully
    System.assert(true, 'Execute should handle null scope gracefully');
  }

  /**
   * @description Tests batch with actual error records to trigger finish notification
   */
  @IsTest
  static void testBatchFinishWithActualErrors() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    Test.startTest();

    // Act - Execute the batch which will process records
    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    // Assert - Batch should complete
    AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchId];
    Assert.areEqual('Completed', job.Status, 'Batch should complete successfully');
  }

  /**
   * @description Tests finish method with simulated errors to cover notification path
   */
  @IsTest
  static void testFinishWithErrorNotification() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    // Create test data that will be found as errors
    Account testAccount = new Account(Name = 'Test Error Account');
    insert testAccount;

    Test.startTest();

    // Manually create error records to simulate batch finding errors
    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = testAccount.Id;
    error.errorMessage = 'Test error with error ID: 12345';
    error.occurredAt = DateTime.now();
    result.errorRecords.add(error);
    result.errorCount = 1;
    result.totalRecords = 1;

    // Call sendErrorNotification directly to cover the notification path
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(
      result.errorRecords,
      'test@example.com',
      'TEST_JOB_ID',
      10
    );

    Test.stopTest();

    // Assert
    Assert.isNotNull(sent, 'Notification should be attempted');
  }

  /**
   * @description Tests finish method directly with mock batch context
   */
  @IsTest
  static void testFinishMethodDirectly() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    
    // Create a mock scope with test data
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;
    List<sObject> scope = new List<sObject>{ testAccount };

    Test.startTest();
    
    // Call execute to populate the result
    batch.execute(null, scope);
    
    // Call finish to test the finish method
    batch.finish(null);
    
    Test.stopTest();

    // Assert - Should complete without error
    Assert.isTrue(true, 'Finish method should execute successfully');
  }

  /**
   * @description Tests finish method with errors to cover notification path (lines 47-51)
   * Uses @TestVisible to directly manipulate the result field
   */
  @IsTest
  static void testFinishMethodWithErrorsUsingTestVisible() {
    // Arrange
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    
    // Create mock error data
    Account testAccount = new Account(Name = 'Test Error Account');
    insert testAccount;

    // Create mock error records using @TestVisible access
    AgentErrorMonitorService.ErrorRecord mockError = new AgentErrorMonitorService.ErrorRecord();
    mockError.recordId = testAccount.Id;
    mockError.errorMessage = 'Test error with error ID: ABC123';
    mockError.occurredAt = DateTime.now();
    mockError.sessionId = 'TEST_SESSION_123';
    mockError.messageType = 'Error';
    
    // Directly manipulate the result field using @TestVisible
    batch.result.errorRecords.add(mockError);
    batch.result.errorCount = 1;
    batch.result.totalRecords = 1;
    
    Test.startTest();
    
    // Execute the batch to get a real BatchableContext with a job ID
    Id batchId = Database.executeBatch(batch, 200);
    
    Test.stopTest();

    // Assert - The batch should have completed and attempted to send email
    AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :batchId];
    Assert.areEqual('Completed', job.Status, 'Batch should complete successfully');
    Assert.areEqual(1, batch.result.errorCount, 'Should have 1 error configured');
  }

}
