/**
 * Service class for Agent Error Monitoring
 * Handles error detection, query building, HTML generation, and email notifications
 * Uses inner classes to minimize Apex class count while maintaining separation of concerns
 */
public with sharing class AgentErrorMonitorService {
  // ============================================================================
  // CONFIGURATION & CONSTANTS
  // ============================================================================

  public static final Integer DEFAULT_LOOKBACK_HOURS = 24;
  public static final Integer DEFAULT_BATCH_SIZE = 200;
  public static final Integer MIN_BATCH_SIZE = 1;
  public static final Integer MAX_BATCH_SIZE = 2000;

  public static final Integer MIN_HOURS = 1;
  public static final Integer MAX_HOURS = 720;
  public static final Integer MAX_QUERY_RECORDS = 100;
  public static final Integer MAX_ERROR_MESSAGE_LENGTH = 1000;

  public static final String AI_AGENT_OBJECT = 'ssot__AiAgentInteractionMessage__dlm';
  public static final String AI_AGENT_CONTENT_FIELD = 'ssot__ContentText__c';
  public static final String AI_AGENT_TYPE_FIELD = 'ssot__AiAgentInteractionMessageType__c';
  public static final String AI_AGENT_TIMESTAMP_FIELD = 'ssot__MessageSentTimestamp__c';
  public static final String AI_AGENT_SESSION_FIELD = 'ssot__AiAgentSessionId__c';

  public static final String ERROR_STATUS = 'Failed';

  // Email HTML requires inline styles for email client compatibility
  // Most email clients (Gmail, Outlook, etc.) strip <style> tags and external CSS
  public static final String COLOR_ERROR = '#d32f2f';
  public static final String COLOR_PRIMARY = '#1976d2';
  public static final String COLOR_TEXT_MUTED = '#666';
  public static final String COLOR_BACKGROUND_LIGHT = '#f5f5f5';
  public static final String COLOR_BACKGROUND_ALT = '#f9f9f9';
  public static final String COLOR_BORDER = '#ddd';
  public static final String COLOR_WHITE = '#ffffff';

  public static final String TD_STYLE_BASE = 'padding: 8px; border: 1px solid ' + COLOR_BORDER + ';';
  public static final String TD_STYLE_MONOSPACE = TD_STYLE_BASE + ' font-family: monospace; font-size: 11px;';
  public static final String TD_STYLE_ERROR = TD_STYLE_BASE + ' color: ' + COLOR_ERROR + ';';

  public static final String CONTAINER_STYLE = 'background-color: ' + COLOR_BACKGROUND_LIGHT + '; padding: 15px; border-radius: 5px;';
  public static final String TABLE_STYLE = 'border-collapse: collapse; width: 100%; border: 1px solid ' + COLOR_BORDER + ';';
  public static final String TABLE_HEADER_STYLE = 'background-color: ' + COLOR_PRIMARY + '; color: white;';
  public static final String TABLE_CELL_HEADER_STYLE = 'padding: 10px; text-align: left; border: 1px solid ' + COLOR_BORDER + ';';

  // ============================================================================
  // CONTEXT OBJECTS
  // ============================================================================

  public class JobContext {
    public String jobId { get; set; }
    public Long durationSeconds { get; set; }
    public Boolean isScheduled { get; set; }
    public Integer lookbackHours { get; set; }

    public JobContext(String jobId, Long durationSeconds, Boolean isScheduled, Integer lookbackHours) {
      this.jobId = jobId;
      this.durationSeconds = durationSeconds;
      this.isScheduled = isScheduled;
      this.lookbackHours = lookbackHours;
    }
  }

  // ============================================================================
  // VALIDATION
  // ============================================================================

  public static void validateHoursBack(Integer hoursBack) {
    if (hoursBack == null || hoursBack < MIN_HOURS || hoursBack > MAX_HOURS) {
      throw new IllegalArgumentException('hoursBack must be between ' + MIN_HOURS + ' and ' + MAX_HOURS + ' (30 days)');
    }
  }

  public static void validateEmail(String email) {
    if (String.isBlank(email)) {
      throw new IllegalArgumentException('Recipient email is required');
    }
  }

  public static void validateBatchSize(Integer batchSize, Integer minSize, Integer maxSize) {
    if (batchSize == null || batchSize < minSize || batchSize > maxSize) {
      throw new IllegalArgumentException('Batch size must be between ' + minSize + ' and ' + maxSize);
    }
  }

  // ============================================================================
  // QUERY BUILDING
  // ============================================================================

  public static String buildFieldList(List<String> fields) {
    if (fields == null || fields.isEmpty()) {
      throw new IllegalArgumentException('Fields list cannot be null or empty');
    }
    return String.join(fields, ', ');
  }

  public static String buildErrorPatternWhereClause() {
    List<String> errorPatterns = new List<String>{ 'error id:', 'error ID:', 'Error ID:', 'ERROR ID:' };
    List<String> conditions = new List<String>();
    for (String pattern : errorPatterns) {
      String escapedPattern = String.escapeSingleQuotes(pattern);
      conditions.add(AI_AGENT_CONTENT_FIELD + ' LIKE \'%' + escapedPattern + '%\'');
    }
    return '(' + String.join(conditions, ' OR ') + ')';
  }

  public static String buildErrorRecordsQuery(DateTime cutoffTime) {
    List<String> fields = new List<String>{ 'Id', AI_AGENT_CONTENT_FIELD, AI_AGENT_TYPE_FIELD, AI_AGENT_TIMESTAMP_FIELD, AI_AGENT_SESSION_FIELD };

    return 'SELECT ' +
      buildFieldList(fields) +
      ' FROM ' +
      AI_AGENT_OBJECT +
      ' WHERE ' +
      AI_AGENT_TIMESTAMP_FIELD +
      ' >= :cutoffTime AND ' +
      buildErrorPatternWhereClause() +
      ' ORDER BY ' +
      AI_AGENT_TIMESTAMP_FIELD +
      ' DESC LIMIT ' +
      MAX_QUERY_RECORDS;
  }

  // ============================================================================
  // HTML GENERATION
  // Note: Inline styles are required for email client compatibility
  // ============================================================================

  public static String wrapInHtmlDocument(String bodyContent) {
    return '<html><body style="font-family: Arial, sans-serif;">' + bodyContent + '</body></html>';
  }

  public static String buildHeading(Integer level, String text, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<h' + level + styleAttr + '>' + text + '</h' + level + '>';
  }

  public static String buildParagraph(String text, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<p' + styleAttr + '>' + text + '</p>';
  }

  public static String buildDiv(String content, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<div' + styleAttr + '>' + content + '</div>';
  }

  public static String buildTableCell(String content, String style, Boolean escape) {
    String safeContent = escape ? escapeHtml(content) : content;
    return '<td style="' + style + '">' + safeContent + '</td>';
  }

  public static String buildTableRow(List<String> cells, String rowStyle) {
    String styleAttr = String.isNotBlank(rowStyle) ? ' style="' + rowStyle + '"' : '';
    return '<tr' + styleAttr + '>' + String.join(cells, '') + '</tr>';
  }

  public static String buildTable(List<String> headers, List<String> rows, String tableStyle) {
    List<String> parts = new List<String>();
    parts.add('<table style="' + tableStyle + '">');

    if (!headers.isEmpty()) {
      parts.add('<thead style="' + TABLE_HEADER_STYLE + '">');
      List<String> headerCells = new List<String>();
      for (String header : headers) {
        headerCells.add('<th style="' + TABLE_CELL_HEADER_STYLE + '">' + header + '</th>');
      }
      parts.add(buildTableRow(headerCells, null));
      parts.add('</thead>');
    }

    parts.add('<tbody>');
    parts.addAll(rows);
    parts.add('</tbody>');
    parts.add('</table>');

    return String.join(parts, '');
  }

  public static String buildPre(String content, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<pre' + styleAttr + '>' + content + '</pre>';
  }

  public static String buildSummarySection(Integer totalErrorCount, JobContext jobContext) {
    String orgUrl = getOrgUrl();
    List<String> tableRows = new List<String>();

    tableRows.add(buildSummaryRow('Total Errors Found:', String.valueOf(totalErrorCount), 'color: ' + COLOR_ERROR + ';'));

    if (jobContext.durationSeconds > 0) {
      tableRows.add(buildSummaryRow('Execution Time:', jobContext.durationSeconds + ' seconds', null));
    }

    String jobType = jobContext.isScheduled ? 'Scheduled' : 'Manual';
    tableRows.add(buildSummaryRow('Job Type:', jobType, null));

    if (jobContext.isScheduled && jobContext.lookbackHours != null) {
      String lookbackDisplay = jobContext.lookbackHours + ' hour' + (jobContext.lookbackHours != 1 ? 's' : '');
      tableRows.add(buildSummaryRow('Lookback Period:', lookbackDisplay, null));
    }

    if (String.isNotBlank(jobContext.jobId)) {
      String jobLink = buildJobLink(jobContext.jobId, orgUrl, jobContext.isScheduled);
      tableRows.add(buildSummaryRow('Job ID:', jobLink, null));
    }

    tableRows.add(buildSummaryRow('Timestamp:', DateTime.now().format('yyyy-MM-dd HH:mm:ss z'), null));

    String table = buildTable(new List<String>(), tableRows, 'border-collapse: collapse;');

    return buildDiv(buildHeading(3, 'Summary', 'margin-top: 0;') + table, CONTAINER_STYLE + ' margin-bottom: 20px;');
  }

  private static String buildSummaryRow(String label, String value, String valueStyle) {
    List<String> cells = new List<String>();
    cells.add(buildTableCell(label, 'padding: 5px; font-weight: bold;', false));

    String cellStyle = 'padding: 5px;';
    if (String.isNotBlank(valueStyle)) {
      cellStyle += ' ' + valueStyle;
    }
    cells.add(buildTableCell(value, cellStyle, false));

    return buildTableRow(cells, null);
  }

  public static String buildErrorDetailsTable(List<ErrorRecord> errors, Integer totalErrorCount) {
    if (errors.isEmpty()) {
      return '';
    }

    List<String> parts = new List<String>();

    // If we hit the query limit, indicate there may be more
    String countDisplay = totalErrorCount >= MAX_QUERY_RECORDS ? totalErrorCount + '+' : String.valueOf(totalErrorCount);
    parts.add(buildHeading(3, 'Error Details (showing ' + errors.size() + ' of ' + countDisplay + ')', null));

    List<String> headers = new List<String>{ 'Timestamp', 'Session ID', 'Message Type', 'Error Message', 'Record ID' };

    List<String> rows = new List<String>();
    Integer rowNum = 0;
    for (ErrorRecord error : errors) {
      rows.add(buildErrorTableRow(error, rowNum));
      rowNum++;
    }

    parts.add(buildTable(headers, rows, TABLE_STYLE));

    return String.join(parts, '');
  }

  private static String buildErrorTableRow(ErrorRecord error, Integer rowNum) {
    List<String> cells = new List<String>();
    String rowColor = Math.mod(rowNum, 2) == 0 ? COLOR_WHITE : COLOR_BACKGROUND_ALT;

    String timestamp = error.occurredAt != null ? error.occurredAt.format('yyyy-MM-dd HH:mm:ss') : 'N/A';
    cells.add(buildTableCell(timestamp, TD_STYLE_BASE, false));
    cells.add(buildTableCell(defaultToNA(error.sessionId), TD_STYLE_MONOSPACE, true));
    cells.add(buildTableCell(defaultToNA(error.messageType), TD_STYLE_BASE, true));
    cells.add(buildTableCell(truncate(error.errorMessage, MAX_ERROR_MESSAGE_LENGTH), TD_STYLE_ERROR, true));
    cells.add(buildTableCell(defaultToNA(error.recordId), TD_STYLE_MONOSPACE, true));

    return buildTableRow(cells, 'background-color: ' + rowColor + ';');
  }

  public static String buildFooterSection(JobContext jobContext) {
    String orgUrl = getOrgUrl();
    List<String> parts = new List<String>();
    parts.add(buildParagraph('This is an automated notification from the Agent Error Monitor.', null));

    if (String.isNotBlank(jobContext.jobId)) {
      String jobLink = buildJobLink(jobContext.jobId, orgUrl, jobContext.isScheduled);
      parts.add(buildParagraph('Job ID: ' + jobLink, null));
    }

    return buildDiv(
      String.join(parts, ''),
      'margin-top: 20px; padding-top: 20px; border-top: 1px solid ' + COLOR_BORDER + '; color: ' + COLOR_TEXT_MUTED + '; font-size: 12px;'
    );
  }

  public static String buildEmailBody(List<ErrorRecord> errors, Integer totalErrorCount, JobContext jobContext) {
    List<String> bodyParts = new List<String>();
    bodyParts.add(buildHeading(2, '⚠️ Agent Errors Detected', 'color: ' + COLOR_ERROR + ';'));
    bodyParts.add(buildSummarySection(totalErrorCount, jobContext));
    bodyParts.add(buildErrorDetailsTable(errors, totalErrorCount));
    bodyParts.add(buildFooterSection(jobContext));

    return wrapInHtmlDocument(String.join(bodyParts, ''));
  }

  public static String buildSchedulerErrorEmailBody(Exception e) {
    List<String> parts = new List<String>();
    parts.add(buildHeading(2, '⚠️ Scheduler Error', 'color: ' + COLOR_ERROR + ';'));
    parts.add(buildParagraph('An error occurred while starting the Agent Error Monitor batch job.', null));

    List<String> errorDetails = new List<String>();
    errorDetails.add(buildParagraph('<strong>Error Type:</strong> ' + e.getTypeName(), null));
    errorDetails.add(buildParagraph('<strong>Error Message:</strong> ' + escapeHtml(e.getMessage()), null));
    errorDetails.add(buildParagraph('<strong>Stack Trace:</strong>', null));
    errorDetails.add(buildPre(escapeHtml(e.getStackTraceString()), 'background-color: ' + COLOR_WHITE + '; padding: 10px; overflow-x: auto;'));

    parts.add(buildDiv(String.join(errorDetails, ''), CONTAINER_STYLE));
    parts.add(
      buildParagraph(
        'Timestamp: ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss z'),
        'margin-top: 20px; color: ' + COLOR_TEXT_MUTED + '; font-size: 12px;'
      )
    );

    return wrapInHtmlDocument(String.join(parts, ''));
  }

  public static String getOrgUrl() {
    try {
      return URL.getOrgDomainUrl().toExternalForm();
    } catch (Exception e) {
      return '';
    }
  }

  public static String getJobUrl(Boolean isScheduled) {
    return isScheduled ? '/lightning/setup/ScheduledJobs/home' : '/lightning/setup/AsyncApexJobs/home';
  }

  public static String buildJobLink(String jobId, String orgUrl, Boolean isScheduled) {
    if (String.isBlank(jobId)) {
      return '';
    }

    if (String.isBlank(orgUrl)) {
      return jobId;
    }

    String jobUrl = getJobUrl(isScheduled);
    return '<a href="' + orgUrl + jobUrl + '" style="color: ' + COLOR_PRIMARY + ';">' + jobId + '</a>';
  }

  // ============================================================================
  // EMAIL NOTIFICATION
  // ============================================================================

  public interface IEmailSender {
    Boolean sendEmail(String recipientEmail, String subject, String htmlBody);
  }

  public class DefaultEmailSender implements IEmailSender {
    public Boolean sendEmail(String recipientEmail, String subject, String htmlBody) {
      try {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ recipientEmail });
        email.setSubject(subject);
        email.setHtmlBody(htmlBody);

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
        return true;
      } catch (Exception e) {
        logException(e);
        return false;
      }
    }
  }

  public class Notifier {
    private IEmailSender emailSender;

    public Notifier(IEmailSender emailSender) {
      this.emailSender = emailSender;
    }

    public Notifier() {
      this(new DefaultEmailSender());
    }

    public Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, JobContext jobContext) {
      if (errors.isEmpty()) {
        return false;
      }

      String subject = 'Agent Errors Detected - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
      String htmlBody = buildEmailBody(errors, errors.size(), jobContext);

      return emailSender.sendEmail(recipientEmail, subject, htmlBody);
    }

    public void sendSchedulerErrorNotification(Exception e, String recipientEmail) {
      String subject = 'Agent Error Monitor Scheduler Error - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
      String htmlBody = buildSchedulerErrorEmailBody(e);

      emailSender.sendEmail(recipientEmail, subject, htmlBody);
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  public static void logException(Exception e) {
    System.debug(LoggingLevel.ERROR, 'Exception Type: ' + e.getTypeName());
    System.debug(LoggingLevel.ERROR, 'Exception Message: ' + e.getMessage());
    System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
  }

  public static String defaultToNA(String value) {
    return value != null ? value : 'N/A';
  }

  public static String truncate(String input, Integer maxLength) {
    if (String.isBlank(input)) {
      return 'N/A';
    }
    return input.length() > maxLength ? input.substring(0, maxLength) + '...' : input;
  }

  public static String escapeHtml(String input) {
    if (String.isBlank(input)) {
      return 'N/A';
    }
    return input.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll('\'', '&#39;');
  }

  // ============================================================================
  // DATA MODELS
  // ============================================================================

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
      this.errorMessage = (String) record.get(AI_AGENT_CONTENT_FIELD);
      this.occurredAt = (DateTime) record.get(AI_AGENT_TIMESTAMP_FIELD);
      this.messageType = (String) record.get(AI_AGENT_TYPE_FIELD);
      this.sessionId = (String) record.get(AI_AGENT_SESSION_FIELD);
      this.operation = null;
      this.objectName = null;
      this.status = null;
    }
  }

  public class ProcessingResult {
    public Integer totalRecords { get; set; }
    public List<ErrorRecord> errorRecords { get; set; }
    public Long durationMilliseconds { get; set; }

    public ProcessingResult() {
      this.totalRecords = 0;
      this.errorRecords = new List<ErrorRecord>();
      this.durationMilliseconds = 0;
    }
  }

  // ============================================================================
  // DATA PROCESSING
  // ============================================================================

  public static List<sObject> queryErrorRecords(Integer hoursBack) {
    validateHoursBack(hoursBack);
    DateTime cutoffTime = DateTime.now().addHours(-hoursBack);
    String query = buildErrorRecordsQuery(cutoffTime);

    try {
      return Database.query(query, AccessLevel.USER_MODE);
    } catch (QueryException e) {
      logException(e);
      throw new AgentErrorMonitorException('Failed to query error records: ' + e.getMessage(), e);
    }
  }

  public static void processRecords(List<sObject> records, ProcessingResult result) {
    for (sObject record : records) {
      result.totalRecords++;
      ErrorRecord errorRec = new ErrorRecord(record);
        result.errorRecords.add(errorRec);
    }
  }

  /**
   * Send error notification with default duration (0 seconds) and not scheduled
   * Delegates to overloaded method with full parameters
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, String jobId) {
    JobContext jobContext = new JobContext(jobId, 0, false, null);
    return sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * Send error notification with execution duration and not scheduled
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, String jobId, Long durationSeconds) {
    JobContext jobContext = new JobContext(jobId, durationSeconds, false, null);
    return sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * Send error notification with execution duration and schedule status
   */
  public static Boolean sendErrorNotification(
    List<ErrorRecord> errors,
    String recipientEmail,
    String jobId,
    Long durationSeconds,
    Boolean isScheduled
  ) {
    JobContext jobContext = new JobContext(jobId, durationSeconds, isScheduled, null);
    return sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * Send error notification with full context including lookback hours
   */
  public static Boolean sendErrorNotification(
    List<ErrorRecord> errors,
    String recipientEmail,
    String jobId,
    Long durationSeconds,
    Boolean isScheduled,
    Integer lookbackHours
  ) {
    JobContext jobContext = new JobContext(jobId, durationSeconds, isScheduled, lookbackHours);
    return sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * Send error notification with notification context
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, JobContext jobContext) {
    Notifier notifier = new Notifier();
    return notifier.sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * Send scheduler error notification when batch job fails to start
   */
  public static void sendSchedulerErrorNotification(Exception e, String recipientEmail) {
    Notifier notifier = new Notifier();
    notifier.sendSchedulerErrorNotification(e, recipientEmail);
  }

  public class AgentErrorMonitorException extends Exception {
  }
}
