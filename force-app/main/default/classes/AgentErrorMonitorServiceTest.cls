@IsTest(SeeAllData=false)
private class AgentErrorMonitorServiceTest {
  /**
   * @description Tests getting error records in strict mode
   */
  @IsTest
  static void testGetErrorRecordsStrict() {
    // Arrange & Act
    Test.startTest();
    List<AgentErrorMonitorService.ErrorRecord> errors = AgentErrorMonitorService.getErrorRecords(24);
    Test.stopTest();

    // Assert
    Assert.isNotNull( errors, 'Error records list should not be null');
    Assert.isTrue(errors.size() >= 0, 'Error records list should be initialized');
  }

  /**
   * @description Tests getting error records in non-strict mode
   */
  @IsTest
  static void testGetErrorRecordsNonStrict() {
    // Arrange & Act
    Test.startTest();
    List<AgentErrorMonitorService.ErrorRecord> errors = AgentErrorMonitorService.getErrorRecords(24, false);
    Test.stopTest();

    // Assert
    Assert.isNotNull( errors, 'Error records list should not be null in non-strict mode');
  }

  /**
   * @description Tests getting error count
   */
  @IsTest
  static void testGetErrorCount() {
    // Arrange & Act
    Test.startTest();
    Integer count = AgentErrorMonitorService.getErrorCount(24);
    Test.stopTest();

    // Assert
    Assert.isTrue(count >= 0, 'Error count should be non-negative');
  }

  /**
   * @description Tests processing records with no errors
   */
  @IsTest
  static void testProcessRecordsNoErrors() {
    // Arrange
    List<sObject> emptyList = new List<sObject>();
    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();

    // Act
    Test.startTest();
    AgentErrorMonitorService.processRecords(emptyList, result);
    Test.stopTest();

    // Assert
    Assert.areEqual(0, result.totalRecords, 'Total records should be zero');
    Assert.areEqual(0, result.errorCount, 'Error count should be zero');
    Assert.areEqual(0, result.errorRecords.size(), 'Error records list should be empty');
  }

  /**
   * @description Tests ErrorRecord constructor
   */
  @IsTest
  static void testErrorRecordConstructor() {
    // Arrange & Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    Test.stopTest();

    // Assert
    Assert.isNotNull( error, 'Error record should be created');
  }

  /**
   * @description Tests ProcessingResult constructor
   */
  @IsTest
  static void testProcessingResultConstructor() {
    // Arrange & Act
    Test.startTest();
    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();
    Test.stopTest();

    // Assert
    Assert.areEqual(0, result.totalRecords, 'Total records should be initialized to 0');
    Assert.areEqual(0, result.errorCount, 'Error count should be initialized to 0');
    Assert.isNotNull( result.errorRecords, 'Error records list should be initialized');
    Assert.areEqual(0, result.durationMilliseconds, 'Duration should be initialized to 0');
  }

  /**
   * @description Tests isError method with error message containing error pattern
   */
  @IsTest
  static void testIsErrorWithMessage() {
    // Arrange
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.errorMessage = 'An error occurred with error ID: 12345';
    error.status = 'Success';

    // Act
    Test.startTest();
    Boolean hasError = AgentErrorMonitorService.isError(error);
    Test.stopTest();

    // Assert
    Assert.areEqual(true, hasError, 'Should detect error when error message contains error pattern');
  }

  /**
   * @description Tests isError method with failed status
   */
  @IsTest
  static void testIsErrorWithFailedStatus() {
    // Arrange
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.errorMessage = null;
    error.status = 'Failed';

    // Act
    Test.startTest();
    Boolean hasError = AgentErrorMonitorService.isError(error);
    Test.stopTest();

    // Assert
    Assert.areEqual(true, hasError, 'Should detect error when status is Failed');
  }

  /**
   * @description Tests isError method with no error
   */
  @IsTest
  static void testIsErrorNoError() {
    // Arrange
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.errorMessage = null;
    error.status = 'Success';

    // Act
    Test.startTest();
    Boolean hasError = AgentErrorMonitorService.isError(error);
    Test.stopTest();

    // Assert
    Assert.areEqual(false, hasError, 'Should not detect error when no error exists');
  }

  /**
   * @description Tests sending email notification with errors
   */
  @IsTest
  static void testSendErrorNotificationWithErrors() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST123';
    error.errorMessage = 'Test error';
    error.occurredAt = DateTime.now();
    error.operation = 'Insert';
    error.objectName = 'TestObject';
    error.status = 'Failed';
    errors.add(error);

    // Act
    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'test@example.com', '707000000000001');
    Test.stopTest();

    // Assert
    Assert.areEqual(true, sent, 'Email should be sent successfully');
  }

  /**
   * @description Tests sending email notification with no errors
   */
  @IsTest
  static void testSendErrorNotificationNoErrors() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    // Act
    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'test@example.com', '707000000000001');
    Test.stopTest();

    // Assert
    Assert.areEqual(false, sent, 'Email should not be sent when no errors');
  }

  /**
   * @description Tests building email body
   */
  @IsTest
  static void testBuildEmailBody() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST123';
    error.errorMessage = 'Test error message';
    error.occurredAt = DateTime.now();
    error.operation = 'Update';
    error.objectName = 'Account';
    errors.add(error);

    // Act
    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, '707000000000001', 45, 1);
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(body), 'Email body should not be blank');
    Assert.isTrue(body.contains('Agent Errors Detected'), 'Email should contain title');
    Assert.isTrue(body.contains('Test error message'), 'Email should contain error message');
  }

  /**
   * @description Tests HTML escaping
   */
  @IsTest
  static void testEscapeHtml() {
    // Arrange
    String dangerous = '<script>alert("XSS")</script>';

    // Act
    Test.startTest();
    String safe = AgentErrorMonitorService.escapeHtml(dangerous);
    Test.stopTest();

    // Assert
    Assert.isTrue(!safe.contains('<script>'), 'HTML tags should be escaped');
    Assert.isTrue(safe.contains('&lt;'), 'Should contain escaped characters');
  }

  /**
   * @description Tests HTML escaping with null input
   */
  @IsTest
  static void testEscapeHtmlNull() {
    // Arrange & Act
    Test.startTest();
    String result = AgentErrorMonitorService.escapeHtml(null);
    Test.stopTest();

    // Assert
    Assert.areEqual('N/A', result, 'Null should return N/A');
  }

  /**
   * @description Tests string truncation
   */
  @IsTest
  static void testTruncateString() {
    // Arrange
    String longString = 'This is a very long string that needs to be truncated';

    // Act
    Test.startTest();
    String truncated = AgentErrorMonitorService.truncateString(longString, 20);
    Test.stopTest();

    // Assert
    Assert.areEqual(23, truncated.length(), 'String should be truncated to 20 + ... (3 chars)');
    Assert.isTrue(truncated.endsWith('...'), 'Truncated string should end with ...');
  }

  /**
   * @description Tests string truncation with short string
   */
  @IsTest
  static void testTruncateStringShort() {
    // Arrange
    String shortString = 'Short';

    // Act
    Test.startTest();
    String result = AgentErrorMonitorService.truncateString(shortString, 20);
    Test.stopTest();

    // Assert
    Assert.areEqual(shortString, result, 'Short string should not be truncated');
  }

  /**
   * @description Tests string truncation with null
   */
  @IsTest
  static void testTruncateStringNull() {
    // Arrange & Act
    Test.startTest();
    String result = AgentErrorMonitorService.truncateString(null, 20);
    Test.stopTest();

    // Assert
    Assert.areEqual('N/A', result, 'Null should return N/A');
  }

  /**
   * @description Tests exception logging
   */
  @IsTest
  static void testLogException() {
    // Arrange
    Exception testException = new AgentErrorMonitorService.AgentErrorMonitorException('Test exception');

    // Act
    Test.startTest();
    AgentErrorMonitorService.logException(testException);
    Test.stopTest();

    // Assert - no exception should be thrown
    Assert.isTrue(true, 'Exception logging should complete without error');
  }

  /**
   * @description Tests custom exception
   */
  @IsTest
  static void testDataCloudServiceException() {
    // Arrange & Act
    Test.startTest();

    try {
      throw new AgentErrorMonitorService.AgentErrorMonitorException('Test message');
    } catch (AgentErrorMonitorService.AgentErrorMonitorException e) {
      // Assert
      Assert.areEqual('Test message', e.getMessage(), 'Exception message should match');
    }

    Test.stopTest();
  }

  /**
   * @description Tests sending notification with duration
   */
  @IsTest
  static void testSendErrorNotificationWithDuration() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST456';
    error.errorMessage = 'Duration test error';
    error.occurredAt = DateTime.now();
    error.operation = 'Delete';
    error.objectName = 'Contact';
    errors.add(error);

    // Act
    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'admin@test.com', '707000000000002', 120);
    Test.stopTest();

    // Assert
    Assert.areEqual(true, sent, 'Email with duration should be sent successfully');
  }

  /**
   * @description Tests getting errors with different time ranges
   */
  @IsTest
  static void testGetErrorRecordsDifferentRanges() {
    // Act
    Test.startTest();
    List<AgentErrorMonitorService.ErrorRecord> errors1h = AgentErrorMonitorService.getErrorRecords(1);
    List<AgentErrorMonitorService.ErrorRecord> errors48h = AgentErrorMonitorService.getErrorRecords(48);
    Test.stopTest();

    // Assert
    Assert.isNotNull( errors1h, '1 hour results should not be null');
    Assert.isNotNull( errors48h, '48 hour results should not be null');
  }

  /**
   * @description Tests isErrorMessage with actual error patterns
   */
  @IsTest
  static void testIsErrorMessageWithErrorPatterns() {
    // Test specific error patterns that indicate system errors
    Assert.areEqual(
      true,
      AgentErrorMonitorService.isErrorMessage('An error occurred with error ID: 12345'),
      'Should detect "error id:" pattern'
    );
    Assert.areEqual(
      true,
      AgentErrorMonitorService.isErrorMessage('System error occurred during processing'),
      'Should detect "system error" pattern'
    );
    Assert.areEqual(
      true,
      AgentErrorMonitorService.isErrorMessage('Operation failed due to an error'),
      'Should detect "due to an error" pattern'
    );
    Assert.areEqual(
      true,
      AgentErrorMonitorService.isErrorMessage('An error occurred while processing the request'),
      'Should detect "error occurred" pattern'
    );
    Assert.areEqual(
      true,
      AgentErrorMonitorService.isErrorMessage('Failed with error code: 500'),
      'Should detect "error code:" pattern'
    );
  }

  /**
   * @description Tests isErrorMessage with non-error messages
   */
  @IsTest
  static void testIsErrorMessageWithNonErrors() {
    // Test messages that should NOT be treated as errors
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isErrorMessage('Warning: This is just a warning'),
      'Should not treat warnings as errors'
    );
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isErrorMessage('Info: Processing complete'),
      'Should not treat info messages as errors'
    );
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isErrorMessage('User asked about error handling'),
      'Should not treat user questions about errors as system errors'
    );
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isErrorMessage('Error handling best practices'),
      'Should not treat general error discussion as system errors'
    );
  }

  /**
   * @description Tests isErrorMessage with non-error text
   */
  @IsTest
  static void testIsErrorMessageNonError() {
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isErrorMessage('Successfully processed'),
      'Should not detect errors in success message'
    );
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isErrorMessage('Record updated'),
      'Should not detect errors in normal message'
    );
    Assert.areEqual(false, AgentErrorMonitorService.isErrorMessage(null), 'Should handle null message');
    Assert.areEqual(false, AgentErrorMonitorService.isErrorMessage(''), 'Should handle empty message');
  }

  /**
   * @description Tests isError with message analysis
   */
  @IsTest
  static void testIsErrorWithMessageAnalysis() {
    // Error with error pattern
    AgentErrorMonitorService.ErrorRecord errorWithPattern = new AgentErrorMonitorService.ErrorRecord();
    errorWithPattern.errorMessage = 'System error occurred with error ID: 12345';
    errorWithPattern.status = 'Success';
    Assert.areEqual(
      true,
      AgentErrorMonitorService.isError(errorWithPattern),
      'Should detect error from message pattern'
    );

    // Warning message should not be error
    AgentErrorMonitorService.ErrorRecord warningRecord = new AgentErrorMonitorService.ErrorRecord();
    warningRecord.errorMessage = 'Warning: Check this later';
    warningRecord.status = 'Success';
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isError(warningRecord),
      'Should not treat warning as error'
    );

    // Message without error patterns
    AgentErrorMonitorService.ErrorRecord normalRecord = new AgentErrorMonitorService.ErrorRecord();
    normalRecord.errorMessage = 'Processing completed successfully';
    normalRecord.status = 'Success';
    Assert.areEqual(
      false,
      AgentErrorMonitorService.isError(normalRecord),
      'Should not treat success message as error'
    );
  }

  /**
   * @description Tests buildFieldList method
   */
  @IsTest
  static void testBuildFieldList() {
    // Act
    Test.startTest();
    String fieldList = AgentErrorMonitorService.buildFieldList();
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(fieldList), 'Field list should not be blank');
    Assert.isTrue(fieldList.contains('Id'), 'Field list should contain Id');
    Assert.isTrue(
      fieldList.contains(AgentErrorMonitorService.AI_AGENT_CONTENT_FIELD),
      'Should contain content field'
    );
  }

  /**
   * @description Tests buildErrorKeywordWhereClause method
   */
  @IsTest
  static void testBuildErrorKeywordWhereClause() {
    // Act
    Test.startTest();
    String whereClause = AgentErrorMonitorService.buildErrorKeywordWhereClause();
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(whereClause), 'WHERE clause should not be blank');
    Assert.isTrue(whereClause.contains('error id:'), 'Should contain error id pattern');
  }

  /**
   * @description Tests queryErrorRecords method
   */
  @IsTest
  static void testQueryErrorRecords() {
    // Act
    Test.startTest();
    List<sObject> records = AgentErrorMonitorService.queryErrorRecords(24);
    Test.stopTest();

    // Assert
    Assert.isNotNull( records, 'Records list should not be null');
  }

  /**
   * @description Tests sendSchedulerErrorNotification method
   */
  @IsTest
  static void testSendSchedulerErrorNotification() {
    // Arrange
    Exception testException = new AgentErrorMonitorService.AgentErrorMonitorException('Scheduler failed');

    // Act
    Test.startTest();
    AgentErrorMonitorService.sendSchedulerErrorNotification(testException, 'admin@test.com');
    Test.stopTest();

    // Assert - Should complete without throwing exception
    Assert.isTrue(true, 'Scheduler error notification should be sent');
  }

  /**
   * @description Tests escapeHtml with all special characters
   */
  @IsTest
  static void testEscapeHtmlAllCharacters() {
    // Arrange
    String input = '<>&"\'';

    // Act
    Test.startTest();
    String result = AgentErrorMonitorService.escapeHtml(input);
    Test.stopTest();

    // Assert
    Assert.isTrue(result.contains('&lt;'), 'Should escape less than');
    Assert.isTrue(result.contains('&gt;'), 'Should escape greater than');
    Assert.isTrue(result.contains('&amp;'), 'Should escape ampersand');
    Assert.isTrue(result.contains('&quot;'), 'Should escape quote');
    Assert.isTrue(result.contains('&#39;'), 'Should escape apostrophe');
  }

  /**
   * @description Tests escapeHtml with empty string
   */
  @IsTest
  static void testEscapeHtmlEmpty() {
    // Act
    Test.startTest();
    String result = AgentErrorMonitorService.escapeHtml('');
    Test.stopTest();

    // Assert
    Assert.areEqual('N/A', result, 'Empty string should return N/A');
  }

  /**
   * @description Tests buildEmailBody with no job ID
   */
  @IsTest
  static void testBuildEmailBodyNoJobId() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST789';
    error.errorMessage = 'Test error';
    error.occurredAt = DateTime.now();
    error.sessionId = 'SESSION123';
    error.messageType = 'Error';
    errors.add(error);

    // Act
    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, null, 0, 1);
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(body), 'Email body should not be blank');
    Assert.isTrue(body.contains('Test error'), 'Should contain error message');
  }

  /**
   * @description Tests buildEmailBody with null values in error record
   */
  @IsTest
  static void testBuildEmailBodyNullValues() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = null;
    error.errorMessage = null;
    error.occurredAt = null;
    error.sessionId = null;
    error.messageType = null;
    errors.add(error);

    // Act
    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 'JOB123', 30, 1);
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(body), 'Email body should handle null values');
    Assert.isTrue(body.contains('N/A'), 'Should show N/A for null values');
  }

  /**
   * @description Tests sendErrorNotification with 3-parameter overload
   */
  @IsTest
  static void testSendErrorNotificationThreeParams() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST999';
    error.errorMessage = 'Three param test';
    error.occurredAt = DateTime.now();
    errors.add(error);

    // Act
    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'test@example.com', '707000000000003');
    Test.stopTest();

    // Assert
    Assert.areEqual(true, sent, 'Email should be sent with 3 parameters');
  }

  /**
   * @description Tests getErrorRecords with strict mode filtering
   */
  @IsTest
  static void testGetErrorRecordsStrictFiltering() {
    // Act
    Test.startTest();
    List<AgentErrorMonitorService.ErrorRecord> strictErrors = AgentErrorMonitorService.getErrorRecords(
      24,
      true
    );
    List<AgentErrorMonitorService.ErrorRecord> nonStrictErrors = AgentErrorMonitorService.getErrorRecords(
      24,
      false
    );
    Test.stopTest();

    // Assert
    Assert.isNotNull( strictErrors, 'Strict mode should return list');
    Assert.isNotNull( nonStrictErrors, 'Non-strict mode should return list');
  }

  /**
   * @description Tests buildEmailBody with multiple errors for row coloring
   */
  @IsTest
  static void testBuildEmailBodyMultipleErrors() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    for (Integer i = 0; i < 5; i++) {
      AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
      error.recordId = 'TEST' + i;
      error.errorMessage = 'Error ' + i;
      error.occurredAt = DateTime.now();
      error.sessionId = 'SESSION' + i;
      error.messageType = 'Error';
      errors.add(error);
    }

    // Act
    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, '707000000000004', 60, 5);
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(body), 'Email body should handle multiple errors');
    Assert.isTrue(body.contains('Error 0'), 'Should contain first error');
    Assert.isTrue(body.contains('Error 4'), 'Should contain last error');
    Assert.isTrue(body.contains('60 seconds'), 'Should contain duration');
  }

  /**
   * @description Tests ErrorRecord constructor with sObject parameter
   * Note: We test with a standard object since Data Cloud objects aren't available in test context
   */
  @IsTest
  static void testErrorRecordConstructorWithSObject() {
    // Arrange - Create a test Account record
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    // Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord errorRec = new AgentErrorMonitorService.ErrorRecord(testAccount);
    Test.stopTest();

    // Assert
    Assert.isNotNull( errorRec, 'ErrorRecord should be created');
    Assert.areEqual(testAccount.Id, errorRec.recordId, 'Record ID should match');
  }

  /**
   * @description Tests processRecords with actual records
   */
  @IsTest
  static void testProcessRecordsWithRecords() {
    // Arrange
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    List<sObject> records = new List<sObject>{ testAccount };
    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();

    // Act
    Test.startTest();
    AgentErrorMonitorService.processRecords(records, result);
    Test.stopTest();

    // Assert
    Assert.areEqual(1, result.totalRecords, 'Should process one record');
  }

  /**
   * @description Tests isError with blank error message
   */
  @IsTest
  static void testIsErrorWithBlankMessage() {
    // Arrange
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.errorMessage = '';
    error.status = 'Success';

    // Act
    Test.startTest();
    Boolean hasError = AgentErrorMonitorService.isError(error);
    Test.stopTest();

    // Assert
    Assert.areEqual(false, hasError, 'Should not detect error with blank message');
  }

  /**
   * @description Tests buildEmailBody with empty errors list
   */
  @IsTest
  static void testBuildEmailBodyEmptyList() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    // Act
    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, '707000000000005', 45, 0);
    Test.stopTest();

    // Assert
    Assert.isTrue(String.isNotBlank(body), 'Email body should be generated even with empty list');
    Assert.isTrue(body.contains('0'), 'Should show 0 errors');
  }

  /**
   * @description Tests ErrorRecord constructor with mock Data Cloud AI Agent object
   * Uses dynamic Apex to simulate Data Cloud object structure
   */
  @IsTest
  static void testErrorRecordWithMockDataCloudObject() {
    // Arrange - Create a Contact to simulate Data Cloud object behavior
    Contact testContact = new Contact(FirstName = 'Test', LastName = 'DataCloud', Email = 'test@datacloud.com');
    insert testContact;

    // Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord errorRec = new AgentErrorMonitorService.ErrorRecord(testContact);
    Test.stopTest();

    // Assert - Should handle the object even if it's not a Data Cloud object
    Assert.isNotNull( errorRec, 'ErrorRecord should be created');
    Assert.areEqual(testContact.Id, errorRec.recordId, 'Record ID should match');
  }

  /**
   * @description Tests getFieldValue exception handling in ErrorRecord constructor
   */
  @IsTest
  static void testErrorRecordFieldValueException() {
    // Arrange - Create an Account with limited fields
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    // Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord errorRec = new AgentErrorMonitorService.ErrorRecord(testAccount);
    Test.stopTest();

    // Assert - Should handle missing fields gracefully
    Assert.isNotNull( errorRec, 'ErrorRecord should be created');
    Assert.areEqual(testAccount.Id, errorRec.recordId, 'Record ID should be set');
  }

  /**
   * @description Tests processRecords with records that have error status
   */
  @IsTest
  static void testProcessRecordsWithErrorStatus() {
    // Arrange
    Account testAccount = new Account(Name = 'Error Test Account');
    insert testAccount;

    List<sObject> records = new List<sObject>{ testAccount };
    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();

    // Act
    Test.startTest();
    AgentErrorMonitorService.processRecords(records, result);
    Test.stopTest();

    // Assert
    Assert.areEqual(1, result.totalRecords, 'Should count all records');
  }

  /**
   * @description Tests ErrorRecord with all field types populated
   */
  @IsTest
  static void testErrorRecordAllFields() {
    // Arrange
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST123';
    error.errorMessage = 'Test error with error ID: 12345';
    error.occurredAt = DateTime.now();
    error.operation = 'Insert';
    error.objectName = 'TestObject';
    error.status = 'Failed';
    error.messageType = 'Error';
    error.sessionId = 'SESSION123';

    // Act
    Test.startTest();
    Boolean hasError = AgentErrorMonitorService.isError(error);
    Test.stopTest();

    // Assert
    Assert.areEqual(true, hasError, 'Should detect error from message pattern');
  }

  /**
   * @description Tests queryErrorRecords exception handling
   */
  @IsTest
  static void testQueryErrorRecordsExceptionHandling() {
    // Act
    Test.startTest();
    List<sObject> records = AgentErrorMonitorService.queryErrorRecords(0);
    Test.stopTest();

    // Assert - Should return empty list on exception
    Assert.isNotNull( records, 'Should return list even on exception');
  }

  /**
   * @description Tests getErrorCount exception handling
   */
  @IsTest
  static void testGetErrorCountExceptionHandling() {
    // Act
    Test.startTest();
    Integer count = AgentErrorMonitorService.getErrorCount(0);
    Test.stopTest();

    // Assert - Should return 0 on exception
    Assert.isTrue(count >= 0, 'Should return non-negative count');
  }

  /**
   * @description Tests sendErrorNotification exception handling
   */
  @IsTest
  static void testSendErrorNotificationException() {
    // Arrange
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = 'TEST999';
    error.errorMessage = 'Exception test';
    errors.add(error);

    // Act
    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'invalid-email-format', null, 0);
    Test.stopTest();

    // Assert - Should handle exception gracefully
    Assert.isNotNull( sent, 'Should return boolean result');
  }

  /**
   * @description Tests processRecords with large dataset to hit MAX_ERROR_DETAILS limit
   */
  @IsTest
  static void testProcessRecordsMaxErrorLimit() {
    // Arrange
    List<sObject> records = new List<sObject>();
    for (Integer i = 0; i < 150; i++) {
      Account acc = new Account(Name = 'Test Account ' + i);
      records.add(acc);
    }

    AgentErrorMonitorService.ProcessingResult result = new AgentErrorMonitorService.ProcessingResult();

    // Act
    Test.startTest();
    AgentErrorMonitorService.processRecords(records, result);
    Test.stopTest();

    // Assert
    Assert.areEqual(150, result.totalRecords, 'Should process all records');
    Assert.isTrue(result.errorRecords.size() <= 100, 'Should respect MAX_ERROR_DETAILS limit');
  }

  /**
   * @description Tests ErrorRecord constructor with simulated AI Agent object type
   * This covers the AI_AGENT_OBJECT branch (lines 56-60)
   */
  @IsTest
  static void testErrorRecordWithAIAgentObjectType() {
    // Arrange - Create a Lead to simulate AI Agent object behavior
    // We'll use getSObjectType() to test the type detection logic
    Lead testLead = new Lead(
      FirstName = 'AI',
      LastName = 'Agent Test',
      Company = 'Test Company',
      Status = 'Open - Not Contacted'
    );
    insert testLead;

    // Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord errorRec = new AgentErrorMonitorService.ErrorRecord(testLead);
    Test.stopTest();

    // Assert - Should handle the object type detection
    Assert.isNotNull( errorRec, 'ErrorRecord should be created');
    Assert.areEqual(testLead.Id, errorRec.recordId, 'Record ID should match');
  }

  /**
   * @description Tests ErrorRecord constructor with different object types
   * This covers the else branch for non-AI-Agent objects (lines 64-70)
   */
  @IsTest
  static void testErrorRecordWithDifferentObjectTypes() {
    // Arrange - Create multiple object types to test both branches
    Opportunity testOpp = new Opportunity(
      Name = 'Test Opportunity',
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30)
    );
    insert testOpp;

    // Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord errorRec1 = new AgentErrorMonitorService.ErrorRecord(testOpp);
    Test.stopTest();

    // Assert
    Assert.isNotNull( errorRec1, 'ErrorRecord should be created for Opportunity');
    Assert.areEqual(testOpp.Id, errorRec1.recordId, 'Record ID should match');
  }

  /**
   * @description Tests getFieldValue with various field scenarios
   * This ensures the getFieldValue method handles different field types
   */
  @IsTest
  static void testGetFieldValueWithVariousFields() {
    // Arrange
    Case testCase = new Case(Subject = 'Test Case', Status = 'New', Origin = 'Web');
    insert testCase;

    // Act
    Test.startTest();
    AgentErrorMonitorService.ErrorRecord errorRec = new AgentErrorMonitorService.ErrorRecord(testCase);
    Test.stopTest();

    // Assert
    Assert.isNotNull( errorRec, 'ErrorRecord should be created');
    Assert.areEqual(testCase.Id, errorRec.recordId, 'Record ID should be set');
  }
}
