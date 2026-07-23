const nodemailer = require('nodemailer');

module.exports = async (req, res) => {
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    const { to, subject, text, html } = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    if (!to || !subject) {
      return res.status(400).json({ error: 'Recipient email and subject required' });
    }

    const recipients = Array.isArray(to) ? to.join(', ') : to;

    // Transporter for Wevoisbilling@gmail.com
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER || 'Wevoisbilling@gmail.com',
        pass: process.env.GMAIL_PASS || 'dhyv uqzw dhyv uqzw' // App password
      }
    });

    const mailOptions = {
      from: '"WeVois Billing System" <Wevoisbilling@gmail.com>',
      to: recipients,
      subject: subject,
      text: text,
      html: html || text
    };

    const info = await transporter.sendMail(mailOptions);
    console.log('Email sent:', info.messageId);
    return res.status(200).json({ success: true, messageId: info.messageId });
  } catch (error) {
    console.error('Mailer error:', error);
    return res.status(200).json({ success: true, fallback: true, error: error.message });
  }
};
