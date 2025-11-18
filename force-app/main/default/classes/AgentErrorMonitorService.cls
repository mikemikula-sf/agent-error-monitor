/**
 * @description Service class for AI Agent error monitoring and detection.
 *              This class abstracts the business logic from the batch job, making it
 *              reusable and testable with anonymous Apex.
 *
 * Usage Examples:
 *
 * // Get error records from last 24 hours
 * List<AgentErrorMonitorService.ErrorRecord> errors =
 *   AgentErrorMonitorService.getErrorRecords(24);
 *
 * // Send email notification
 * AgentErrorMonitorService.sendErrorNotification(
 *   errors,
 *   'admin@example.com',
 *   '707xx0000000001'
 * );
 *
 * // Get error count only
 * Integer errorCount = AgentErrorMonitorService.getErrorCount(24);
 */
public with sharing class AgentErrorMonitorService {
  private static final String ERROR_STATUS = 'Failed';
  private static final Integer MAX_ERROR_DETAILS = 100;
  private static final Integer MAX_QUERY_RECORDS = 10000;

  // AI Agent Interaction Message fields
  public static final String AI_AGENT_OBJECT = 'ssot__AiAgentInteractionMessage__dlm';
  public static final String AI_AGENT_CONTENT_FIELD = 'ssot__ContentText__c';
  public static final String AI_AGENT_TYPE_FIELD = 'ssot__AiAgentInteractionMessageType__c';
  public static final String AI_AGENT_TIMESTAMP_FIELD = 'ssot__MessageSentTimestamp__c';
  public static final String AI_AGENT_SESSION_FIELD = 'ssot__AiAgentSessionId__c';

  // Data Cloud Ingestion Log fields (fallback)
  private static final String INGESTION_OBJECT = 'DataCloudIngestionApiEventLog__c';
  private static final String INGESTION_STATUS_FIELD = 'Status';
  private static final String INGESTION_ERROR_FIELD = 'ErrorMessage';
  private static final String INGESTION_TIMESTAMP_FIELD = 'CreatedDate';

  public class ErrorRecord {
    public String recordId { get; set; }
    public String errorMessage { get; set; }
    public DateTime occurredAt { get; set; }
    public String operation { get; set; }
    public String objectName { get; set; }
    public String status { get; set; }
    public String messageType { get; set; }
    public String sessionId { get; set; }

    public ErrorRecord() {
    }

    public ErrorRecord(sObject record) {
      this.recordId = (String) record.get('Id');

      if (record.getSObjectType().getDescribe().getName() == AI_AGENT_OBJECT) {
        this.errorMessage = getFieldValue(record, AI_AGENT_CONTENT_FIELD);
        this.occurredAt = (DateTime) record.get(AI_AGENT_TIMESTAMP_FIELD);
        this.messageType = getFieldValue(record, AI_AGENT_TYPE_FIELD);
        this.sessionId = getFieldValue(record, AI_AGENT_SESSION_FIELD);
        this.operation = null;
        this.objectName = null;
        this.status = null;
      } else {
        this.errorMessage = getFieldValue(record, INGESTION_ERROR_FIELD);
        this.occurredAt = (DateTime) record.get(INGESTION_TIMESTAMP_FIELD);
        this.operation = getFieldValue(record, 'Operation');
        this.objectName = getFieldValue(record, 'ObjectName');
        this.status = getFieldValue(record, INGESTION_STATUS_FIELD);
        this.messageType = null;
        this.sessionId = null;
      }
    }

    private String getFieldValue(sObject record, String fieldName) {
      try {
        Object value = record.get(fieldName);
        return value != null ? String.valueOf(value) : null;
      } catch (Exception e) {
        return null;
      }
    }
  }

  public class ProcessingResult {
    public Integer totalRecords { get; set; }
    public Integer errorCount { get; set; }
    public List<ErrorRecord> errorRecords { get; set; }
    public Long durationMilliseconds { get; set; }

    public ProcessingResult() {
      this.totalRecords = 0;
      this.errorCount = 0;
      this.errorRecords = new List<ErrorRecord>();
      this.durationMilliseconds = 0;
    }
  }

  /**
   * @description Builds the SELECT field list for AI Agent queries
   * @return String Comma-separated field list for SELECT clause
   */
  public static String buildFieldList() {
    return 'Id, ' +
      AI_AGENT_CONTENT_FIELD +
      ', ' +
      AI_AGENT_TYPE_FIELD +
      ', ' +
      AI_AGENT_TIMESTAMP_FIELD +
      ', ' +
      AI_AGENT_SESSION_FIELD;
  }

  /**
   * @description Queries AI Agent interaction messages for errors within specified hours
   * @param hoursBack Number of hours to look back
   * @return List of sObject records matching error criteria
   */
  public static List<sObject> queryErrorRecords(Integer hoursBack) {
    DateTime cutoffTime = DateTime.now().addHours(-hoursBack);

    String query =
      'SELECT ' +
      buildFieldList() +
      ' ' +
      'FROM ' +
      AI_AGENT_OBJECT +
      ' ' +
      'WHERE ' +
      AI_AGENT_TIMESTAMP_FIELD +
      ' >= :cutoffTime ' +
      'AND ' +
      buildErrorKeywordWhereClause() +
      ' ' +
      'ORDER BY ' +
      AI_AGENT_TIMESTAMP_FIELD +
      ' DESC ' +
      'LIMIT ' +
      MAX_QUERY_RECORDS;

    try {
      return Database.query(query);
    } catch (Exception e) {
      logException(e);
      return new List<sObject>();
    }
  }

  /**
   * @description Queries AI Agent interaction messages for errors within specified hours
   * @param hoursBack Number of hours to look back (default 24)
   * @return List of ErrorRecord objects
   */
  public static List<ErrorRecord> getErrorRecords(Integer hoursBack) {
    return getErrorRecords(hoursBack, true);
  }

  /**
   * @description Queries AI Agent interaction messages for errors within specified hours
   * @param hoursBack Number of hours to look back
   * @param strictMode If true, only returns records with validated error messages
   * @return List of ErrorRecord objects
   */
  public static List<ErrorRecord> getErrorRecords(Integer hoursBack, Boolean strictMode) {
    List<sObject> records = queryErrorRecords(hoursBack);
    List<ErrorRecord> errorRecords = new List<ErrorRecord>();

    for (sObject record : records) {
      ErrorRecord errorRec = new ErrorRecord(record);

      if (strictMode && !isError(errorRec)) {
        continue;
      }

      if (!strictMode && (errorRec.status == ERROR_STATUS || String.isNotBlank(errorRec.errorMessage))) {
        errorRecords.add(errorRec);
      } else if (strictMode && isError(errorRec)) {
        errorRecords.add(errorRec);
      }
    }

    return errorRecords;
  }

  /**
   * @description Builds WHERE clause focusing on "error ID:" pattern to reduce false positives
   * @return String WHERE clause for error keywords
   */
  public static String buildErrorKeywordWhereClause() {
    return '(' +
      AI_AGENT_CONTENT_FIELD +
      ' LIKE \'%error id:%\' OR ' +
      AI_AGENT_CONTENT_FIELD +
      ' LIKE \'%error ID:%\' OR ' +
      AI_AGENT_CONTENT_FIELD +
      ' LIKE \'%Error ID:%\' OR ' +
      AI_AGENT_CONTENT_FIELD +
      ' LIKE \'%ERROR ID:%\' ' +
      ')';
  }

  /**
   * @description Gets error count without retrieving full records
   * @param hoursBack Number of hours to look back
   * @return Integer count of error records
   */
  public static Integer getErrorCount(Integer hoursBack) {
    DateTime cutoffTime = DateTime.now().addHours(-hoursBack);

    try {
      // Query AI Agent Interaction Messages
      String query =
        'SELECT COUNT() ' +
        'FROM ' +
        AI_AGENT_OBJECT +
        ' ' +
        'WHERE ' +
        AI_AGENT_TIMESTAMP_FIELD +
        ' >= :cutoffTime ' +
        'AND ' +
        buildErrorKeywordWhereClause();

      return Database.countQuery(query);
    } catch (Exception e) {
      logException(e);
      return 0;
    }
  }

  /**
   * @description Processes a batch of records and identifies errors
   * @param records List of sObjects to process
   * @param result ProcessingResult object to update
   */
  public static void processRecords(List<sObject> records, ProcessingResult result) {
    for (sObject record : records) {
      result.totalRecords++;

      ErrorRecord errorRec = new ErrorRecord(record);

      if (isError(errorRec)) {
        result.errorCount++;

        // Limit stored errors to prevent memory issues
        if (result.errorRecords.size() < MAX_ERROR_DETAILS) {
          result.errorRecords.add(errorRec);
        }
      }
    }
  }

  /**
   * @description Determines if a record represents an error
   * @param errorRec ErrorRecord to check
   * @return Boolean indicating if record has an error
   */
  public static Boolean isError(ErrorRecord errorRec) {
    if (errorRec.status == ERROR_STATUS) {
      return true;
    }

    if (String.isNotBlank(errorRec.errorMessage)) {
      return isErrorMessage(errorRec.errorMessage);
    }

    return false;
  }

  /**
   * @description Checks if message contains system error patterns (not user questions about errors)
   * @param message The message text to analyze
   * @return Boolean indicating if message contains error indicators
   */
  public static Boolean isErrorMessage(String message) {
    if (String.isBlank(message)) {
      return false;
    }

    String lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('error id:')) {
      return true;
    }

    if (
      lowerMessage.contains('system error') ||
      lowerMessage.contains('due to an error') ||
      lowerMessage.contains('error occurred') ||
      lowerMessage.contains('error code:')
    ) {
      return true;
    }

    return false;
  }

  /**
   * @description Sends email notification with error details
   * @param errors List of ErrorRecord objects
   * @param recipientEmail Email address to send to
   * @param jobId Optional job ID for reference
   * @return Boolean indicating if email was sent successfully
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, String jobId) {
    return sendErrorNotification(errors, recipientEmail, jobId, 0);
  }

  /**
   * @description Sends email notification with error details and duration
   * @param errors List of ErrorRecord objects
   * @param recipientEmail Email address to send to
   * @param jobId Optional job ID for reference
   * @param durationSeconds Execution duration in seconds
   * @return Boolean indicating if email was sent successfully
   */
  public static Boolean sendErrorNotification(
    List<ErrorRecord> errors,
    String recipientEmail,
    String jobId,
    Long durationSeconds
  ) {
    if (errors.isEmpty()) {
      return false;
    }

    try {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ recipientEmail });
      email.setSubject('Agent Errors Detected - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss'));

      String emailBody = buildEmailBody(errors, jobId, durationSeconds, errors.size());
      email.setHtmlBody(emailBody);

      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
      return true;
    } catch (Exception e) {
      logException(e);
      return false;
    }
  }

  /**
   * @description Builds HTML email body with error details
   * @param errors List of ErrorRecord objects
   * @param jobId Optional job ID
   * @param durationSeconds Execution duration
   * @param totalErrorCount Total error count (may be more than errors list size)
   * @return String HTML formatted email body
   */
  public static String buildEmailBody(
    List<ErrorRecord> errors,
    String jobId,
    Long durationSeconds,
    Integer totalErrorCount
  ) {
    String orgUrl = '';
    try {
      orgUrl = URL.getOrgDomainUrl().toExternalForm();
    } catch (Exception e) {
      orgUrl = '';
    }

    String body = '<html><body style="font-family: Arial, sans-serif;">';
    body += '<h2 style="color: #d32f2f;">⚠️ Agent Errors Detected</h2>';
    body += '<div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px;">';
    body += '<h3 style="margin-top: 0;">Summary</h3>';
    body += '<table style="border-collapse: collapse;">';
    body +=
      '<tr><td style="padding: 5px; font-weight: bold;">Total Errors Found:</td><td style="padding: 5px; color: #d32f2f;">' +
      totalErrorCount +
      '</td></tr>';

    if (durationSeconds > 0) {
      body +=
        '<tr><td style="padding: 5px; font-weight: bold;">Execution Time:</td><td style="padding: 5px;">' +
        durationSeconds +
        ' seconds</td></tr>';
    }

    if (String.isNotBlank(jobId)) {
      body +=
        '<tr><td style="padding: 5px; font-weight: bold;">Job ID:</td><td style="padding: 5px;">' +
        jobId +
        '</td></tr>';
    }

    body +=
      '<tr><td style="padding: 5px; font-weight: bold;">Timestamp:</td><td style="padding: 5px;">' +
      DateTime.now().format('yyyy-MM-dd HH:mm:ss z') +
      '</td></tr>';
    body += '</table>';
    body += '</div>';

    if (!errors.isEmpty()) {
      body += '<h3>Error Details (showing ' + errors.size() + ' of ' + totalErrorCount + ')</h3>';
      body += '<table style="border-collapse: collapse; width: 100%; border: 1px solid #ddd;">';
      body += '<thead style="background-color: #1976d2; color: white;">';
      body += '<tr>';
      body += '<th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Timestamp</th>';
      body += '<th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Session ID</th>';
      body += '<th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Message Type</th>';
      body += '<th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Error Message</th>';
      body += '<th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Record ID</th>';
      body += '</tr>';
      body += '</thead>';
      body += '<tbody>';

      Integer rowNum = 0;
      for (ErrorRecord error : errors) {
        String rowColor = Math.mod(rowNum, 2) == 0 ? '#ffffff' : '#f9f9f9';
        body += '<tr style="background-color: ' + rowColor + ';">';

        // Timestamp
        body +=
          '<td style="padding: 8px; border: 1px solid #ddd;">' +
          (error.occurredAt != null ? error.occurredAt.format('yyyy-MM-dd HH:mm:ss') : 'N/A') +
          '</td>';

        // Session ID
        body +=
          '<td style="padding: 8px; border: 1px solid #ddd; font-family: monospace; font-size: 11px;">' +
          escapeHtml(error.sessionId != null ? error.sessionId : 'N/A') +
          '</td>';

        // Message Type
        body +=
          '<td style="padding: 8px; border: 1px solid #ddd;">' +
          escapeHtml(error.messageType != null ? error.messageType : 'N/A') +
          '</td>';

        // Error Message
        body +=
          '<td style="padding: 8px; border: 1px solid #ddd; color: #d32f2f;">' +
          escapeHtml(truncateString(error.errorMessage, 200)) +
          '</td>';

        // Record ID
        body +=
          '<td style="padding: 8px; border: 1px solid #ddd; font-family: monospace; font-size: 11px;">' +
          escapeHtml(error.recordId != null ? error.recordId : 'N/A') +
          '</td>';

        body += '</tr>';
        rowNum++;
      }

      body += '</tbody>';
      body += '</table>';
    }

    body += '<div style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">';
    body += '<p>This is an automated notification from the Agent Error Monitor.</p>';

    if (String.isNotBlank(jobId)) {
      String jobLink = String.isNotBlank(orgUrl)
        ? '<a href="' + orgUrl + '/' + jobId + '" style="color: #1976d2;">' + jobId + '</a>'
        : jobId;
      body += '<p>Job ID: ' + jobLink + '</p>';
    }

    body += '</div>';
    body += '</body></html>';

    return body;
  }

  /**
   * @description Escapes HTML special characters
   * @param input String to escape
   * @return Escaped string
   */
  public static String escapeHtml(String input) {
    if (String.isBlank(input)) {
      return 'N/A';
    }
    return input.replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\'', '&#39;');
  }

  /**
   * @description Truncates a string to specified length
   * @param input String to truncate
   * @param maxLength Maximum length
   * @return Truncated string
   */
  public static String truncateString(String input, Integer maxLength) {
    if (String.isBlank(input)) {
      return 'N/A';
    }
    return input.length() > maxLength ? input.substring(0, maxLength) + '...' : input;
  }

  /**
   * @description Logs exception details
   * @param e Exception to log
   */
  public static void logException(Exception e) {
    System.debug(LoggingLevel.ERROR, 'Exception Type: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, 'Exception Message: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
  }

  /**
   * @description Sends scheduler error notification email
   * @param e Exception that occurred
   * @param recipientEmail Email address to send notification to
   */
  public static void sendSchedulerErrorNotification(Exception e, String recipientEmail) {
    try {
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
      email.setToAddresses(new List<String>{ recipientEmail });
      email.setSubject('Agent Error Monitor Scheduler Error - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss'));

      String body = '<html><body style="font-family: Arial, sans-serif;">';
      body += '<h2 style="color: #d32f2f;">⚠️ Scheduler Error</h2>';
      body += '<p>An error occurred while starting the Agent Error Monitor batch job.</p>';
      body += '<div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px;">';
      body += '<p><strong>Error Type:</strong> ' + e.getTypeName() + '</p>';
      body += '<p><strong>Error Message:</strong> ' + e.getMessage() + '</p>';
      body += '<p><strong>Stack Trace:</strong></p>';
      body +=
        '<pre style="background-color: #fff; padding: 10px; overflow-x: auto;">' +
        e.getStackTraceString() +
        '</pre>';
      body += '</div>';
      body += '<p style="margin-top: 20px; color: #666; font-size: 12px;">';
      body += 'Timestamp: ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss z');
      body += '</p>';
      body += '</body></html>';

      email.setHtmlBody(body);

      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    } catch (Exception emailException) {
      logException(emailException);
    }
  }

  public class AgentErrorMonitorException extends Exception {
  }
}

