/**
 * @description Run the Agent Error Monitor batch job immediately
 *
 * IMPORTANT: Update the email address below before running!
 */
// Configuration
String recipientEmail = 'your-email@example.com'; // TODO: Update this email address
Integer batchSize = 200; // Number of records to process per batch
Integer lookbackHours = 24; // Hours to look back for errors

AgentErrorMonitorBatch batch = new AgentErrorMonitorBatch(
  recipientEmail,
  lookbackHours
);
Id batchJobId = Database.executeBatch(batch, batchSize);

System.debug('Batch job started with ID: ' + batchJobId);
System.debug('Processing AI Agent errors from the last ' + lookbackHours + ' hours');
System.debug('Email notifications will be sent to: ' + recipientEmail);
