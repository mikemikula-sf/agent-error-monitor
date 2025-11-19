/**
 * Batch class for processing Agent Error records
 * Queries error records, processes them, and sends email notifications
 * Implements Database.Stateful to maintain state across batch executions
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

  public AgentErrorMonitorBatch(String recipientEmail) {
    this(recipientEmail, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS, false);
  }

  public AgentErrorMonitorBatch(String recipientEmail, Integer lookbackHours) {
    this(recipientEmail, lookbackHours, false);
  }

  public AgentErrorMonitorBatch(String recipientEmail, Integer lookbackHours, Boolean isScheduled) {
    AgentErrorMonitorService.validateEmail(recipientEmail);
    AgentErrorMonitorService.validateHoursBack(lookbackHours);

    this.recipientEmail = recipientEmail;
    this.lookbackHours = lookbackHours;
    this.startTime = DateTime.now();
    this.result = new AgentErrorMonitorService.ProcessingResult();
    this.isScheduled = isScheduled;
  }

  public Iterable<sObject> start(Database.BatchableContext bc) {
    return AgentErrorMonitorService.queryErrorRecords(this.lookbackHours);
  }

  public void execute(Database.BatchableContext bc, List<sObject> scope) {
    AgentErrorMonitorService.processRecords(scope, result);
  }

  public void finish(Database.BatchableContext bc) {
    DateTime endTime = DateTime.now();
    result.durationMilliseconds = endTime.getTime() - startTime.getTime();
    Long durationSeconds = result.durationMilliseconds / 1000;

    if (result.totalRecords > 0) {
      AgentErrorMonitorService.sendErrorNotification(result.errorRecords, recipientEmail, bc.getJobId(), durationSeconds, isScheduled, lookbackHours);
    }
  }
}
