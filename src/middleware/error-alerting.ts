/**
 * Error Alerting Middleware
 * Sends alerts to Slack/email for critical errors
 */

import { logError } from '../shared/logger.js';
import axios from 'axios';

interface AlertConfig {
  slackWebhookUrl?: string;
  emailApiKey?: string;
  emailTo?: string;
  alertThreshold?: number; // Errors per minute before alerting
}

let alertConfig: AlertConfig = {
  slackWebhookUrl: process.env.SLACK_WEBHOOK_URL,
  emailApiKey: process.env.SENDGRID_API_KEY,
  emailTo: process.env.ALERT_EMAIL,
  alertThreshold: parseInt(process.env.ALERT_THRESHOLD || '10'),
};

// Track error rates
const errorCounts: Map<string, number> = new Map();
const errorResetInterval = 60 * 1000; // 1 minute

// Reset error counts periodically
setInterval(() => {
  errorCounts.clear();
}, errorResetInterval);

/**
 * Send alert to Slack
 */
async function sendSlackAlert(message: string, metadata?: Record<string, any>): Promise<void> {
  if (!alertConfig.slackWebhookUrl) {
    return;
  }

  try {
    await axios.post(alertConfig.slackWebhookUrl, {
      text: `🚨 VibeZ Alert: ${message}`,
      blocks: [
        {
          type: 'section',
          text: {
            type: 'mrkdwn',
            text: `*${message}*\n\`\`\`${JSON.stringify(metadata, null, 2)}\`\`\``,
          },
        },
      ],
    });
  } catch (error: any) {
    logError('Failed to send Slack alert', error);
  }
}

/**
 * Send alert via email (using SendGrid or similar)
 */
async function sendEmailAlert(subject: string, message: string): Promise<void> {
  if (!alertConfig.emailApiKey || !alertConfig.emailTo) {
    return;
  }

  try {
    // Example: SendGrid API
    await axios.post(
      'https://api.sendgrid.com/v3/mail/send',
      {
        personalizations: [{ to: [{ email: alertConfig.emailTo }] }],
        from: { email: 'alerts@vibez.app' },
        subject,
        content: [{ type: 'text/plain', value: message }],
      },
      {
        headers: {
          Authorization: `Bearer ${alertConfig.emailApiKey}`,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    logError('Failed to send email alert', error);
  }
}

/**
 * Alert on critical error
 */
export async function alertOnError(
  error: Error,
  context: {
    type: 'auth' | 'db' | 'ws' | 'api' | 'moderation';
    endpoint?: string;
    userId?: string;
    metadata?: Record<string, any>;
  }
): Promise<void> {
  const errorKey = `${context.type}:${context.endpoint || 'unknown'}`;
  const count = (errorCounts.get(errorKey) || 0) + 1;
  errorCounts.set(errorKey, count);

  // Only alert if error rate exceeds threshold
  if (count >= (alertConfig.alertThreshold || 10)) {
    const message = `High error rate detected: ${errorKey} (${count} errors/min)`;
    const metadata = {
      error: error.message,
      stack: error.stack,
      ...context.metadata,
    };

    // Send alerts (non-blocking)
    Promise.all([
      sendSlackAlert(message, metadata),
      sendEmailAlert(`VibeZ Alert: ${context.type} Error`, `${message}\n\n${JSON.stringify(metadata, null, 2)}`),
    ]).catch(err => {
      logError('Failed to send alerts', err);
    });
  }
}

/**
 * Configure alerting
 */
export function configureAlerting(config: Partial<AlertConfig>): void {
  alertConfig = { ...alertConfig, ...config };
}

