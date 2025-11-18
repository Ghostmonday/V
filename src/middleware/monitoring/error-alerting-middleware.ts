/**
 * Error Alerting Middleware
 * Sends alerts to Slack/email for critical errors
 */

import { logError } from '../../shared/logger.js';
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
 * Send alert via email (using SendGrid)
 * Phase 6.3: Enhanced email alerting
 */
async function sendEmailAlert(subject: string, message: string, html?: string): Promise<void> {
  if (!alertConfig.emailApiKey || !alertConfig.emailTo) {
    return;
  }

  try {
    // SendGrid API v3
    const emailData: any = {
      personalizations: [{ to: [{ email: alertConfig.emailTo }] }],
      from: { email: process.env.ALERT_FROM_EMAIL || 'alerts@vibez.app', name: 'VibeZ Alerts' },
      subject,
      content: [{ type: 'text/plain', value: message }],
    };

    // Add HTML content if provided
    if (html) {
      emailData.content.push({ type: 'text/html', value: html });
    }

    await axios.post('https://api.sendgrid.com/v3/mail/send', emailData, {
      headers: {
        Authorization: `Bearer ${alertConfig.emailApiKey}`,
        'Content-Type': 'application/json',
      },
    });
  } catch (error: any) {
    logError('Failed to send email alert', error);
  }
}

/**
 * Send alert to PagerDuty
 * Phase 6.3: PagerDuty integration for critical issues
 */
async function sendPagerDutyAlert(
  summary: string,
  severity: 'critical' | 'error' | 'warning',
  details: Record<string, any>
): Promise<void> {
  const pagerDutyKey = process.env.PAGERDUTY_INTEGRATION_KEY;
  if (!pagerDutyKey) {
    return;
  }

  try {
    await axios.post(
      'https://events.pagerduty.com/v2/enqueue',
      {
        routing_key: pagerDutyKey,
        event_action: severity === 'critical' ? 'trigger' : 'acknowledge',
        payload: {
          summary,
          severity:
            severity === 'critical' ? 'critical' : severity === 'error' ? 'error' : 'warning',
          source: 'vibez-api',
          custom_details: details,
        },
      },
      {
        headers: {
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    logError('Failed to send PagerDuty alert', error);
  }
}

/**
 * Alert on critical error
 * Phase 6.3: Enhanced with PagerDuty for critical issues
 */
export async function alertOnError(
  error: Error,
  context: {
    type: 'auth' | 'db' | 'ws' | 'api' | 'moderation';
    endpoint?: string;
    userId?: string;
    metadata?: Record<string, any>;
    severity?: 'critical' | 'error' | 'warning';
  }
): Promise<void> {
  const errorKey = `${context.type}:${context.endpoint || 'unknown'}`;
  const count = (errorCounts.get(errorKey) || 0) + 1;
  errorCounts.set(errorKey, count);

  const severity = context.severity || (context.type === 'db' ? 'critical' : 'error');
  const shouldAlert = count >= (alertConfig.alertThreshold || 10) || severity === 'critical';

  if (shouldAlert) {
    const message = `High error rate detected: ${errorKey} (${count} errors/min)`;
    const metadata = {
      error: error.message,
      stack: error.stack,
      ...context.metadata,
      count,
      severity,
    };

    // Format HTML email
    const htmlEmail = `
      <h2>VibeZ Alert: ${context.type} Error</h2>
      <p><strong>Message:</strong> ${message}</p>
      <p><strong>Severity:</strong> ${severity}</p>
      <pre>${JSON.stringify(metadata, null, 2)}</pre>
    `;

    // Send alerts (non-blocking)
    const alertPromises = [
      sendSlackAlert(message, metadata),
      sendEmailAlert(
        `VibeZ Alert: ${context.type} Error (${severity})`,
        `${message}\n\n${JSON.stringify(metadata, null, 2)}`,
        htmlEmail
      ),
    ];

    // Send PagerDuty alert for critical issues
    if (severity === 'critical') {
      alertPromises.push(sendPagerDutyAlert(message, severity, metadata));
    }

    Promise.all(alertPromises).catch((err) => {
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
