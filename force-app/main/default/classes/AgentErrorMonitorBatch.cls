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

  public AgentErrorMonitorBatch(String recipientEmail) {
    this(recipientEmail, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS);
  }

  public AgentErrorMonitorBatch(String recipientEmail, Integer lookbackHours) {
    AgentErrorMonitorService.validateEmail(recipientEmail);
    AgentErrorMonitorService.validateHoursBack(lookbackHours);

    this.recipientEmail = recipientEmail;
    this.lookbackHours = lookbackHours;
    this.startTime = DateTime.now();
    this.result = new AgentErrorMonitorService.ProcessingResult();
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

    if (result.errorCount > 0) {
      AgentErrorMonitorService.sendErrorNotification(result.errorRecords, recipientEmail, bc.getJobId(), durationSeconds);
    }
  }
}
