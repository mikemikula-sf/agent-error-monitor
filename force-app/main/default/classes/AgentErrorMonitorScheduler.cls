/**
 * @description Schedulable class to run AgentErrorMonitorBatch on a recurring schedule
 *
 * Usage Examples:
 *
 * // Schedule to run daily at 8 AM
 * String cronExp = '0 0 8 * * ?';
 * String jobName = 'Agent Error Monitor - Daily';
 * System.schedule(jobName, cronExp, new AgentErrorMonitorScheduler('admin@example.com'));
 *
 * // Programmatic scheduling using helper method
 * AgentErrorMonitorScheduler.scheduleDaily('admin@example.com');
 */
public with sharing class AgentErrorMonitorScheduler implements Schedulable {
  /**
   * @description Enum for schedule types
   */
  public enum ScheduleType {
    DAILY,
    HOURLY,
    INTERVAL
  }

  private String recipientEmail;
  private Integer batchSize;

  private static final Integer DEFAULT_BATCH_SIZE = 200;

  public AgentErrorMonitorScheduler(String recipientEmail) {
    if (String.isBlank(recipientEmail)) {
      throw new IllegalArgumentException('Recipient email is required');
    }
    this.recipientEmail = recipientEmail;
    this.batchSize = DEFAULT_BATCH_SIZE;
  }

  public AgentErrorMonitorScheduler(String recipientEmail, Integer batchSize) {
    if (String.isBlank(recipientEmail)) {
      throw new IllegalArgumentException('Recipient email is required');
    }
    this.recipientEmail = recipientEmail;
    this.batchSize = batchSize;
  }

  public void execute(SchedulableContext sc) {
    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch(recipientEmail);
      Database.executeBatch(batch, batchSize);
    } catch (Exception e) {
      AgentErrorMonitorService.logException(e);
      sendErrorNotification(e);
    }
  }

  /**
   * @description Helper method to schedule the job to run daily at specified hour with custom batch size
   * @param recipientEmail Email address for notifications
   * @param hour Hour of day (0-23) to run the job
   * @param batchSize Batch size for processing
   * @return String Scheduled job ID
   */
  public static String scheduleDaily(String recipientEmail, Integer hour, Integer batchSize) {
    if (hour < 0 || hour > 23) {
      throw new IllegalArgumentException('Hour must be between 0 and 23');
    }

    String cronExp = '0 0 ' + hour + ' * * ?';
    String jobName = 'Agent Error Monitor - Daily ' + hour + ':00';

    return System.schedule(jobName, cronExp, new AgentErrorMonitorScheduler(recipientEmail, batchSize));
  }

  /**
   * @description Helper method to schedule the job to run daily at specified hour
   * @param recipientEmail Email address for notifications
   * @param hour Hour of day (0-23) to run the job
   * @return String Scheduled job ID
   */
  public static String scheduleDaily(String recipientEmail, Integer hour) {
    return scheduleDaily(recipientEmail, hour, DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Helper method to schedule the job to run daily at 8 AM
   * @param recipientEmail Email address for notifications
   * @return String Scheduled job ID
   */
  public static String scheduleDaily(String recipientEmail) {
    return scheduleDaily(recipientEmail, 8, DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Helper method to schedule the job to run hourly with custom batch size
   * @param recipientEmail Email address for notifications
   * @param batchSize Batch size for processing
   * @return String Scheduled job ID
   */
  public static String scheduleHourly(String recipientEmail, Integer batchSize) {
    String cronExp = '0 0 * * * ?';
    String jobName = 'Agent Error Monitor - Hourly';

    return System.schedule(jobName, cronExp, new AgentErrorMonitorScheduler(recipientEmail, batchSize));
  }

  /**
   * @description Helper method to schedule the job to run hourly
   * @param recipientEmail Email address for notifications
   * @return String Scheduled job ID
   */
  public static String scheduleHourly(String recipientEmail) {
    return scheduleHourly(recipientEmail, DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Helper method to schedule the job to run every N hours with custom batch size
   * @param recipientEmail Email address for notifications
   * @param intervalHours Interval in hours (1-12)
   * @param batchSize Batch size for processing
   * @return String Scheduled job ID
   */
  public static String scheduleEveryNHours(String recipientEmail, Integer intervalHours, Integer batchSize) {
    if (intervalHours < 1 || intervalHours > 12) {
      throw new IllegalArgumentException('Interval must be between 1 and 12 hours');
    }

    String cronExp = '0 0 0/' + intervalHours + ' * * ?';
    String jobName = 'Agent Error Monitor - Every ' + intervalHours + ' Hours';

    return System.schedule(jobName, cronExp, new AgentErrorMonitorScheduler(recipientEmail, batchSize));
  }

  /**
   * @description Helper method to schedule the job to run every N hours
   * @param recipientEmail Email address for notifications
   * @param intervalHours Interval in hours (1-12)
   * @return String Scheduled job ID
   */
  public static String scheduleEveryNHours(String recipientEmail, Integer intervalHours) {
    return scheduleEveryNHours(recipientEmail, intervalHours, DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Unified scheduling method that handles all schedule types
   * @param recipientEmail Email address for notifications
   * @param scheduleType Type of schedule (DAILY, HOURLY, or INTERVAL)
   * @param dailyHour Hour of day for DAILY schedule (0-23)
   * @param intervalHours Hours between runs for INTERVAL schedule (1-12)
   * @param batchSize Batch size for processing
   * @return String Scheduled job ID
   */
  public static String schedule(
    String recipientEmail,
    ScheduleType scheduleType,
    Integer dailyHour,
    Integer intervalHours,
    Integer batchSize
  ) {
    switch on scheduleType {
      when DAILY {
        return scheduleDaily(recipientEmail, dailyHour, batchSize);
      }
      when HOURLY {
        return scheduleHourly(recipientEmail, batchSize);
      }
      when INTERVAL {
        return scheduleEveryNHours(recipientEmail, intervalHours, batchSize);
      }
      when else {
        throw new IllegalArgumentException('Invalid scheduleType: ' + scheduleType);
      }
    }
  }

  /**
   * @description Unschedules all Agent Error Monitor jobs
   */
  public static void unscheduleAll() {
    List<CronTrigger> scheduledJobs = [
      SELECT Id, CronJobDetail.Name
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
    ];

    for (CronTrigger job : scheduledJobs) {
      System.abortJob(job.Id);
    }
  }

  /**
   * @description Gets list of currently scheduled jobs
   * @return List<CronTrigger> List of scheduled jobs
   */
  public static List<CronTrigger> getScheduledJobs() {
    return [
      SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime, PreviousFireTime
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
      ORDER BY NextFireTime
    ];
  }

  /**
   * @description Sends error notification email when scheduler fails
   * @param e Exception that occurred
   */
  private void sendErrorNotification(Exception e) {
    AgentErrorMonitorService.sendSchedulerErrorNotification(e, recipientEmail);
  }
}

