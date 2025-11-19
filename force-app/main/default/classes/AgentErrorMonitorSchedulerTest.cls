@IsTest(SeeAllData=false)
private class AgentErrorMonitorSchedulerTest {
  @IsTest
  static void testScheduledExecution() {
    String cronExp = '0 0 8 * * ?';

    Test.startTest();

    String jobId = System.schedule('Test Data Cloud Monitor', cronExp, new AgentErrorMonitorScheduler('test@example.com'));

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression, State, NextFireTime
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Scheduled job should exist');
    Assert.areEqual(cronExp, ct.CronExpression, 'Cron expression should match');
  }

  @IsTest
  static void testConstructorValidation() {
    Test.startTest();

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler(null);
      Assert.fail('Should throw IllegalArgumentException for null email');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('required'), 'Should validate email is required');
    }

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('');
      Assert.fail('Should throw IllegalArgumentException for blank email');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('required'), 'Should validate email is required');
    }

    Test.stopTest();
  }

  @IsTest
  static void testScheduleDaily() {
    String email = 'daily@test.com';
    Integer hour = 9;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleDaily(email, hour);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isTrue(ct.CronExpression.contains('0 0 9'), 'Cron expression should run at 9:00');
  }

  @IsTest
  static void testScheduleDailyDefault() {
    String email = 'default@test.com';

    AgentErrorMonitorScheduler.unscheduleAll();

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleDaily(email);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isTrue(ct.CronExpression.contains('0 0 8'), 'Cron expression should run at 8:00 (default)');
  }

  @IsTest
  static void testScheduleHourly() {
    String email = 'hourly@test.com';

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleHourly(email);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.areEqual('0 0 * * * ?', ct.CronExpression, 'Cron expression should run hourly');
  }

  @IsTest
  static void testScheduleEveryNHours() {
    String email = 'interval@test.com';
    Integer intervalHours = 4;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleEveryNHours(email, intervalHours);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isTrue(ct.CronExpression.contains('0/4'), 'Cron expression should run every 4 hours');
  }

  @IsTest
  static void testInvalidHour() {
    String email = 'test@example.com';

    try {
      AgentErrorMonitorScheduler.scheduleDaily(email, 25);
      Assert.fail('Should throw IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Hour must be between'), 'Should validate hour range');
    }
  }

  @IsTest
  static void testInvalidInterval() {
    String email = 'test@example.com';

    try {
      AgentErrorMonitorScheduler.scheduleEveryNHours(email, 15);
      Assert.fail('Should throw IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Interval must be between'), 'Should validate interval range');
    }
  }

  @IsTest
  static void testUnscheduleAll() {
    AgentErrorMonitorScheduler.unscheduleAll();

    AgentErrorMonitorScheduler.scheduleDaily('test1@example.com', 10);
    AgentErrorMonitorScheduler.scheduleHourly('test2@example.com');

    Test.startTest();

    AgentErrorMonitorScheduler.unscheduleAll();

    Test.stopTest();

    List<CronTrigger> remainingJobs = [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
    ];

    Assert.areEqual(0, remainingJobs.size(), 'All scheduled jobs should be removed');
  }

  @IsTest
  static void testGetScheduledJobs() {
    AgentErrorMonitorScheduler.unscheduleAll();

    AgentErrorMonitorScheduler.scheduleDaily('test@example.com');

    Test.startTest();

    List<CronTrigger> jobs = AgentErrorMonitorScheduler.getScheduledJobs();

    Test.stopTest();

    Assert.areEqual(1, jobs.size(), 'Should return one scheduled job');
    Assert.isNotNull(jobs[0].CronExpression, 'Job should have cron expression');
  }

  @IsTest
  static void testExecuteMethod() {
    String cronExp = '0 0 * * * ?';

    Test.startTest();

    String jobId = System.schedule('Test Execute Method', cronExp, new AgentErrorMonitorScheduler('execute@test.com', 100));

    Test.stopTest();

    Assert.isNotNull(jobId, 'Job should be scheduled successfully');
  }

  @IsTest
  static void testCustomBatchSize() {
    Integer customBatchSize = 50;

    Test.startTest();

    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', customBatchSize);
    String jobId = System.schedule('Test Custom Batch Size', '0 0 * * * ?', scheduler);

    Test.stopTest();

    Assert.isNotNull(jobId, 'Job should be scheduled with custom batch size');
  }

  @IsTest
  static void testScheduleDailyWithBatchSize() {
    String email = 'batchsize@test.com';
    Integer hour = 10;
    Integer batchSize = 150;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleDaily(email, hour, batchSize);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled with custom batch size');
    Assert.isTrue(ct.CronExpression.contains('0 0 10'), 'Cron expression should run at 10:00');
  }

  @IsTest
  static void testScheduleHourlyWithBatchSize() {
    String email = 'hourly-batch@test.com';
    Integer batchSize = 100;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleHourly(email, batchSize);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled hourly with custom batch size');
    Assert.areEqual('0 0 * * * ?', ct.CronExpression, 'Cron expression should run hourly');
  }

  @IsTest
  static void testScheduleEveryNHoursWithBatchSize() {
    String email = 'interval-batch@test.com';
    Integer intervalHours = 6;
    Integer batchSize = 250;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.scheduleEveryNHours(email, intervalHours, batchSize);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled with custom batch size');
    Assert.isTrue(ct.CronExpression.contains('0/6'), 'Cron expression should run every 6 hours');
  }

  @IsTest
  static void testUnifiedScheduleDaily() {
    String email = 'unified-daily@test.com';
    Integer dailyHour = 9;
    Integer batchSize = 150;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.schedule(email, AgentErrorMonitorScheduler.ScheduleType.DAILY, dailyHour, batchSize, null);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled');
    Assert.isTrue(ct.CronExpression.contains('0 0 9'), 'Should run at 9:00');
  }

  @IsTest
  static void testUnifiedScheduleHourly() {
    String email = 'unified-hourly@test.com';
    Integer batchSize = 100;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.schedule(email, AgentErrorMonitorScheduler.ScheduleType.HOURLY, null, batchSize, null);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled');
    Assert.areEqual('0 0 * * * ?', ct.CronExpression, 'Should run hourly');
  }

  @IsTest
  static void testUnifiedScheduleInterval() {
    String email = 'unified-interval@test.com';
    Integer intervalHours = 4;
    Integer batchSize = 200;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.schedule(email, AgentErrorMonitorScheduler.ScheduleType.INTERVAL, intervalHours, batchSize, null);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled');
    Assert.isTrue(ct.CronExpression.contains('0/4'), 'Should run every 4 hours');
  }

  @IsTest
  static void testUnifiedScheduleInvalidType() {
    String email = 'invalid@test.com';
    Integer batchSize = 200;

    Test.startTest();

    try {
      String jobId = AgentErrorMonitorScheduler.schedule(email, null, null, null, batchSize);
      Assert.fail('Should throw IllegalArgumentException for invalid schedule type');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Invalid scheduleType'), 'Should validate schedule type: ' + e.getMessage());
    }

    Test.stopTest();
  }

  @IsTest
  static void testConstructorWithBatchSizeValidation() {
    Test.startTest();

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler(null, 100);
      Assert.fail('Should throw IllegalArgumentException for null email');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('required'), 'Should validate email is required');
    }

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('', 100);
      Assert.fail('Should throw IllegalArgumentException for blank email');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('required'), 'Should validate email is required');
    }

    AgentErrorMonitorScheduler validScheduler = new AgentErrorMonitorScheduler('test@example.com', 150);
    Assert.isNotNull(validScheduler, 'Valid scheduler should be created');

    Test.stopTest();
  }

  @IsTest
  static void testSchedulerExecuteDirect() {
    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 100);

    Test.startTest();
    scheduler.execute(null);
    Test.stopTest();

    // Verify that execute() method completes without throwing exceptions
    // The batch job is queued asynchronously, so we can't verify the batch execution here
    // This is covered by other integration tests that use System.schedule()
    Assert.isNotNull(scheduler, 'Scheduler should remain valid after execution');
  }

  @IsTest
  static void testConstructorInvalidBatchSize() {
    Test.startTest();

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 0);
      Assert.fail('Should throw IllegalArgumentException for batch size too small');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Batch size must be between'), 'Should validate batch size range');
    }

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 3000);
      Assert.fail('Should throw IllegalArgumentException for batch size too large');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Batch size must be between'), 'Should validate batch size range');
    }

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', null);
      Assert.fail('Should throw IllegalArgumentException for null batch size');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Batch size must be between'), 'Should validate batch size range');
    }

    Test.stopTest();
  }

  @IsTest
  static void testConstructorWithLookbackHours() {
    Integer batchSize = 100;
    Integer lookbackHours = 48;

    Test.startTest();

    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', batchSize, lookbackHours);
    String jobId = System.schedule('Test Lookback Hours', '0 0 * * * ?', scheduler);

    Test.stopTest();

    Assert.isNotNull(jobId, 'Job should be scheduled with custom lookback hours');
  }

  @IsTest
  static void testConstructorInvalidLookbackHours() {
    Test.startTest();

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 100, 0);
      Assert.fail('Should throw IllegalArgumentException for lookback hours too small');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('hoursBack must be between'), 'Should validate lookback hours');
    }

    try {
      AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 100, null);
      Assert.fail('Should throw IllegalArgumentException for null lookback hours');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('hoursBack must be between'), 'Should validate lookback hours');
    }

    Test.stopTest();
  }

  @IsTest
  static void testUnifiedScheduleWithLookbackHours() {
    String email = 'lookback@test.com';
    Integer dailyHour = 10;
    Integer batchSize = 150;
    Integer lookbackHours = 72;

    Test.startTest();

    String jobId = AgentErrorMonitorScheduler.schedule(email, AgentErrorMonitorScheduler.ScheduleType.DAILY, dailyHour, batchSize, lookbackHours);

    Test.stopTest();

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled with custom lookback hours');
    Assert.isTrue(ct.CronExpression.contains('0 0 10'), 'Should run at 10:00');
  }
}
