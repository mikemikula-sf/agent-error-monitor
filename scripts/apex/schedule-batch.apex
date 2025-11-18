/**
 * @description Flexible scheduler for Agent Error Monitor batch job
 *              Supports daily, hourly, or custom interval scheduling
 *
 * IMPORTANT: Update the configuration below before running!
 */

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIGURATION - Update these values
// ═══════════════════════════════════════════════════════════════════════════════

String recipientEmail = 'your-email@example.com'; // TODO: Update this email address
Integer batchSize = 200; // Number of records to process per batch

// Schedule Type: DAILY, HOURLY, or INTERVAL
AgentErrorMonitorScheduler.ScheduleType scheduleType = AgentErrorMonitorScheduler.ScheduleType.DAILY;

// For DAILY: Hour of day to run (0-23)
Integer dailyHour = 8;

// For INTERVAL: Number of hours between runs (1-12)
Integer intervalHours = 4;

// ═══════════════════════════════════════════════════════════════════════════════
// EXECUTION - Do not modify below this line
// ═══════════════════════════════════════════════════════════════════════════════

// First, unschedule any existing jobs to avoid duplicates
AgentErrorMonitorScheduler.unscheduleAll();
System.debug('Unscheduled all existing Agent Error Monitor jobs');

// Schedule using unified method
String jobId = AgentErrorMonitorScheduler.schedule(
  recipientEmail,
  scheduleType,
  dailyHour,
  intervalHours,
  batchSize
);

// Build description for display
String scheduleDescription;
switch on scheduleType {
  when DAILY {
    scheduleDescription = 'Daily at ' + dailyHour + ':00';
  }
  when HOURLY {
    scheduleDescription = 'Every hour';
  }
  when INTERVAL {
    scheduleDescription = 'Every ' + intervalHours + ' hours';
  }
}

// Display results
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('✓ Batch job scheduled successfully');
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('Job ID: ' + jobId);
System.debug('Schedule: ' + scheduleDescription);
System.debug('Batch Size: ' + batchSize);
System.debug('Email Recipient: ' + recipientEmail);
System.debug('═══════════════════════════════════════════════════════════════');

// Verify the scheduled job
List<CronTrigger> scheduledJobs = AgentErrorMonitorScheduler.getScheduledJobs();
System.debug('\nCurrently scheduled jobs: ' + scheduledJobs.size());
for (CronTrigger job : scheduledJobs) {
  System.debug('  • Job: ' + job.CronJobDetail.Name);
  System.debug('    Next Run: ' + job.NextFireTime);
  System.debug('    Cron Expression: ' + job.CronExpression);
  System.debug('    State: ' + job.State);
}

