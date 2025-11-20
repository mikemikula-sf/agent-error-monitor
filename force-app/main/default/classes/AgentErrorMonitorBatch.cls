/**
 * @description Batch class for processing Agent Error records.
 * Queries error records, processes them, and sends email notifications.
 * Implements Database.Stateful to maintain state across batch executions.
 */
public with sharing class AgentErrorMonitorBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
  @TestVisible
  private String recipientEmail;
  @TestVisible
  private Integer lookbackHours;
  @TestVisible
  private DateTime startTime;
  @TestVisible
  private AgentErrorMonitorService.ProcessingResult result;
  @TestVisible
  private Boolean isScheduled;

  /**
   * @description Constructor with default lookback hours (24 hours) and not scheduled
   * @param recipientEmail Email address to send error notifications to
   */
  public AgentErrorMonitorBatch(String recipientEmail) {
    this(recipientEmail, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS, false);
  }

  /**
   * @description Constructor with custom lookback hours and not scheduled
   * @param recipientEmail Email address to send error notifications to
   * @param lookbackHours Number of hours to look back for errors
   */
  public AgentErrorMonitorBatch(String recipientEmail, Integer lookbackHours) {
    this(recipientEmail, lookbackHours, false);
  }

  /**
   * @description Full constructor with all parameters
   * @param recipientEmail Email address to send error notifications to
   * @param lookbackHours Number of hours to look back for errors
   * @param isScheduled Whether this batch is running from a scheduled job
   */
  public AgentErrorMonitorBatch(String recipientEmail, Integer lookbackHours, Boolean isScheduled) {
    AgentErrorMonitorService.validateEmail(recipientEmail);
    AgentErrorMonitorService.validateHoursBack(lookbackHours);

    this.recipientEmail = recipientEmail;
    this.lookbackHours = lookbackHours;
    this.startTime = DateTime.now();
    this.result = new AgentErrorMonitorService.ProcessingResult();
    this.isScheduled = isScheduled;
  }

  /**
   * @description Start method of the batch job - queries error records
   * @param bc Batch context provided by the platform
   * @return Iterable of sObjects containing error records to process
   */
  public Iterable<sObject> start(Database.BatchableContext bc) {
    return AgentErrorMonitorService.queryErrorRecords(this.lookbackHours);
  }

  /**
   * @description Execute method of the batch job - processes each batch of records
   * @param bc Batch context provided by the platform
   * @param scope List of sObjects to process in this batch
   */
  public void execute(Database.BatchableContext bc, List<sObject> scope) {
    AgentErrorMonitorService.processRecords(scope, result);
  }

  /**
   * @description Finish method of the batch job - sends email notification with results
   * @param bc Batch context provided by the platform
   */
  public void finish(Database.BatchableContext bc) {
    DateTime endTime = DateTime.now();
    result.durationMilliseconds = endTime.getTime() - startTime.getTime();
    Long durationSeconds = result.durationMilliseconds / 1000;

    if (result.totalRecords > 0) {
      AgentErrorMonitorService.sendErrorNotification(result.errorRecords, recipientEmail, bc.getJobId(), durationSeconds, isScheduled, lookbackHours);
    }
  }
}
