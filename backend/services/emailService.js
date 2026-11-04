const nodemailer = require('nodemailer');

const SMTP_USER = process.env.SMTP_USER || 'progressodulana@agentmobiletech.com';
const SMTP_PASS = process.env.SMTP_PASS || 'd8d8tY40Pe7W';
const SMTP_HOST = process.env.SMTP_HOST || 'smtp.zoho.com';
const SMTP_PORT = Number(process.env.SMTP_PORT) || 465;

const FROM_DISPLAY = '"Agent Platform" <' + SMTP_USER + '>';

const ADMIN_EMAILS = [
  'admin@agentmobiletech.com',
  'customercare@agentmobiletech.com',
  'progressodulana@agentmobiletech.com',
];

const BILLING_EMAILS = [
  'billing@agentmobiletech.com',
  'admin@agentmobiletech.com',
  'progressodulana@agentmobiletech.com',
];

// Initialize transporter
const transporter = nodemailer.createTransport({
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: SMTP_PORT === 465,
  auth: {
    user: SMTP_USER,
    pass: SMTP_PASS,
  },
  connectionTimeout: 10000,
  socketTimeout: 15000,
});

/**
 * Base email layout with branded header and footer
 */
function renderBaseTemplate({ title, preheader, bodyContent }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    body { margin: 0; padding: 0; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1E293B; }
    table { border-spacing: 0; width: 100%; }
    td { padding: 0; }
    img { border: 0; }
    .wrapper { width: 100%; table-layout: fixed; background-color: #F8FAFC; padding: 30px 0; }
    .main { background-color: #FFFFFF; max-width: 600px; margin: 0 auto; border-radius: 16px; border: 1px solid #E2E8F0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05); }
    .header { background: linear-gradient(135deg, #4F46E5 0%, #3730A3 100%); padding: 32px 28px; text-align: center; }
    .logo-text { color: #FFFFFF; font-size: 26px; font-weight: 800; letter-spacing: -0.5px; margin: 0; }
    .tagline { color: #E0E7FF; font-size: 13px; margin: 4px 0 0; }
    .content { padding: 36px 32px; font-size: 15px; line-height: 1.6; color: #334155; }
    .btn { display: inline-block; background-color: #4F46E5; color: #FFFFFF !important; font-weight: 600; font-size: 14px; text-decoration: none; padding: 13px 28px; border-radius: 10px; margin: 20px 0; }
    .card { background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 18px 20px; margin: 20px 0; }
    .footer { text-align: center; padding: 24px 20px; font-size: 12px; color: #94A3B8; background-color: #F8FAFC; }
    .footer a { color: #64748B; text-decoration: underline; }
  </style>
</head>
<body>
  <div style="display:none;font-size:1px;color:#333;line-height:1px;max-height:0px;max-width:0px;opacity:0;overflow:hidden;">
    ${preheader || title}
  </div>
  <center class="wrapper">
    <div class="main">
      <div class="header">
        <h1 class="logo-text">Agent</h1>
        <p class="tagline">Beyond Housing — Real Estate & Secure Escrow</p>
      </div>
      <div class="content">
        ${bodyContent}
      </div>
      <div class="footer">
        <p style="margin: 0 0 8px;">© ${new Date().getFullYear()} Agent Limited (agentmobiletech.com). All rights reserved.</p>
        <p style="margin: 0 0 8px;">Lagos, Nigeria • Secure Escrow Platform</p>
        <p style="margin: 0;">Support: <a href="mailto:customercare@agentmobiletech.com">customercare@agentmobiletech.com</a></p>
      </div>
    </div>
  </center>
</body>
</html>`;
}

/**
 * Send an email safely with logging and error handling
 */
async function sendMailSafely({ to, bcc, subject, html, text }) {
  try {
    const info = await transporter.sendMail({
      from: FROM_DISPLAY,
      to,
      bcc,
      subject,
      html,
      text: text || subject,
    });
    console.log(`📧 Email dispatched to [${to}]: ${subject} (ID: ${info.messageId})`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error(`❌ Email dispatch error to [${to}]:`, error.message);
    return { success: false, error: error.message };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. LOGIN SECURITY ALERT EMAIL
// ─────────────────────────────────────────────────────────────────────────────
async function sendLoginAlert({ to, name, time, ip, device, location }) {
  const loginTime = time || new Date().toUTCString();
  const title = 'Security Alert: New Sign-in to your Agent Account';
  const preheader = `A new sign-in was detected on your Agent account at ${loginTime}`;

  const bodyContent = `
    <h2 style="color: #0F172A; margin: 0 0 16px; font-size: 20px;">New Sign-In Detected</h2>
    <p>Hello ${name || 'User'},</p>
    <p>We detected a new sign-in to your Agent account. Here are the session details:</p>
    
    <div class="card">
      <table style="width: 100%;">
        <tr>
          <td style="padding: 6px 0; color: #64748B; width: 35%;"><strong>Date & Time:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;">${loginTime}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Device / Browser:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;">${device || 'Web / Mobile Client'}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>IP Address:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;">${ip || 'Protected'}</td>
        </tr>
        ${location ? `<tr><td style="padding: 6px 0; color: #64748B;"><strong>Location:</strong></td><td style="padding: 6px 0; color: #0F172A;">${location}</td></tr>` : ''}
      </table>
    </div>

    <p style="margin-top: 20px;">If this was you, you can safely ignore this email.</p>
    <p style="color: #DC2626; font-size: 13px;"><strong>If you did NOT sign in</strong>, your account may be compromised. Please reset your password immediately or contact our support team at <a href="mailto:customercare@agentmobiletech.com" style="color: #DC2626;">customercare@agentmobiletech.com</a>.</p>
  `;

  return sendMailSafely({
    to,
    subject: title,
    html: renderBaseTemplate({ title, preheader, bodyContent }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. ACCOUNT CREATION / WELCOME EMAIL
// ─────────────────────────────────────────────────────────────────────────────
async function sendWelcomeEmail({ to, name, role = 'tenant' }) {
  const title = 'Welcome to Agent — Your Secure Real Estate Platform 🏠';
  const preheader = `Welcome aboard, ${name}! Your Agent account is now ready.`;

  const bodyContent = `
    <h2 style="color: #0F172A; margin: 0 0 16px; font-size: 22px;">Welcome to Agent, ${name || 'Friend'}! 🎉</h2>
    <p>Thank you for joining Agent. We are thrilled to have you as part of Nigeria's safest property marketplace and escrow protection network.</p>

    <div class="card">
      <h3 style="margin: 0 0 10px; color: #4F46E5; font-size: 16px;">What you can do with Agent:</h3>
      <ul style="margin: 0; padding-left: 20px; color: #334155;">
        <li style="margin-bottom: 8px;"><strong>Verified Properties:</strong> Browse 100% verified homes, apartments, and land across Nigeria.</li>
        <li style="margin-bottom: 8px;"><strong>Vault Escrow Protection:</strong> Your rent and property deposits are held in a secure vault until you physically inspect and confirm possession.</li>
        <li style="margin-bottom: 8px;"><strong>Direct Messaging:</strong> Chat directly with verified landlords and property agents.</li>
        <li><strong>Instant Digital Payments:</strong> Pay securely with virtual accounts, cards, or bank transfers.</li>
      </ul>
    </div>

    <center>
      <a href="https://agentmobiletech.com" class="btn">Explore Available Properties</a>
    </center>

    <p style="font-size: 13px; color: #64748B;">Need help getting started? Our team is always here for you at <a href="mailto:customercare@agentmobiletech.com">customercare@agentmobiletech.com</a>.</p>
  `;

  // Send to the new user and alert admins
  const userResult = await sendMailSafely({
    to,
    subject: title,
    html: renderBaseTemplate({ title, preheader, bodyContent }),
  });

  // Admin Notification
  await sendAdminAlert({
    subject: `🔔 New User Registration: ${name || 'User'} (${role})`,
    title: 'New User Registered on Agent',
    details: {
      'Full Name': name || 'N/A',
      'Email Address': to,
      'User Role': role,
      'Registered At': new Date().toUTCString(),
    },
  });

  return userResult;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. PAYMENT RECEIVED EMAIL
// ─────────────────────────────────────────────────────────────────────────────
async function sendPaymentReceivedEmail({ to, name, amount, txRef, type = 'Escrow Deposit', propertyTitle, date }) {
  const formattedAmt = `₦${Number(amount || 0).toLocaleString()}`;
  const title = `Payment Confirmed: ${formattedAmt} received in your Agent Account 💳`;
  const preheader = `We have confirmed a payment of ${formattedAmt} (Ref: ${txRef})`;

  const bodyContent = `
    <h2 style="color: #0F172A; margin: 0 0 16px; font-size: 20px;">Payment Confirmed ✅</h2>
    <p>Hello ${name || 'Valued User'},</p>
    <p>We are pleased to inform you that a payment of <strong>${formattedAmt}</strong> has been successfully credited to your Agent account.</p>

    <div class="card">
      <table style="width: 100%;">
        <tr>
          <td style="padding: 6px 0; color: #64748B; width: 35%;"><strong>Amount:</strong></td>
          <td style="padding: 6px 0; color: #16A34A; font-size: 18px; font-weight: bold;">${formattedAmt}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Payment Type:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;">${type}</td>
        </tr>
        ${propertyTitle ? `<tr><td style="padding: 6px 0; color: #64748B;"><strong>Property:</strong></td><td style="padding: 6px 0; color: #0F172A;">${propertyTitle}</td></tr>` : ''}
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Reference:</strong></td>
          <td style="padding: 6px 0; color: #0F172A; font-family: monospace;">${txRef}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Date:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;">${date || new Date().toUTCString()}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Status:</strong></td>
          <td style="padding: 6px 0; color: #16A34A; font-weight: bold;">COMPLETED / CLEARED</td>
        </tr>
      </table>
    </div>

    <center>
      <a href="https://agentmobiletech.com" class="btn">View in Wallet</a>
    </center>

    <p style="font-size: 13px; color: #64748B;">Your transaction is protected by Agent Vault Escrow. Funds remain secure until deal conditions are satisfied.</p>
  `;

  // Send to user
  const userResult = await sendMailSafely({
    to,
    subject: title,
    html: renderBaseTemplate({ title, preheader, bodyContent }),
  });

  // Admin Alert to Billing team
  await sendAdminAlert({
    subject: `💰 Payment Received: ${formattedAmt} — ${txRef}`,
    title: 'New Transaction Processed',
    details: {
      'Payer / Recipient': `${name || 'User'} (${to})`,
      'Amount': formattedAmt,
      'Transaction Ref': txRef,
      'Payment Type': type,
      'Property': propertyTitle || 'Wallet Deposit',
      'Processed At': new Date().toUTCString(),
    },
    recipients: BILLING_EMAILS,
  });

  return userResult;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. PROPERTY ENQUIRY / TOUR REQUEST EMAIL
// ─────────────────────────────────────────────────────────────────────────────
async function sendPropertyEnquiryEmail({ to, ownerName, prospectName, prospectEmail, prospectPhone, propertyTitle, message, tourDate, tourTime }) {
  const title = `New Property Enquiry: ${prospectName} is interested in "${propertyTitle}" 🔑`;
  const preheader = `${prospectName} submitted an enquiry for ${propertyTitle}`;

  const bodyContent = `
    <h2 style="color: #0F172A; margin: 0 0 16px; font-size: 20px;">New Property Lead! 🎯</h2>
    <p>Hello ${ownerName || 'Property Owner'},</p>
    <p>A potential tenant/buyer has just submitted an enquiry regarding your listing <strong>"${propertyTitle}"</strong>.</p>

    <div class="card">
      <h3 style="margin: 0 0 12px; color: #4F46E5; font-size: 16px;">Lead Information</h3>
      <table style="width: 100%;">
        <tr>
          <td style="padding: 6px 0; color: #64748B; width: 35%;"><strong>Prospect Name:</strong></td>
          <td style="padding: 6px 0; color: #0F172A; font-weight: bold;">${prospectName}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Email:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;"><a href="mailto:${prospectEmail}">${prospectEmail}</a></td>
        </tr>
        <tr>
          <td style="padding: 6px 0; color: #64748B;"><strong>Phone Number:</strong></td>
          <td style="padding: 6px 0; color: #0F172A;"><a href="tel:${prospectPhone}">${prospectPhone}</a></td>
        </tr>
        ${tourDate ? `<tr><td style="padding: 6px 0; color: #64748B;"><strong>Requested Inspection:</strong></td><td style="padding: 6px 0; color: #4F46E5; font-weight: bold;">${tourDate} ${tourTime ? 'at ' + tourTime : ''}</td></tr>` : ''}
        ${message ? `<tr><td style="padding: 6px 0; color: #64748B; vertical-align: top;"><strong>Message:</strong></td><td style="padding: 6px 0; color: #0F172A; font-style: italic;">"${message}"</td></tr>` : ''}
      </table>
    </div>

    <center>
      <a href="https://agentmobiletech.com" class="btn">Respond in Agent Chat</a>
    </center>

    <p style="font-size: 13px; color: #64748B;">Pro tip: Responding within 1 hour increases your chance of closing a booking by 70%!</p>
  `;

  // Send to owner
  const result = await sendMailSafely({
    to,
    subject: title,
    html: renderBaseTemplate({ title, preheader, bodyContent }),
  });

  // Admin Notification to Customer Care
  await sendAdminAlert({
    subject: `📋 New Enquiry on "${propertyTitle}" by ${prospectName}`,
    title: 'Property Tour / Enquiry Lead',
    details: {
      'Property': propertyTitle,
      'Owner Email': to,
      'Prospect Name': prospectName,
      'Prospect Contact': `${prospectEmail} | ${prospectPhone}`,
      'Inspection Date': tourDate || 'Not specified',
      'Submitted At': new Date().toUTCString(),
    },
    recipients: ADMIN_EMAILS,
  });

  return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. CHAT MESSAGE NOTIFICATION EMAIL
// ─────────────────────────────────────────────────────────────────────────────
async function sendChatMessageEmail({ to, receiverName, senderName, messagePreview, conversationId }) {
  const title = `New message from ${senderName} on Agent 💬`;
  const preheader = `${senderName}: "${messagePreview}"`;

  const bodyContent = `
    <h2 style="color: #0F172A; margin: 0 0 16px; font-size: 20px;">You Have a New Message</h2>
    <p>Hello ${receiverName || 'User'},</p>
    <p><strong>${senderName}</strong> sent you a new message on Agent:</p>

    <div class="card" style="border-left: 4px solid #4F46E5;">
      <p style="margin: 0; font-size: 16px; color: #1E293B; font-style: italic;">"${messagePreview}"</p>
    </div>

    <center>
      <a href="https://agentmobiletech.com" class="btn">Reply to ${senderName}</a>
    </center>

    <p style="font-size: 13px; color: #64748B;">You can manage your notification preferences in your Agent account settings at any time.</p>
  `;

  return sendMailSafely({
    to,
    subject: title,
    html: renderBaseTemplate({ title, preheader, bodyContent }),
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. ADMIN & CUSTOMER CARE BROADCAST ALERT
// ─────────────────────────────────────────────────────────────────────────────
async function sendAdminAlert({ subject, title, details = {}, recipients = ADMIN_EMAILS }) {
  const preheader = subject;
  let rows = '';
  for (const [key, val] of Object.entries(details)) {
    rows += `<tr>
      <td style="padding: 6px 0; color: #64748B; width: 35%;"><strong>${key}:</strong></td>
      <td style="padding: 6px 0; color: #0F172A;">${val}</td>
    </tr>`;
  }

  const bodyContent = `
    <h2 style="color: #0F172A; margin: 0 0 16px; font-size: 20px;">${title}</h2>
    <div class="card">
      <table style="width: 100%;">
        ${rows}
      </table>
    </div>
    <center>
      <a href="https://agentmobiletech.com" class="btn">Open Admin Console</a>
    </center>
  `;

  const html = renderBaseTemplate({ title, preheader, bodyContent });

  // Send to all admin emails
  return sendMailSafely({
    to: recipients[0],
    bcc: recipients.slice(1),
    subject,
    html,
  });
}

module.exports = {
  sendLoginAlert,
  sendWelcomeEmail,
  sendPaymentReceivedEmail,
  sendPropertyEnquiryEmail,
  sendChatMessageEmail,
  sendAdminAlert,
  ADMIN_EMAILS,
  BILLING_EMAILS,
};

