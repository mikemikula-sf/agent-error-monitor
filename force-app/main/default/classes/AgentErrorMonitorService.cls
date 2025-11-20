/**
 * @description Service class for Agent Error Monitoring.
 * Handles error detection, query building, HTML generation, and email notifications.
 * Uses inner classes to minimize Apex class count while maintaining separation of concerns.
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

  /**
   * @description Context object containing job execution information
   */
  public class JobContext {
    /** @description Salesforce job ID */
    public String jobId { get; set; }
    /** @description Execution duration in seconds */
    public Long durationSeconds { get; set; }
    /** @description Whether the job was scheduled or run manually */
    public Boolean isScheduled { get; set; }
    /** @description Number of hours looked back for errors */
    public Integer lookbackHours { get; set; }

    /**
     * @description Constructor for JobContext
     * @param jobId Salesforce job ID
     * @param durationSeconds Execution duration in seconds
     * @param isScheduled Whether the job was scheduled or run manually
     * @param lookbackHours Number of hours looked back for errors
     */
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

  /**
   * @description Validates lookback hours parameter
   * @param hoursBack Number of hours to validate
   */
  public static void validateHoursBack(Integer hoursBack) {
    if (hoursBack == null || hoursBack < MIN_HOURS || hoursBack > MAX_HOURS) {
      throw new IllegalArgumentException('hoursBack must be between ' + MIN_HOURS + ' and ' + MAX_HOURS + ' (30 days)');
    }
  }

  /**
   * @description Validates email address parameter
   * @param email Email address to validate
   */
  public static void validateEmail(String email) {
    if (String.isBlank(email)) {
      throw new IllegalArgumentException('Recipient email is required');
    }
  }

  /**
   * @description Validates batch size parameter
   * @param batchSize Batch size to validate
   * @param minSize Minimum allowed batch size
   * @param maxSize Maximum allowed batch size
   */
  public static void validateBatchSize(Integer batchSize, Integer minSize, Integer maxSize) {
    if (batchSize == null || batchSize < minSize || batchSize > maxSize) {
      throw new IllegalArgumentException('Batch size must be between ' + minSize + ' and ' + maxSize);
    }
  }

  // ============================================================================
  // QUERY BUILDING (Private - internal helpers)
  // ============================================================================

  /**
   * @description Builds a comma-separated field list for SOQL queries
   * @param fields List of field API names to include in the query
   * @return Comma-separated string of field names
   */
  @TestVisible
  private static String buildFieldList(List<String> fields) {
    if (fields == null || fields.isEmpty()) {
      throw new IllegalArgumentException('Fields list cannot be null or empty');
    }
    return String.join(fields, ', ');
  }

  /**
   * @description Builds WHERE clause to match error patterns in AI Agent messages
   * @return WHERE clause string with OR conditions for various error patterns
   */
  private static String buildErrorPatternWhereClause() {
    List<String> errorPatterns = new List<String>{ 'error id:', 'error ID:', 'Error ID:', 'ERROR ID:' };
    List<String> conditions = new List<String>();
    for (String pattern : errorPatterns) {
      String escapedPattern = String.escapeSingleQuotes(pattern);
      conditions.add(AI_AGENT_CONTENT_FIELD + ' LIKE \'%' + escapedPattern + '%\'');
    }
    return '(' + String.join(conditions, ' OR ') + ')';
  }

  /**
   * @description Builds complete SOQL query for error records
   * @param cutoffTime DateTime threshold - only records after this time are included
   * @return Complete SOQL query string ready for execution
   */
  private static String buildErrorRecordsQuery(DateTime cutoffTime) {
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
  // HTML GENERATION (Private - internal helpers)
  // Note: Inline styles are required for email client compatibility
  // ============================================================================

  /**
   * @description Wraps content in complete HTML document structure
   * @param bodyContent HTML content to wrap
   * @return Complete HTML document with body styling
   */
  private static String wrapInHtmlDocument(String bodyContent) {
    return '<html><body style="font-family: Arial, sans-serif;">' + bodyContent + '</body></html>';
  }

  /**
   * @description Builds HTML heading element with optional inline styles
   * @param level Heading level (1-6)
   * @param text Heading text content
   * @param style Optional inline CSS styles
   * @return HTML heading element
   */
  private static String buildHeading(Integer level, String text, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<h' + level + styleAttr + '>' + text + '</h' + level + '>';
  }

  /**
   * @description Builds HTML paragraph element with optional inline styles
   * @param text Paragraph text content
   * @param style Optional inline CSS styles
   * @return HTML paragraph element
   */
  private static String buildParagraph(String text, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<p' + styleAttr + '>' + text + '</p>';
  }

  /**
   * @description Builds HTML div element with optional inline styles
   * @param content Div content
   * @param style Optional inline CSS styles
   * @return HTML div element
   */
  private static String buildDiv(String content, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<div' + styleAttr + '>' + content + '</div>';
  }

  /**
   * @description Builds HTML table cell with optional HTML escaping
   * @param content Cell content
   * @param style Inline CSS styles for the cell
   * @param escape Whether to HTML-escape the content
   * @return HTML table cell element
   */
  private static String buildTableCell(String content, String style, Boolean escape) {
    String safeContent = escape ? escapeHtml(content) : content;
    return '<td style="' + style + '">' + safeContent + '</td>';
  }

  /**
   * @description Builds HTML table row from list of cells
   * @param cells List of HTML table cell strings
   * @param rowStyle Optional inline CSS styles for the row
   * @return HTML table row element
   */
  private static String buildTableRow(List<String> cells, String rowStyle) {
    String styleAttr = String.isNotBlank(rowStyle) ? ' style="' + rowStyle + '"' : '';
    return '<tr' + styleAttr + '>' + String.join(cells, '') + '</tr>';
  }

  /**
   * @description Builds complete HTML table with headers and rows
   * @param headers List of header text strings
   * @param rows List of HTML row strings
   * @param tableStyle Inline CSS styles for the table
   * @return Complete HTML table element
   */
  private static String buildTable(List<String> headers, List<String> rows, String tableStyle) {
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

  /**
   * @description Builds HTML pre element for preformatted text
   * @param content Preformatted text content
   * @param style Optional inline CSS styles
   * @return HTML pre element
   */
  private static String buildPre(String content, String style) {
    String styleAttr = String.isNotBlank(style) ? ' style="' + style + '"' : '';
    return '<pre' + styleAttr + '>' + content + '</pre>';
  }

  /**
   * @description Builds summary section with job execution details
   * @param totalErrorCount Total number of errors found
   * @param jobContext Job execution context with metadata
   * @return HTML div containing summary table
   */
  private static String buildSummarySection(Integer totalErrorCount, JobContext jobContext) {
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

  /**
   * @description Builds a single row for the summary table
   * @param label Row label text
   * @param value Row value text (may contain HTML)
   * @param valueStyle Optional inline CSS styles for the value cell
   * @return HTML table row with label and value cells
   */
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

  /**
   * @description Builds error details table with all error records
   * @param errors List of error records to display
   * @param totalErrorCount Total count (may exceed list size if query was limited)
   * @return HTML section with error details table
   */
  private static String buildErrorDetailsTable(List<ErrorRecord> errors, Integer totalErrorCount) {
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

  /**
   * @description Builds a single table row for an error record
   * @param error Error record to display
   * @param rowNum Row number for alternating row colors
   * @return HTML table row with error details
   */
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

  /**
   * @description Builds email footer with job metadata and links
   * @param jobContext Job execution context
   * @return HTML div containing footer content
   */
  private static String buildFooterSection(JobContext jobContext) {
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

  /**
   * @description Builds complete email body with all sections
   * @param errors List of error records to display
   * @param totalErrorCount Total error count
   * @param jobContext Job execution context
   * @return Complete HTML email body
   */
  @TestVisible
  private static String buildEmailBody(List<ErrorRecord> errors, Integer totalErrorCount, JobContext jobContext) {
    List<String> bodyParts = new List<String>();
    bodyParts.add(buildHeading(2, '⚠️ Agent Errors Detected', 'color: ' + COLOR_ERROR + ';'));
    bodyParts.add(buildSummarySection(totalErrorCount, jobContext));
    bodyParts.add(buildErrorDetailsTable(errors, totalErrorCount));
    bodyParts.add(buildFooterSection(jobContext));

    return wrapInHtmlDocument(String.join(bodyParts, ''));
  }

  /**
   * @description Builds email body for scheduler error notifications
   * @param e Exception that occurred during scheduling
   * @return Complete HTML email body for error notification
   */
  private static String buildSchedulerErrorEmailBody(Exception e) {
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

  /**
   * @description Gets the current org's base URL
   * @return Org domain URL or empty string if unavailable
   */
  @TestVisible
  private static String getOrgUrl() {
    try {
      return URL.getOrgDomainUrl().toExternalForm();
    } catch (Exception e) {
      return '';
    }
  }

  /**
   * @description Gets the Lightning setup URL for job monitoring
   * @param isScheduled Whether this is a scheduled job (vs batch job)
   * @return Lightning setup URL path
   */
  @TestVisible
  private static String getJobUrl(Boolean isScheduled) {
    return isScheduled ? '/lightning/setup/ScheduledJobs/home' : '/lightning/setup/AsyncApexJobs/home';
  }

  /**
   * @description Builds HTML link to job monitoring page
   * @param jobId Salesforce job ID
   * @param orgUrl Organization base URL
   * @param isScheduled Whether this is a scheduled job
   * @return HTML anchor tag with job link or plain job ID if URL unavailable
   */
  @TestVisible
  private static String buildJobLink(String jobId, String orgUrl, Boolean isScheduled) {
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

  /**
   * @description Interface for email sending to allow dependency injection for testing
   */
  public interface IEmailSender {
    /**
     * @description Sends an email
     * @param recipientEmail Email address to send to
     * @param subject Email subject
     * @param htmlBody HTML body content
     * @return True if email sent successfully
     */
    Boolean sendEmail(String recipientEmail, String subject, String htmlBody);
  }

  /**
   * @description Default implementation of IEmailSender using Salesforce Messaging API
   */
  public class DefaultEmailSender implements IEmailSender {
    /**
     * @description Sends an email using Salesforce Messaging API
     * @param recipientEmail Email address to send to
     * @param subject Email subject
     * @param htmlBody HTML body content
     * @return True if email sent successfully
     */
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

  /**
   * @description Handles sending error notifications via email
   */
  public class Notifier {
    private IEmailSender emailSender;

    /**
     * @description Constructor with custom email sender (for testing)
     * @param emailSender Custom email sender implementation
     */
    public Notifier(IEmailSender emailSender) {
      this.emailSender = emailSender;
    }

    /**
     * @description Constructor with default email sender
     */
    public Notifier() {
      this(new DefaultEmailSender());
    }

    /**
     * @description Sends error notification email
     * @param errors List of error records to include in notification
     * @param recipientEmail Email address to send to
     * @param jobContext Job execution context
     * @return True if email sent successfully
     */
    public Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, JobContext jobContext) {
      if (errors.isEmpty()) {
        return false;
      }

      String subject = 'Agent Errors Detected - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
      String htmlBody = buildEmailBody(errors, errors.size(), jobContext);

      return emailSender.sendEmail(recipientEmail, subject, htmlBody);
    }

    /**
     * @description Sends scheduler error notification email
     * @param e Exception that occurred
     * @param recipientEmail Email address to send to
     */
    public void sendSchedulerErrorNotification(Exception e, String recipientEmail) {
      String subject = 'Agent Error Monitor Scheduler Error - ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss');
      String htmlBody = buildSchedulerErrorEmailBody(e);

      emailSender.sendEmail(recipientEmail, subject, htmlBody);
    }
  }

  // ============================================================================
  // UTILITY METHODS (Public for logging, Private for internal helpers)
  // ============================================================================

  /**
   * @description Logs exception details for debugging
   * @param e Exception to log
   */
  public static void logException(Exception e) {
    // Log exception details for debugging
    // Note: In production, consider using a logging framework or Platform Events
    System.debug(
      LoggingLevel.ERROR,
      'Agent Error Monitor Exception - Type: ' + e.getTypeName() + ', Message: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString()
    );
  }

  /**
   * @description Returns 'N/A' if value is null, otherwise returns the value
   * @param value String value to check
   * @return Original value or 'N/A' if null
   */
  private static String defaultToNA(String value) {
    return value != null ? value : 'N/A';
  }

  /**
   * @description Truncates string to maximum length with ellipsis
   * @param input String to truncate
   * @param maxLength Maximum allowed length before truncation
   * @return Truncated string with '...' or 'N/A' if blank
   */
  @TestVisible
  private static String truncate(String input, Integer maxLength) {
    if (String.isBlank(input)) {
      return 'N/A';
    }
    return input.length() > maxLength ? input.substring(0, maxLength) + '...' : input;
  }

  /**
   * @description Escapes HTML special characters to prevent XSS attacks
   * @param input String to escape
   * @return HTML-escaped string or 'N/A' if blank
   */
  @TestVisible
  private static String escapeHtml(String input) {
    if (String.isBlank(input)) {
      return 'N/A';
    }
    return input.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll('\'', '&#39;');
  }

  // ============================================================================
  // DATA MODELS
  // ============================================================================

  /**
   * @description Data model representing an error record
   */
  public class ErrorRecord {
    /** @description Salesforce record ID */
    public String recordId { get; set; }
    /** @description Error message text */
    public String errorMessage { get; set; }
    /** @description Timestamp when error occurred */
    public DateTime occurredAt { get; set; }
    /** @description Operation being performed when error occurred */
    public String operation { get; set; }
    /** @description Object name where error occurred */
    public String objectName { get; set; }
    /** @description Status of the record */
    public String status { get; set; }
    /** @description Type of message */
    public String messageType { get; set; }
    /** @description Session ID associated with the error */
    public String sessionId { get; set; }

    /**
     * @description Default constructor for manual instantiation
     */
    public ErrorRecord() {
    }

    /**
     * @description Constructor from sObject record
     * @param record sObject containing error data
     */
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

  /**
   * @description Result object containing processing statistics
   */
  public class ProcessingResult {
    /** @description Total number of records processed */
    public Integer totalRecords { get; set; }
    /** @description List of error records found */
    public List<ErrorRecord> errorRecords { get; set; }
    /** @description Duration of processing in milliseconds */
    public Long durationMilliseconds { get; set; }

    /**
     * @description Constructor initializing default values
     */
    public ProcessingResult() {
      this.totalRecords = 0;
      this.errorRecords = new List<ErrorRecord>();
      this.durationMilliseconds = 0;
    }
  }

  // ============================================================================
  // DATA PROCESSING
  // ============================================================================

  /**
   * @description Queries error records from the database
   * @param hoursBack Number of hours to look back for errors
   * @return List of sObjects containing error records
   */
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

  /**
   * @description Processes error records and adds them to the result
   * @param records List of sObjects to process
   * @param result ProcessingResult to update with processed records
   */
  public static void processRecords(List<sObject> records, ProcessingResult result) {
    for (sObject record : records) {
      result.totalRecords++;
      ErrorRecord errorRec = new ErrorRecord(record);
      result.errorRecords.add(errorRec);
    }
  }

  /**
   * @description Send error notification with default duration (0 seconds) and not scheduled
   * @param errors List of error records to include in notification
   * @param recipientEmail Email address to send to
   * @param jobId Salesforce job ID
   * @return True if email sent successfully
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, String jobId) {
    JobContext jobContext = new JobContext(jobId, 0, false, null);
    return sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * @description Send error notification with execution duration and not scheduled
   * @param errors List of error records to include in notification
   * @param recipientEmail Email address to send to
   * @param jobId Salesforce job ID
   * @param durationSeconds Execution duration in seconds
   * @return True if email sent successfully
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, String jobId, Long durationSeconds) {
    JobContext jobContext = new JobContext(jobId, durationSeconds, false, null);
    return sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * @description Send error notification with execution duration and schedule status
   * @param errors List of error records to include in notification
   * @param recipientEmail Email address to send to
   * @param jobId Salesforce job ID
   * @param durationSeconds Execution duration in seconds
   * @param isScheduled Whether the job was scheduled or run manually
   * @return True if email sent successfully
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
   * @description Send error notification with full context including lookback hours
   * @param errors List of error records to include in notification
   * @param recipientEmail Email address to send to
   * @param jobId Salesforce job ID
   * @param durationSeconds Execution duration in seconds
   * @param isScheduled Whether the job was scheduled or run manually
   * @param lookbackHours Number of hours looked back for errors
   * @return True if email sent successfully
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
   * @description Send error notification with job context
   * @param errors List of error records to include in notification
   * @param recipientEmail Email address to send to
   * @param jobContext Job execution context
   * @return True if email sent successfully
   */
  public static Boolean sendErrorNotification(List<ErrorRecord> errors, String recipientEmail, JobContext jobContext) {
    Notifier notifier = new Notifier();
    return notifier.sendErrorNotification(errors, recipientEmail, jobContext);
  }

  /**
   * @description Send scheduler error notification when batch job fails to start
   * @param e Exception that occurred
   * @param recipientEmail Email address to send to
   */
  public static void sendSchedulerErrorNotification(Exception e, String recipientEmail) {
    Notifier notifier = new Notifier();
    notifier.sendSchedulerErrorNotification(e, recipientEmail);
  }

  /**
   * @description Custom exception class for Agent Error Monitor
   */
  public class AgentErrorMonitorException extends Exception {
  }
}
