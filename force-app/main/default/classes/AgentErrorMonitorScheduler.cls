/**
 * Scheduler class for Agent Error Monitor batch jobs
 * Uses Strategy pattern to support multiple scheduling types (Daily, Hourly, Interval)
 * Handles batch job execution and error notifications
 */
public with sharing class AgentErrorMonitorScheduler implements Schedulable {
  public enum ScheduleType {
    DAILY,
    HOURLY,
    INTERVAL
  }

  public class ScheduleConfig {
    public String cronExpression { get; private set; }
    public String jobName { get; private set; }
    public Integer lookbackHours { get; private set; }

    public ScheduleConfig(String cronExpression, String jobName, Integer lookbackHours) {
      this.cronExpression = cronExpression;
      this.jobName = jobName;
      this.lookbackHours = lookbackHours;
    }
  }

  public interface IScheduleStrategy {
    ScheduleConfig createConfig(Integer param);
    void validate(Integer param);
  }

  public class DailyScheduleStrategy implements IScheduleStrategy {
    public ScheduleConfig createConfig(Integer dailyHour) {
      String cronExp = '0 0 ' + dailyHour + ' * * ?';
      String jobName = 'Agent Error Monitor - Daily ' + dailyHour + ':00';
      Integer lookbackHours = 24;
      return new ScheduleConfig(cronExp, jobName, lookbackHours);
    }

    public void validate(Integer dailyHour) {
      if (dailyHour == null || dailyHour < 0 || dailyHour > 23) {
        throw new IllegalArgumentException('Hour must be between 0 and 23');
      }
    }
  }

  public class HourlyScheduleStrategy implements IScheduleStrategy {
    public ScheduleConfig createConfig(Integer param) {
      String cronExp = '0 0 * * * ?';
      String jobName = 'Agent Error Monitor - Hourly';
      Integer lookbackHours = 1;
      return new ScheduleConfig(cronExp, jobName, lookbackHours);
    }

    public void validate(Integer param) {
    }
  }

  public class IntervalScheduleStrategy implements IScheduleStrategy {
    public ScheduleConfig createConfig(Integer intervalHours) {
      String cronExp = '0 0 0/' + intervalHours + ' * * ?';
      String jobName = 'Agent Error Monitor - Every ' + intervalHours + ' Hours';
      Integer lookbackHours = intervalHours;
      return new ScheduleConfig(cronExp, jobName, lookbackHours);
    }

    public void validate(Integer intervalHours) {
      if (intervalHours == null || intervalHours < 1 || intervalHours > 12) {
        throw new IllegalArgumentException('Interval must be between 1 and 12 hours');
      }
    }
  }

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

  private String recipientEmail;
  private Integer batchSize;
  private Integer lookbackHours;

  public AgentErrorMonitorScheduler(String recipientEmail) {
    this(recipientEmail, AgentErrorMonitorService.DEFAULT_BATCH_SIZE, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS);
  }

  public AgentErrorMonitorScheduler(String recipientEmail, Integer batchSize) {
    this(recipientEmail, batchSize, AgentErrorMonitorService.DEFAULT_LOOKBACK_HOURS);
  }

  public AgentErrorMonitorScheduler(String recipientEmail, Integer batchSize, Integer lookbackHours) {
    AgentErrorMonitorService.validateEmail(recipientEmail);
    AgentErrorMonitorService.validateBatchSize(batchSize, AgentErrorMonitorService.MIN_BATCH_SIZE, AgentErrorMonitorService.MAX_BATCH_SIZE);
    AgentErrorMonitorService.validateHoursBack(lookbackHours);

    this.recipientEmail = recipientEmail;
    this.batchSize = batchSize;
    this.lookbackHours = lookbackHours;
  }

  public void execute(SchedulableContext sc) {
    try {
      AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch(recipientEmail, lookbackHours);
      Database.executeBatch(batch, batchSize);
    } catch (Exception e) {
      AgentErrorMonitorService.logException(e);
      sendErrorNotification(e);
    }
  }

  public static String scheduleDaily(String recipientEmail, Integer hour, Integer batchSize) {
    return schedule(recipientEmail, ScheduleType.DAILY, hour, batchSize);
  }

  public static String scheduleDaily(String recipientEmail, Integer hour) {
    return scheduleDaily(recipientEmail, hour, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  public static String scheduleDaily(String recipientEmail) {
    return scheduleDaily(recipientEmail, 8, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  public static String scheduleHourly(String recipientEmail, Integer batchSize) {
    return schedule(recipientEmail, ScheduleType.HOURLY, null, batchSize);
  }

  public static String scheduleHourly(String recipientEmail) {
    return scheduleHourly(recipientEmail, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  public static String scheduleEveryNHours(String recipientEmail, Integer intervalHours, Integer batchSize) {
    return schedule(recipientEmail, ScheduleType.INTERVAL, intervalHours, batchSize);
  }

  public static String scheduleEveryNHours(String recipientEmail, Integer intervalHours) {
    return scheduleEveryNHours(recipientEmail, intervalHours, AgentErrorMonitorService.DEFAULT_BATCH_SIZE);
  }

  private static ScheduleConfig buildScheduleConfig(ScheduleType scheduleType, Integer param) {
    IScheduleStrategy strategy = getStrategy(scheduleType);
    strategy.validate(param);
    return strategy.createConfig(param);
  }

  public static String schedule(String recipientEmail, ScheduleType scheduleType, Integer param, Integer batchSize, Integer lookbackHours) {
    ScheduleConfig config = buildScheduleConfig(scheduleType, param);

    Integer effectiveLookback = lookbackHours != null ? lookbackHours : config.lookbackHours;

    return System.schedule(config.jobName, config.cronExpression, new AgentErrorMonitorScheduler(recipientEmail, batchSize, effectiveLookback));
  }

  public static String schedule(String recipientEmail, ScheduleType scheduleType, Integer param, Integer batchSize) {
    return schedule(recipientEmail, scheduleType, param, batchSize, null);
  }

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

  public static List<CronTrigger> getScheduledJobs() {
    return [
      SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime, PreviousFireTime
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
      ORDER BY NextFireTime
    ];
  }

  private void sendErrorNotification(Exception e) {
    AgentErrorMonitorService.sendSchedulerErrorNotification(e, recipientEmail);
  }
}
