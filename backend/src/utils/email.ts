import nodemailer from 'nodemailer';
import dotenv from 'dotenv';

dotenv.config();

export interface EmailOptions {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export class EmailService {
  private transporter: nodemailer.Transporter;

  constructor() {
    this.transporter = nodemailer.createTransporter({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: false, // true for 465, false for other ports
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }

  /**
   * Send email
   */
  async sendEmail(options: EmailOptions): Promise<boolean> {
    try {
      const mailOptions = {
        from: `"Blue Video" <${process.env.SMTP_USER}>`,
        to: options.to,
        subject: options.subject,
        text: options.text,
        html: options.html,
      };

      await this.transporter.sendMail(mailOptions);
      return true;
    } catch (error) {
      console.error('Email sending failed:', error);
      return false;
    }
  }

  /**
   * Send welcome email
   */
  async sendWelcomeEmail(userEmail: string, username: string): Promise<boolean> {
    const subject = 'Welcome to Blue Video!';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2196F3;">Welcome to Blue Video!</h1>
        <p>Hi ${username},</p>
        <p>Welcome to Blue Video! We're excited to have you join our community of creators and viewers.</p>
        <p>Here's what you can do:</p>
        <ul>
          <li>Upload and share your videos</li>
          <li>Connect with other creators</li>
          <li>Discover amazing content</li>
          <li>Join community discussions</li>
        </ul>
        <p>Get started by uploading your first video or exploring the community!</p>
        <p>Best regards,<br>The Blue Video Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html,
    });
  }

  /**
   * Send password reset email
   */
  async sendPasswordResetEmail(userEmail: string, resetToken: string): Promise<boolean> {
    const subject = 'Reset Your Blue Video Password';
    const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${resetToken}`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2196F3;">Reset Your Password</h1>
        <p>You requested to reset your password for your Blue Video account.</p>
        <p>Click the button below to reset your password:</p>
        <a href="${resetUrl}" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Reset Password</a>
        <p>If the button doesn't work, copy and paste this link into your browser:</p>
        <p>${resetUrl}</p>
        <p>This link will expire in 1 hour.</p>
        <p>If you didn't request this password reset, please ignore this email.</p>
        <p>Best regards,<br>The Blue Video Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html,
    });
  }

  /**
   * Send email verification
   */
  async sendEmailVerification(userEmail: string, verificationToken: string): Promise<boolean> {
    const subject = 'Verify Your Blue Video Account';
    const verificationUrl = `${process.env.FRONTEND_URL}/verify-email?token=${verificationToken}`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2196F3;">Verify Your Email Address</h1>
        <p>Thank you for signing up for Blue Video!</p>
        <p>Please verify your email address by clicking the button below:</p>
        <a href="${verificationUrl}" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">Verify Email</a>
        <p>If the button doesn't work, copy and paste this link into your browser:</p>
        <p>${verificationUrl}</p>
        <p>This link will expire in 24 hours.</p>
        <p>Best regards,<br>The Blue Video Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html,
    });
  }

  /**
   * Send notification email
   */
  async sendNotificationEmail(
    userEmail: string,
    title: string,
    message: string,
    actionUrl?: string
  ): Promise<boolean> {
    const subject = `Blue Video: ${title}`;
    
    let html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2196F3;">${title}</h1>
        <p>${message}</p>
    `;

    if (actionUrl) {
      html += `
        <a href="${actionUrl}" style="background-color: #2196F3; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; display: inline-block;">View Details</a>
      `;
    }

    html += `
        <p>Best regards,<br>The Blue Video Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html,
    });
  }

  /**
   * Send chat notification email
   */
  async sendChatNotificationEmail(
    userEmail: string,
    senderName: string,
    message: string,
    roomName: string
  ): Promise<boolean> {
    const subject = `New message from ${senderName}`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #2196F3;">New Message</h1>
        <p>You have a new message from <strong>${senderName}</strong> in <strong>${roomName}</strong>:</p>
        <div style="background-color: #f5f5f5; padding: 16px; border-radius: 4px; margin: 16px 0;">
          <p style="margin: 0;">${message}</p>
        </div>
        <p>Reply to continue the conversation!</p>
        <p>Best regards,<br>The Blue Video Team</p>
      </div>
    `;

    return this.sendEmail({
      to: userEmail,
      subject,
      html,
    });
  }
}
