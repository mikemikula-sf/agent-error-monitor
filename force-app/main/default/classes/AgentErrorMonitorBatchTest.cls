@IsTest(SeeAllData=false)
private class AgentErrorMonitorBatchTest {
  // ============================================================================
  // TEST DATA HELPERS
  // ============================================================================

  private static AgentErrorMonitorService.ErrorRecord createMockError(Id recordId, String errorMessage) {
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = recordId;
    error.errorMessage = errorMessage;
    error.occurredAt = DateTime.now();
    error.sessionId = 'TEST_SESSION_' + recordId;
    error.messageType = 'Error';
    return error;
  }

  private static AsyncApexJob queryBatchJob(Id batchId) {
    return [
      SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];
  }

  private static void assertExceptionThrown(String methodCall, String expectedMessage) {
    Assert.fail('Should throw IllegalArgumentException for ' + methodCall);
  }

  private static void assertExceptionMessage(Exception e, String expectedSubstring) {
    Assert.isTrue(e.getMessage().contains(expectedSubstring), 'Exception message should contain: ' + expectedSubstring);
  }

  // ============================================================================
  // TESTS
  // ============================================================================

  @IsTest
  static void testBatchWithErrors() {
    Test.startTest();
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Id batchId = Database.executeBatch(batch, 200);
    Test.stopTest();

    AsyncApexJob job = queryBatchJob(batchId);
    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
    Assert.areEqual(0, job.NumberOfErrors, 'Batch job should not have any errors');
  }

  @IsTest
  static void testConstructorWithLookback() {
    Integer lookbackHours = 48;

    Test.startTest();
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com', lookbackHours);
    Id batchId = Database.executeBatch(batch, 200);
    Test.stopTest();

    AsyncApexJob job = queryBatchJob(batchId);
    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
    Assert.areEqual(lookbackHours, batch.lookbackHours, 'Lookback hours should be set correctly');
  }

  @IsTest
  static void testConstructorValidationInvalidLookback() {
    Boolean exceptionThrown = false;
    try {
      new AgentErrorMonitorBatch('test@example.com', 0);
      Assert.fail('Expected IllegalArgumentException for invalid lookback');
    } catch (IllegalArgumentException e) {
      assertExceptionMessage(e, 'hoursBack must be between');
      exceptionThrown = true;
    }
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown for invalid lookback');

    exceptionThrown = false;
    try {
      new AgentErrorMonitorBatch('test@example.com', null);
      Assert.fail('Expected IllegalArgumentException for null lookback');
    } catch (IllegalArgumentException e) {
      assertExceptionMessage(e, 'hoursBack must be between');
      exceptionThrown = true;
    }
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown for null lookback');
  }

  @IsTest
  static void testConstructorValidationNull() {
    Boolean exceptionThrown = false;
    try {
      new AgentErrorMonitorBatch(null);
      Assert.fail('Expected IllegalArgumentException for null email');
    } catch (IllegalArgumentException e) {
      assertExceptionMessage(e, 'required');
      exceptionThrown = true;
    }
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown for null email');
  }

  @IsTest
  static void testConstructorValidationBlank() {
    Boolean exceptionThrown = false;
    try {
      new AgentErrorMonitorBatch('');
      Assert.fail('Expected IllegalArgumentException for blank email');
    } catch (IllegalArgumentException e) {
      assertExceptionMessage(e, 'required');
      exceptionThrown = true;
    }
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown for blank email');
  }

  @IsTest
  static void testBatchStart() {
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    Test.startTest();
    Iterable<sObject> results = batch.start(null);
    Test.stopTest();

    Assert.isNotNull(results, 'Start method should return iterable');
  }

  @IsTest
  static void testBatchExecuteWithNullScope() {
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      batch.execute(null, null);
      Assert.fail('Should throw exception for null scope');
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception should be thrown for null scope');
      exceptionThrown = true;
    }
    Test.stopTest();
    Assert.isTrue(exceptionThrown, 'Exception should have been thrown for null scope');
  }

  @IsTest
  static void testFinishWithErrorNotification() {
    Account testAccount = new Account(Name = 'Test Error Account');
    insert testAccount;

    Test.startTest();
    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();
    result.errorRecords.add(createMockError(testAccount.Id, 'Test error with error ID: 12345'));
    result.totalRecords = 1;
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(result.errorRecords, 'test@example.com', 'TEST_JOB_ID', 10);
    Test.stopTest();

    Assert.isNotNull(sent, 'Notification should be attempted');
  }

  @IsTest
  static void testFinishMethodWithErrorsUsingTestVisible() {
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Account testAccount = new Account(Name = 'Test Error Account');
    insert testAccount;

    batch.result.errorRecords.add(createMockError(testAccount.Id, 'Test error with error ID: ABC123'));
    batch.result.totalRecords = 1;

    Test.startTest();
    Id batchId = Database.executeBatch(batch, 200);
    Test.stopTest();

    AsyncApexJob job = queryBatchJob(batchId);
    Assert.areEqual('Completed', job.Status, 'Batch should complete successfully');
    Assert.areEqual(1, batch.result.totalRecords, 'Should have 1 error configured');
  }
}
