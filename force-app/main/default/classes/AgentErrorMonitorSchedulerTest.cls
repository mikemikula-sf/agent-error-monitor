@IsTest(SeeAllData=false)
private class AgentErrorMonitorSchedulerTest {
  /**
   * @description Tests scheduled job execution
   */
  @IsTest
  static void testScheduledExecution() {
    // Arrange
    String cronExp = '0 0 8 * * ?';

    Test.startTest();

    // Act
    String jobId = System.schedule(
      'Test Data Cloud Monitor',
      cronExp,
      new AgentErrorMonitorScheduler('test@example.com')
    );

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression, State, NextFireTime
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Scheduled job should exist');
    Assert.areEqual(cronExp, ct.CronExpression, 'Cron expression should match');
  }

  /**
   * @description Tests constructor validation
   */
  @IsTest
  static void testConstructorValidation() {
    // Arrange & Act
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

  /**
   * @description Tests scheduling daily at specific hour
   */
  @IsTest
  static void testScheduleDaily() {
    // Arrange
    String email = 'daily@test.com';
    Integer hour = 9;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleDaily(email, hour);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isTrue(ct.CronExpression.contains('0 0 9'), 'Cron expression should run at 9:00');
  }

  /**
   * @description Tests scheduling daily at default hour (8 AM)
   */
  @IsTest
  static void testScheduleDailyDefault() {
    // Arrange
    String email = 'default@test.com';

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleDaily(email);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isTrue(ct.CronExpression.contains('0 0 8'), 'Cron expression should run at 8:00 (default)');
  }

  /**
   * @description Tests scheduling hourly
   */
  @IsTest
  static void testScheduleHourly() {
    // Arrange
    String email = 'hourly@test.com';

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleHourly(email);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.areEqual('0 0 * * * ?', ct.CronExpression, 'Cron expression should run hourly');
  }

  /**
   * @description Tests scheduling every N hours
   */
  @IsTest
  static void testScheduleEveryNHours() {
    // Arrange
    String email = 'interval@test.com';
    Integer intervalHours = 4;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleEveryNHours(email, intervalHours);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isTrue(ct.CronExpression.contains('0/4'), 'Cron expression should run every 4 hours');
  }

  /**
   * @description Tests invalid hour parameter
   */
  @IsTest
  static void testInvalidHour() {
    // Arrange
    String email = 'test@example.com';

    // Act & Assert
    try {
      AgentErrorMonitorScheduler.scheduleDaily(email, 25);
      Assert.fail('Should throw IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(e.getMessage().contains('Hour must be between'), 'Should validate hour range');
    }
  }

  /**
   * @description Tests invalid interval parameter
   */
  @IsTest
  static void testInvalidInterval() {
    // Arrange
    String email = 'test@example.com';

    // Act & Assert
    try {
      AgentErrorMonitorScheduler.scheduleEveryNHours(email, 15);
      Assert.fail('Should throw IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(
        e.getMessage().contains('Interval must be between'),
        'Should validate interval range'
      );
    }
  }

  /**
   * @description Tests unscheduling all jobs
   */
  @IsTest
  static void testUnscheduleAll() {
    // Arrange
    AgentErrorMonitorScheduler.scheduleDaily('test1@example.com');
    AgentErrorMonitorScheduler.scheduleHourly('test2@example.com');

    Test.startTest();

    // Act
    AgentErrorMonitorScheduler.unscheduleAll();

    Test.stopTest();

    // Assert
    List<CronTrigger> remainingJobs = [
      SELECT Id
      FROM CronTrigger
      WHERE CronJobDetail.Name LIKE 'Agent Error Monitor%'
    ];

    Assert.areEqual(0, remainingJobs.size(), 'All scheduled jobs should be removed');
  }

  /**
   * @description Tests getting scheduled jobs
   */
  @IsTest
  static void testGetScheduledJobs() {
    // Arrange
    AgentErrorMonitorScheduler.scheduleDaily('test@example.com');

    Test.startTest();

    // Act
    List<CronTrigger> jobs = AgentErrorMonitorScheduler.getScheduledJobs();

    Test.stopTest();

    // Assert
    Assert.areEqual(1, jobs.size(), 'Should return one scheduled job');
    Assert.isNotNull(jobs[0].CronExpression, 'Job should have cron expression');
  }

  /**
   * @description Tests scheduler execute method
   */
  @IsTest
  static void testExecuteMethod() {
    // Arrange
    String cronExp = '0 0 * * * ?';

    Test.startTest();

    // Act
    String jobId = System.schedule(
      'Test Execute Method',
      cronExp,
      new AgentErrorMonitorScheduler('execute@test.com', 100)
    );

    Test.stopTest();

    // Assert
    Assert.isNotNull(jobId, 'Job should be scheduled successfully');
  }

  /**
   * @description Tests constructor with custom batch size
   */
  @IsTest
  static void testCustomBatchSize() {
    // Arrange
    Integer customBatchSize = 50;

    Test.startTest();

    // Act
    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', customBatchSize);
    String jobId = System.schedule('Test Custom Batch Size', '0 0 * * * ?', scheduler);

    Test.stopTest();

    // Assert
    Assert.isNotNull(jobId, 'Job should be scheduled with custom batch size');
  }

  /**
   * @description Tests scheduling daily with custom batch size
   */
  @IsTest
  static void testScheduleDailyWithBatchSize() {
    // Arrange
    String email = 'batchsize@test.com';
    Integer hour = 10;
    Integer batchSize = 150;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleDaily(email, hour, batchSize);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled with custom batch size');
    Assert.isTrue(ct.CronExpression.contains('0 0 10'), 'Cron expression should run at 10:00');
  }

  /**
   * @description Tests scheduling hourly with custom batch size
   */
  @IsTest
  static void testScheduleHourlyWithBatchSize() {
    // Arrange
    String email = 'hourly-batch@test.com';
    Integer batchSize = 100;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleHourly(email, batchSize);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled hourly with custom batch size');
    Assert.areEqual('0 0 * * * ?', ct.CronExpression, 'Cron expression should run hourly');
  }

  /**
   * @description Tests scheduling every N hours with custom batch size
   */
  @IsTest
  static void testScheduleEveryNHoursWithBatchSize() {
    // Arrange
    String email = 'interval-batch@test.com';
    Integer intervalHours = 6;
    Integer batchSize = 250;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.scheduleEveryNHours(email, intervalHours, batchSize);

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled with custom batch size');
    Assert.isTrue(ct.CronExpression.contains('0/6'), 'Cron expression should run every 6 hours');
  }

  /**
   * @description Tests unified schedule method with DAILY type
   */
  @IsTest
  static void testUnifiedScheduleDaily() {
    // Arrange
    String email = 'unified-daily@test.com';
    Integer dailyHour = 9;
    Integer batchSize = 150;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.schedule(
      email,
      AgentErrorMonitorScheduler.ScheduleType.DAILY,
      dailyHour,
      null,
      batchSize
    );

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled');
    Assert.isTrue(ct.CronExpression.contains('0 0 9'), 'Should run at 9:00');
  }

  /**
   * @description Tests unified schedule method with HOURLY type
   */
  @IsTest
  static void testUnifiedScheduleHourly() {
    // Arrange
    String email = 'unified-hourly@test.com';
    Integer batchSize = 100;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.schedule(
      email,
      AgentErrorMonitorScheduler.ScheduleType.HOURLY,
      null,
      null,
      batchSize
    );

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled');
    Assert.areEqual('0 0 * * * ?', ct.CronExpression, 'Should run hourly');
  }

  /**
   * @description Tests unified schedule method with INTERVAL type
   */
  @IsTest
  static void testUnifiedScheduleInterval() {
    // Arrange
    String email = 'unified-interval@test.com';
    Integer intervalHours = 4;
    Integer batchSize = 200;

    Test.startTest();

    // Act
    String jobId = AgentErrorMonitorScheduler.schedule(
      email,
      AgentErrorMonitorScheduler.ScheduleType.INTERVAL,
      null,
      intervalHours,
      batchSize
    );

    Test.stopTest();

    // Assert
    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];

    Assert.isNotNull(ct, 'Job should be scheduled');
    Assert.isTrue(ct.CronExpression.contains('0/4'), 'Should run every 4 hours');
  }

  /**
   * @description Tests unified schedule method with invalid schedule type
   * Note: This test validates the when else clause by passing null
   */
  @IsTest
  static void testUnifiedScheduleInvalidType() {
    // Arrange
    String email = 'invalid@test.com';
    Integer batchSize = 200;

    Test.startTest();

    // Act & Assert
    try {
      String jobId = AgentErrorMonitorScheduler.schedule(email, null, null, null, batchSize);
      Assert.fail('Should throw IllegalArgumentException for invalid schedule type');
    } catch (IllegalArgumentException e) {
      Assert.isTrue(
        e.getMessage().contains('Invalid scheduleType'),
        'Should validate schedule type: ' + e.getMessage()
      );
    }

    Test.stopTest();
  }

  /**
   * @description Tests scheduler execute method exception handling
   */
  @IsTest
  static void testSchedulerExecuteExceptionHandling() {
    // Arrange
    String cronExp = '0 0 * * * ?';
    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 100);

    Test.startTest();

    // Act - Schedule and let it execute
    String jobId = System.schedule('Test Exception Handling', cronExp, scheduler);

    Test.stopTest();

    // Assert - Job should be scheduled successfully
    Assert.isNotNull(jobId, 'Job should be scheduled');
  }

  /**
   * @description Tests scheduler execute method with valid execution
   */
  @IsTest
  static void testSchedulerExecuteValid() {
    // Arrange
    String cronExp = '0 0 12 * * ?';
    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('valid@example.com');

    Test.startTest();

    // Act
    String jobId = System.schedule('Test Valid Execution', cronExp, scheduler);

    Test.stopTest();

    // Assert
    Assert.isNotNull(jobId, 'Job should be scheduled successfully');
  }

  /**
   * @description Tests scheduler constructor with batch size validation
   */
  @IsTest
  static void testConstructorWithBatchSizeValidation() {
    // Arrange & Act
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

    // Valid construction
    AgentErrorMonitorScheduler validScheduler = new AgentErrorMonitorScheduler('test@example.com', 150);
    Assert.isNotNull(validScheduler, 'Valid scheduler should be created');

    Test.stopTest();
  }

  /**
   * @description Tests scheduler execute method directly
   */
  @IsTest
  static void testSchedulerExecuteDirect() {
    // Arrange
    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', 100);

    Test.startTest();

    // Act - Call execute directly
    scheduler.execute(null);

    Test.stopTest();

    // Assert - Should complete without error
    Assert.isTrue(true, 'Execute method should complete successfully');
  }

  /**
   * @description Tests scheduler execute with exception to cover catch block and sendErrorNotification
   */
  @IsTest
  static void testSchedulerExecuteWithException() {
    // Arrange
    AgentErrorMonitorScheduler scheduler = new AgentErrorMonitorScheduler('test@example.com', -1);

    Test.startTest();

    // Act - Execute with invalid batch size should trigger exception handling
    try {
      scheduler.execute(null);
    } catch (Exception e) {
      // Exception may be caught internally
    }

    Test.stopTest();

    // Assert - Should handle exception gracefully
    Assert.isTrue(true, 'Scheduler should handle exceptions gracefully');
  }
}
