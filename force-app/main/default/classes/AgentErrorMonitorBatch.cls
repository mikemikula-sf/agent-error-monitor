/**
 * @description Batch job to monitor AI Agent errors and send email notifications
 *              when errors are detected in agent interactions.
 *              Uses AgentErrorMonitorService for business logic.
 *
 * Usage:
 *   AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch('admin@example.com');
 *   Database.executeBatch(batch, 200);
 */
public with sharing class AgentErrorMonitorBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
  private static final Integer DEFAULT_LOOKBACK_HOURS = 24;

  @TestVisible
  private String recipientEmail;
  @TestVisible
  private DateTime startTime;
  @TestVisible
  private AgentErrorMonitorService.ProcessingResult result;

  public AgentErrorMonitorBatch(String recipientEmail) {
    if (String.isBlank(recipientEmail)) {
      throw new IllegalArgumentException('Recipient email is required');
    }
    this.recipientEmail = recipientEmail;
    this.startTime = DateTime.now();
    this.result = new AgentErrorMonitorService.ProcessingResult();
  }

  public Iterable<sObject> start(Database.BatchableContext bc) {
    return AgentErrorMonitorService.queryErrorRecords(DEFAULT_LOOKBACK_HOURS);
  }

  public void execute(Database.BatchableContext bc, List<sObject> scope) {
    try {
      AgentErrorMonitorService.processRecords(scope, result);
    } catch (Exception e) {
      AgentErrorMonitorService.logException(e);
    }
  }

  public void finish(Database.BatchableContext bc) {
    DateTime endTime = DateTime.now();
    result.durationMilliseconds = endTime.getTime() - startTime.getTime();
    Long durationSeconds = result.durationMilliseconds / 1000;

    if (result.errorCount > 0) {
      AgentErrorMonitorService.sendErrorNotification(
        result.errorRecords,
        recipientEmail,
        bc.getJobId(),
        durationSeconds
      );
    }
  }
}

