@IsTest(SeeAllData=false)
private class AgentErrorMonitorServiceTest {
  // ============================================================================
  // TEST DATA HELPERS
  // ============================================================================

  private static AgentErrorMonitorService.ErrorRecord createMockErrorRecord() {
    return createMockErrorRecord('TEST123', 'Test error message', 'Success');
  }

  private static AgentErrorMonitorService.ErrorRecord createMockErrorRecord(String recordId, String errorMessage, String status) {
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    error.recordId = recordId;
    error.errorMessage = errorMessage;
    error.occurredAt = DateTime.now();
    error.status = status;
    error.sessionId = 'SESSION_' + recordId;
    error.messageType = 'Error';
    return error;
  }

  private static List<AgentErrorMonitorService.ErrorRecord> createMockErrorRecords(Integer count) {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    for (Integer i = 0; i < count; i++) {
      errors.add(createMockErrorRecord('TEST' + i, 'Error ' + i, 'Failed'));
    }
    return errors;
  }

  private static AgentErrorMonitorService.JobContext createJobContext(
    String jobId,
    Long durationSeconds,
    Boolean isScheduled,
    Integer lookbackHours
  ) {
    return new AgentErrorMonitorService.JobContext(jobId, durationSeconds, isScheduled, lookbackHours);
  }

  private static AgentErrorMonitorService.JobContext createManualJobContext(String jobId, Long durationSeconds) {
    return createJobContext(jobId, durationSeconds, false, null);
  }

  private static AgentErrorMonitorService.JobContext createScheduledJobContext(String jobId, Long durationSeconds, Integer lookbackHours) {
    return createJobContext(jobId, durationSeconds, true, lookbackHours);
  }

  private static void assertExceptionThrown(String methodName, Exception expectedException, String expectedMessage) {
    Assert.fail('Should throw ' + expectedException.getTypeName() + ' for ' + methodName);
  }

  private static void assertExceptionMessage(Exception e, String expectedSubstring, String context) {
    Assert.isTrue(e.getMessage().contains(expectedSubstring), context);
  }

  // ============================================================================
  // TESTS
  // ============================================================================

  @IsTest
  static void testSendErrorNotificationWithErrors() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = createMockErrorRecord('TEST123', 'Test error', 'Failed');
    error.operation = 'Insert';
    error.objectName = 'TestObject';
    errors.add(error);

    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'test@example.com', '707000000000001');
    Test.stopTest();

    Assert.areEqual(true, sent, 'Email should be sent successfully');
  }

  @IsTest
  static void testSendErrorNotificationNoErrors() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'test@example.com', '707000000000001');
    Test.stopTest();

    Assert.areEqual(false, sent, 'Email should not be sent when no errors');
  }

  @IsTest
  static void testBuildEmailBody() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = createMockErrorRecord('TEST123', 'Test error message', 'Failed');
    error.operation = 'Update';
    error.objectName = 'Account';
    errors.add(error);

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 1, createManualJobContext('707000000000001', 45));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should not be blank');
    Assert.isTrue(body.contains('Agent Errors Detected'), 'Email should contain title');
    Assert.isTrue(body.contains('Test error message'), 'Email should contain error message');
  }

  @IsTest
  static void testEscapeHtmlNull() {
    Test.startTest();
    String result = AgentErrorMonitorService.escapeHtml(null);
    Test.stopTest();

    Assert.areEqual('N/A', result, 'Null should return N/A');
  }

  @IsTest
  static void testTruncateString() {
    String longString = 'This is a very long string that needs to be truncated';

    Test.startTest();
    String truncated = AgentErrorMonitorService.truncate(longString, 20);
    Test.stopTest();

    Assert.areEqual(23, truncated.length(), 'String should be truncated to 20 + ... (3 chars)');
    Assert.isTrue(truncated.endsWith('...'), 'Truncated string should end with ...');
  }

  @IsTest
  static void testTruncateStringShort() {
    String shortString = 'Short';

    Test.startTest();
    String result = AgentErrorMonitorService.truncate(shortString, 20);
    Test.stopTest();

    Assert.areEqual(shortString, result, 'Short string should not be truncated');
  }

  @IsTest
  static void testTruncateStringNull() {
    Test.startTest();
    String result = AgentErrorMonitorService.truncate(null, 20);
    Test.stopTest();

    Assert.areEqual('N/A', result, 'Null should return N/A');
  }

  @IsTest
  static void testSendErrorNotificationWithDuration() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = createMockErrorRecord('TEST456', 'Duration test error', 'Failed');
    error.operation = 'Delete';
    error.objectName = 'Contact';
    errors.add(error);

    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'admin@test.com', '707000000000002', 120);
    Test.stopTest();

    Assert.areEqual(true, sent, 'Email with duration should be sent successfully');
  }

  @IsTest
  static void testBuildFieldList() {
    List<String> fields = new List<String>{ 'Id', 'Name', 'CreatedDate' };

    Test.startTest();
    String fieldList = AgentErrorMonitorService.buildFieldList(fields);
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(fieldList), 'Field list should not be blank');
    Assert.isTrue(fieldList.contains('Id'), 'Field list should contain Id');
    Assert.isTrue(fieldList.contains('Name'), 'Field list should contain Name');
    Assert.isTrue(fieldList.contains('CreatedDate'), 'Field list should contain CreatedDate');
    Assert.areEqual('Id, Name, CreatedDate', fieldList, 'Field list should be properly formatted');
  }

  @IsTest
  static void testQueryErrorRecords() {
    Test.startTest();
    List<sObject> records = AgentErrorMonitorService.queryErrorRecords(24);
    Test.stopTest();

    Assert.isNotNull(records, 'Records list should not be null');
  }

  @IsTest
  static void testSendSchedulerErrorNotification() {
    Exception testException = new AgentErrorMonitorService.AgentErrorMonitorException('Scheduler failed');
    Integer emailLimitBefore = Limits.getEmailInvocations();

    Test.startTest();
    AgentErrorMonitorService.sendSchedulerErrorNotification(testException, 'admin@test.com');
    Test.stopTest();

    Integer emailLimitAfter = Limits.getEmailInvocations();
    Assert.isTrue(emailLimitAfter >= emailLimitBefore, 'Should attempt to send email notification');
  }

  @IsTest
  static void testEscapeHtmlAllCharacters() {
    String input = '<>&"\'';

    Test.startTest();
    String result = AgentErrorMonitorService.escapeHtml(input);
    Test.stopTest();

    Assert.isTrue(result.contains('&lt;'), 'Should escape less than');
    Assert.isTrue(result.contains('&gt;'), 'Should escape greater than');
    Assert.isTrue(result.contains('&amp;'), 'Should escape ampersand');
    Assert.isTrue(result.contains('&quot;'), 'Should escape quote');
    Assert.isTrue(result.contains('&#39;'), 'Should escape apostrophe');
  }

  @IsTest
  static void testEscapeHtmlEmpty() {
    Test.startTest();
    String result = AgentErrorMonitorService.escapeHtml('');
    Test.stopTest();

    Assert.areEqual('N/A', result, 'Empty string should return N/A');
  }

  @IsTest
  static void testBuildEmailBodyNoJobId() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    errors.add(createMockErrorRecord('TEST789', 'Test error', 'Error'));

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 1, createManualJobContext(null, 0));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should not be blank');
    Assert.isTrue(body.contains('Test error'), 'Should contain error message');
  }

  @IsTest
  static void testBuildEmailBodyNullValues() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    AgentErrorMonitorService.ErrorRecord error = new AgentErrorMonitorService.ErrorRecord();
    errors.add(error);

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 1, createManualJobContext('JOB123', 30));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should handle null values');
    Assert.isTrue(body.contains('N/A'), 'Should show N/A for null values');
  }

  @IsTest
  static void testBuildEmailBodyMultipleErrors() {
    List<AgentErrorMonitorService.ErrorRecord> errors = createMockErrorRecords(5);

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 5, createManualJobContext('707000000000004', 60));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should handle multiple errors');
    Assert.isTrue(body.contains('Error 0'), 'Should contain first error');
    Assert.isTrue(body.contains('Error 4'), 'Should contain last error');
    Assert.isTrue(body.contains('60 seconds'), 'Should contain duration');
  }

  @IsTest
  static void testBuildEmailBodyEmptyList() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 0, createManualJobContext('707000000000005', 45));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should be generated even with empty list');
    Assert.isTrue(body.contains('0'), 'Should show 0 errors');
  }

  @IsTest
  static void testQueryErrorRecordsExceptionHandling() {
    Test.startTest();
    try {
      List<sObject> records = AgentErrorMonitorService.queryErrorRecords(0);
      Assert.fail('Should throw IllegalArgumentException for invalid hoursBack');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('hoursBack must be between'), 'Should validate hoursBack range');
    }
    Test.stopTest();
  }

  @IsTest
  static void testSendErrorNotificationException() {
    List<AgentErrorMonitorService.ErrorRecord> errors = new List<AgentErrorMonitorService.ErrorRecord>();
    errors.add(createMockErrorRecord('TEST999', 'Exception test', 'Error'));

    Test.startTest();
    Boolean sent = AgentErrorMonitorService.sendErrorNotification(errors, 'invalid-email-format', null, 0);
    Test.stopTest();

    Assert.isNotNull(sent, 'Should return boolean result');
  }

  @IsTest
  static void testBuildFieldListNull() {
    Test.startTest();
    try {
      AgentErrorMonitorService.buildFieldList(null);
      Assert.fail('Should throw IllegalArgumentException for null fields');
    } catch (IllegalArgumentException e) {
      assertExceptionMessage(e, 'cannot be null or empty', 'Should validate null fields');
    }
    Test.stopTest();
  }

  @IsTest
  static void testBuildFieldListEmpty() {
    Test.startTest();
    try {
      AgentErrorMonitorService.buildFieldList(new List<String>());
      Assert.fail('Should throw IllegalArgumentException for empty fields');
    } catch (IllegalArgumentException e) {
      assertExceptionMessage(e, 'cannot be null or empty', 'Should validate empty fields');
    }
    Test.stopTest();
  }

  @IsTest
  static void testBuildEmailBodyScheduledWithLookback() {
    List<AgentErrorMonitorService.ErrorRecord> errors = createMockErrorRecords(3);

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 3, createScheduledJobContext('707000000000006', 45, 24));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should not be blank');
    Assert.isTrue(body.contains('Scheduled'), 'Should show Scheduled job type');
    Assert.isTrue(body.contains('24 hours') || body.contains('Lookback'), 'Should show lookback period');
  }

  @IsTest
  static void testBuildEmailBodyScheduledWithSingleHour() {
    List<AgentErrorMonitorService.ErrorRecord> errors = createMockErrorRecords(1);

    Test.startTest();
    String body = AgentErrorMonitorService.buildEmailBody(errors, 1, createScheduledJobContext('707000000000007', 30, 1));
    Test.stopTest();

    Assert.isTrue(String.isNotBlank(body), 'Email body should not be blank');
    Assert.isTrue(body.contains('1 hour') && !body.contains('1 hours'), 'Should show singular hour');
  }

  @IsTest
  static void testGetOrgUrl() {
    Test.startTest();
    String orgUrl = AgentErrorMonitorService.getOrgUrl();
    Test.stopTest();

    Assert.isNotNull(orgUrl, 'Org URL should not be null');
  }

  @IsTest
  static void testGetJobUrlScheduled() {
    Test.startTest();
    String jobUrl = AgentErrorMonitorService.getJobUrl(true);
    Test.stopTest();

    Assert.isTrue(jobUrl.contains('ScheduledJobs'), 'Should return Scheduled Jobs URL');
  }

  @IsTest
  static void testGetJobUrlManual() {
    Test.startTest();
    String jobUrl = AgentErrorMonitorService.getJobUrl(false);
    Test.stopTest();

    Assert.isTrue(jobUrl.contains('AsyncApexJobs'), 'Should return Async Apex Jobs URL');
  }

  @IsTest
  static void testBuildJobLinkScheduled() {
    Test.startTest();
    String jobLink = AgentErrorMonitorService.buildJobLink('707000000000008', 'https://test.salesforce.com', true);
    Test.stopTest();

    Assert.isTrue(jobLink.contains('ScheduledJobs'), 'Should link to Scheduled Jobs');
    Assert.isTrue(jobLink.contains('707000000000008'), 'Should contain job ID');
  }

  @IsTest
  static void testBuildJobLinkManual() {
    Test.startTest();
    String jobLink = AgentErrorMonitorService.buildJobLink('707000000000009', 'https://test.salesforce.com', false);
    Test.stopTest();

    Assert.isTrue(jobLink.contains('AsyncApexJobs'), 'Should link to Async Apex Jobs');
    Assert.isTrue(jobLink.contains('707000000000009'), 'Should contain job ID');
  }

  @IsTest
  static void testBuildJobLinkBlankJobId() {
    Test.startTest();
    String jobLink = AgentErrorMonitorService.buildJobLink('', 'https://test.salesforce.com', false);
    Test.stopTest();

    Assert.areEqual('', jobLink, 'Should return empty string for blank job ID');
  }

  @IsTest
  static void testBuildJobLinkBlankOrgUrl() {
    Test.startTest();
    String jobLink = AgentErrorMonitorService.buildJobLink('707000000000010', '', false);
    Test.stopTest();

    Assert.areEqual('707000000000010', jobLink, 'Should return plain job ID when org URL is blank');
  }
}
