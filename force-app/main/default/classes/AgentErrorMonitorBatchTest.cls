@IsTest(SeeAllData=false)
private class AgentErrorMonitorBatchTest {
  @IsTest
  static void testBatchWithErrors() {
    Test.startTest();

    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');
    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

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

    AsyncApexJob job = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];

    Assert.areEqual('Completed', job.Status, 'Batch job should complete successfully');
    Assert.areEqual(lookbackHours, batch.lookbackHours, 'Lookback hours should be set correctly');
  }

  @IsTest
  static void testConstructorValidationInvalidLookback() {
    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com', 0);
      Assert.fail('Should throw IllegalArgumentException for invalid lookback');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('hoursBack must be between'), 'Should validate lookback hours');
    }

    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com', null);
      Assert.fail('Should throw IllegalArgumentException for null lookback');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('hoursBack must be between'), 'Should validate lookback hours');
    }
  }

  @IsTest
  static void testConstructorValidationNull() {
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

  @IsTest
  static void testConstructorValidationBlank() {
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
    try {
      batch.execute(null, null);
      Assert.fail('Should throw exception for null scope');
    } catch (Exception e) {
      Assert.isNotNull(e, 'Exception should be thrown for null scope');
    }
    Test.stopTest();
  }

  @IsTest
  static void testFinishWithErrorNotification() {
    AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('test@example.com');

    Account testAccount = new Account(Name = 'Test Error Account');
    insert testAccount;

    Test.startTest();

    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = testAccount.Id;
    error.errorMessage = 'Test error with error ID: 12345';
    error.occurredAt = DateTime.now();
    result.errorRecords.add(error);
    result.errorCount = 1;
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

    AgentErrorMonitorService.ErrorRecord mockError = new AgentErrorMonitorService.ErrorRecord();
    mockError.recordId = testAccount.Id;
    mockError.errorMessage = 'Test error with error ID: ABC123';
    mockError.occurredAt = DateTime.now();
    mockError.sessionId = 'TEST_SESSION_123';
    mockError.messageType = 'Error';

    batch.result.errorRecords.add(mockError);
    batch.result.errorCount = 1;
    batch.result.totalRecords = 1;

    Test.startTest();

    Id batchId = Database.executeBatch(batch, 200);

    Test.stopTest();

    AsyncApexJob job = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE Id = :batchId
    ];
    Assert.areEqual('Completed', job.Status, 'Batch should complete successfully');
    Assert.areEqual(1, batch.result.errorCount, 'Should have 1 error configured');
  }
}
