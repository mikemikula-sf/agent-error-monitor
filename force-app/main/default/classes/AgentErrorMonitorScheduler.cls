/**
 * @description Scheduler class for Agent Error Monitor batch jobs.
 * Uses Strategy pattern to support multiple scheduling types (Daily, Hourly, Interval).
 * Handles batch job execution and error notifications.
 */
public with sharing class AgentErrorMonitorScheduler implements Schedulable {
  // Instance fields
  private String recipientEmail;
  private Integer batchSize;
  private Integer lookbackHours;

  /**
   * @description Enum defining the types of schedules supported
   */
  public enum ScheduleType {
    DAILY,
    HOURLY,
    INTERVAL
  }

  /**
   * @description Configuration class containing schedule details
   */
  public class ScheduleConfig {
    /** @description Cron expression for the schedule */
    public String cronExpression { get; private set; }
    /** @description Name of the scheduled job */
    public String jobName { get; private set; }
    /** @description Number of hours to look back for errors */
    public Integer lookbackHours { get; private set; }

    /**
     * @description Constructor for ScheduleConfig
     * @param cronExpression Cron expression for the schedule
     * @param jobName Name of the scheduled job
     * @param lookbackHours Number of hours to look back for errors
     */
    public ScheduleConfig(String cronExpression, String jobName, Integer lookbackHours) {
      this.cronExpression = cronExpression;
      this.jobName = jobName;
      this.lookbackHours = lookbackHours;
    }
  }

  /**
   * @description Strategy interface for creating schedule configurations
   */
  public interface IScheduleStrategy {
    /**
     * @description Creates a schedule configuration with validation
     * @param param Schedule-specific parameter (hour for daily, interval for interval)
     * @return ScheduleConfig containing cron expression and job details
     */
    ScheduleConfig createConfig(Integer param);
  }

  /**
   * @description Strategy for daily schedules at a specific hour
   */
  public class DailyScheduleStrategy implements IScheduleStrategy {
    /**
     * @description Creates daily schedule configuration with validation
     * @param dailyHour Hour of day (0-23) to run the job
     * @return ScheduleConfig for daily execution
     */
    public ScheduleConfig createConfig(Integer dailyHour) {
      if (dailyHour == null || dailyHour < 0 || dailyHour > 23) {
        throw new IllegalArgumentException('Hour must be between 0 and 23');
      }
      String cronExp = '0 0 ' + dailyHour + ' * * ?';
      String jobName = 'Agent Error Monitor - Daily ' + dailyHour + ':00';
      Integer lookbackHours = 24;
      return new ScheduleConfig(cronExp, jobName, lookbackHours);
    }
  }

  /**
   * @description Strategy for hourly schedules
   */
  public class HourlyScheduleStrategy implements IScheduleStrategy {
    /**
     * @description Creates hourly schedule configuration
     * @param param Not used for hourly schedules
     * @return ScheduleConfig for hourly execution
     */
    public ScheduleConfig createConfig(Integer param) {
      String cronExp = '0 0 * * * ?';
      String jobName = 'Agent Error Monitor - Hourly';
      Integer lookbackHours = 1;
      return new ScheduleConfig(cronExp, jobName, lookbackHours);
    }
  }

  /**
   * @description Strategy for interval-based schedules
   */
  public class IntervalScheduleStrategy implements IScheduleStrategy {
    /**
     * @description Creates interval schedule configuration with validation
     * @param intervalHours Number of hours between executions (1-12)
     * @return ScheduleConfig for interval execution
     */
    public ScheduleConfig createConfig(Integer intervalHours) {
      if (intervalHours == null || intervalHours < 1 || intervalHours > 12) {
        throw new IllegalArgumentException('Interval must be between 1 and 12 hours');
      }
      String cronExp = '0 0 0/' + intervalHours + ' * * ?';
      String jobName = 'Agent Error Monitor - Every ' + intervalHours + ' Hours';
      Integer lookbackHours = intervalHours;
      return new ScheduleConfig(cronExp, jobName, lookbackHours);
    }
  }

  /**
   * @description Gets the appropriate strategy for the given schedule type
   * @param scheduleType Type of schedule (DAILY, HOURLY, or INTERVAL)
   * @return IScheduleStrategy implementation for the schedule type
   */
  private static IScheduleStrategy getStrategy(ScheduleType scheduleType) {
    switch on scheduleType {
      when DAILY {
        return new DailyScheduleStrategy();
      }
      when HOURLY {
        return new HourlyScheduleStrategy();
      }
      when INTERVAL {
        return new IntervalScheduleStrategy();
      }
      when else {
        throw new IllegalArgumentException('Invalid scheduleType: ' + scheduleType);
      }
    }
  }

  /**
   * @description Constructor with default batch size and lookback hours
   * @param recipientEmail Email address to send error notifications to
   */
  public AgentErrorMonitorScheduler(String recipientEmail) {
    this(recipientEmail, AgentErrorMonitorService.DEFAULT_BATCH_SIZE, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS);
  }

  /**
   * @description Constructor with custom batch size and default lookback hours
   * @param recipientEmail Email address to send error notifications to
   * @param batchSize Number of records to process per batch
   */
  public AgentErrorMonitorScheduler(String recipientEmail, Integer batchSize) {
    this(recipientEmail, batchSize, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS);
  }

  /**
   * @description Full constructor with all parameters
   * @param recipientEmail Email address to send error notifications to
   * @param batchSize Number of records to process per batch
   * @param lookbackHours Number of hours to look back for errors
   */
  public AgentErrorMonitorScheduler(String recipientEmail, Integer batchSize, Integer lookbackHours) {
    AgentErrorMonitorService.validateEmail(recipientEmail);
    AgentErrorMonitorService.validateBatchSize(batchSize, AgentErrorMonitorService.MIN_BATCH_SIZE, AgentErrorMonitorService.MAX_BATCH_SIZE);
    AgentErrorMonitorService.validateHoursBack(lookbackHours);

    this.recipientEmail = recipientEmail;
    this.batchSize = batchSize;
    this.lookbackHours = lookbackHours;
  }

  /**
   * @description Executes the scheduled job by starting the batch process
   * @param sc Schedulable context provided by the platform
   */
  public void execute(SchedulableContext sc) {
    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch(recipientEmail, lookbackHours, true);
      Database.executeBatch(batch, batchSize);
    } catch (Exception e) {
      AgentErrorMonitorService.logException(e);
      sendErrorNotification(e);
    }
  }

  /**
   * @description Schedules a daily job at a specific hour with custom batch size
   * @param recipientEmail Email address to send error notifications to
   * @param hour Hour of day (0-23) to run the job
   * @param batchSize Number of records to process per batch
   * @return Job ID of the scheduled job
   */
  public static String scheduleDaily(String recipientEmail, Integer hour, Integer batchSize) {
    return schedule(recipientEmail, ScheduleType.DAILY, hour, batchSize);
  }

  /**
   * @description Schedules a daily job at a specific hour with default batch size
   * @param recipientEmail Email address to send error notifications to
   * @param hour Hour of day (0-23) to run the job
   * @return Job ID of the scheduled job
   */
  public static String scheduleDaily(String recipientEmail, Integer hour) {
    return scheduleDaily(recipientEmail, hour, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Schedules a daily job at 8 AM with default batch size
   * @param recipientEmail Email address to send error notifications to
   * @return Job ID of the scheduled job
   */
  public static String scheduleDaily(String recipientEmail) {
    return scheduleDaily(recipientEmail, 8, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Schedules an hourly job with custom batch size
   * @param recipientEmail Email address to send error notifications to
   * @param batchSize Number of records to process per batch
   * @return Job ID of the scheduled job
   */
  public static String scheduleHourly(String recipientEmail, Integer batchSize) {
    return schedule(recipientEmail, ScheduleType.HOURLY, null, batchSize);
  }

  /**
   * @description Schedules an hourly job with default batch size
   * @param recipientEmail Email address to send error notifications to
   * @return Job ID of the scheduled job
   */
  public static String scheduleHourly(String recipientEmail) {
    return scheduleHourly(recipientEmail, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Schedules a job to run every N hours with custom batch size
   * @param recipientEmail Email address to send error notifications to
   * @param intervalHours Number of hours between executions (1-12)
   * @param batchSize Number of records to process per batch
   * @return Job ID of the scheduled job
   */
  public static String scheduleEveryNHours(String recipientEmail, Integer intervalHours, Integer batchSize) {
    return schedule(recipientEmail, ScheduleType.INTERVAL, intervalHours, batchSize);
  }

  /**
   * @description Schedules a job to run every N hours with default batch size
   * @param recipientEmail Email address to send error notifications to
   * @param intervalHours Number of hours between executions (1-12)
   * @return Job ID of the scheduled job
   */
  public static String scheduleEveryNHours(String recipientEmail, Integer intervalHours) {
    return scheduleEveryNHours(recipientEmail, intervalHours, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  /**
   * @description Builds schedule configuration using the appropriate strategy
   * @param scheduleType Type of schedule (DAILY, HOURLY, or INTERVAL)
   * @param param Schedule-specific parameter (hour for daily, interval for interval)
   * @return ScheduleConfig containing cron expression and job details
   */
  private static ScheduleConfig buildScheduleConfig(ScheduleType scheduleType, Integer param) {
    IScheduleStrategy strategy = getStrategy(scheduleType);
    return strategy.createConfig(param);
  }

  /**
   * @description Schedules a job with full configuration options
   * @param recipientEmail Email address to send error notifications to
   * @param scheduleType Type of schedule (DAILY, HOURLY, or INTERVAL)
   * @param param Schedule-specific parameter (hour for daily, interval for interval)
   * @param batchSize Number of records to process per batch
   * @param lookbackHours Number of hours to look back for errors (null uses schedule default)
   * @return Job ID of the scheduled job
   */
  public static String schedule(String recipientEmail, ScheduleType scheduleType, Integer param, Integer batchSize, Integer lookbackHours) {
    ScheduleConfig config = buildScheduleConfig(scheduleType, param);

    Integer effectiveLookback = lookbackHours != null ? lookbackHours : config.lookbackHours;

    return System.schedule(config.jobName, config.cronExpression, new AgentErrorMonitorScheduler(recipientEmail, batchSize, effectiveLookback));
  }

  /**
   * @description Schedules a job with default lookback hours
   * @param recipientEmail Email address to send error notifications to
   * @param scheduleType Type of schedule (DAILY, HOURLY, or INTERVAL)
   * @param param Schedule-specific parameter (hour for daily, interval for interval)
   * @param batchSize Number of records to process per batch
   * @return Job ID of the scheduled job
   */
  public static String schedule(String recipientEmail, ScheduleType scheduleType, Integer param, Integer batchSize) {
    return schedule(recipientEmail, scheduleType, param, batchSize, null);
  }

  /**
   * @description Unschedules all Agent Error Monitor jobs
   */
  public static void unscheduleAll() {
    List<CronTrigger> scheduledJobs = [
      SELECT Id, CronJobDetail.Name
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
      WITH USER_MODE
    ];

    for (CronTrigger job : scheduledJobs) {
      System.abortJob(job.Id);
    }
  }

  /**
   * @description Gets all scheduled Agent Error Monitor jobs
   * @return List of CronTrigger records for Agent Error Monitor jobs
   */
  public static List<CronTrigger> getScheduledJobs() {
    return [
      SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime, PreviousFireTime
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
      WITH USER_MODE
      ORDER BY NextFireTime
    ];
  }

  /**
   * @description Sends error notification when scheduler execution fails
   * @param e Exception that occurred during scheduler execution
   */
  private void sendErrorNotification(Exception e) {
    AgentErrorMonitorService.sendSchedulerErrorNotification(e, recipientEmail);
  }
}
