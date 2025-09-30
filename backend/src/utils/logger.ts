import fs from 'fs';
import path from 'path';

export enum LogLevel {
  ERROR = 'error',
  WARN = 'warn',
  INFO = 'info',
  DEBUG = 'debug',
}

export interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  data?: any;
  userId?: string;
  requestId?: string;
}

export class Logger {
  private static logDir = path.join(process.cwd(), 'logs');
  private static isInitialized = false;

  /**
   * Initialize logger
   */
  static initialize(): void {
    if (!this.isInitialized) {
      // Create logs directory if it doesn't exist
      if (!fs.existsSync(this.logDir)) {
        fs.mkdirSync(this.logDir, { recursive: true });
      }
      this.isInitialized = true;
    }
  }

  /**
   * Log message to console and file
   */
  private static log(level: LogLevel, message: string, data?: any, userId?: string, requestId?: string): void {
    this.initialize();

    const timestamp = new Date().toISOString();
    const logEntry: LogEntry = {
      timestamp,
      level,
      message,
      data,
      userId,
      requestId,
    };

    // Console output
    const consoleMessage = `[${timestamp}] ${level.toUpperCase()}: ${message}`;
    if (data) {
      console.log(consoleMessage, data);
    } else {
      console.log(consoleMessage);
    }

    // File output
    const logFile = path.join(this.logDir, `${level}.log`);
    const logLine = JSON.stringify(logEntry) + '\n';
    
    fs.appendFileSync(logFile, logLine);
  }

  /**
   * Log error message
   */
  static error(message: string, data?: any, userId?: string, requestId?: string): void {
    this.log(LogLevel.ERROR, message, data, userId, requestId);
  }

  /**
   * Log warning message
   */
  static warn(message: string, data?: any, userId?: string, requestId?: string): void {
    this.log(LogLevel.WARN, message, data, userId, requestId);
  }

  /**
   * Log info message
   */
  static info(message: string, data?: any, userId?: string, requestId?: string): void {
    this.log(LogLevel.INFO, message, data, userId, requestId);
  }

  /**
   * Log debug message
   */
  static debug(message: string, data?: any, userId?: string, requestId?: string): void {
    this.log(LogLevel.DEBUG, message, data, userId, requestId);
  }

  /**
   * Log API request
   */
  static apiRequest(method: string, url: string, statusCode: number, responseTime: number, userId?: string): void {
    this.info(`API Request: ${method} ${url}`, {
      method,
      url,
      statusCode,
      responseTime,
    }, userId);
  }

  /**
   * Log database query
   */
  static dbQuery(query: string, duration: number, userId?: string): void {
    this.debug(`Database Query`, {
      query,
      duration,
    }, userId);
  }

  /**
   * Log authentication event
   */
  static authEvent(event: string, userId: string, data?: any): void {
    this.info(`Auth Event: ${event}`, data, userId);
  }

  /**
   * Log file upload
   */
  static fileUpload(filename: string, size: number, userId: string): void {
    this.info(`File Upload: ${filename}`, {
      filename,
      size,
    }, userId);
  }

  /**
   * Log video processing
   */
  static videoProcessing(videoId: string, status: string, userId: string): void {
    this.info(`Video Processing: ${status}`, {
      videoId,
      status,
    }, userId);
  }

  /**
   * Log chat message
   */
  static chatMessage(roomId: string, userId: string, messageType: string): void {
    this.debug(`Chat Message`, {
      roomId,
      userId,
      messageType,
    }, userId);
  }

  /**
   * Log social interaction
   */
  static socialInteraction(action: string, contentId: string, contentType: string, userId: string): void {
    this.info(`Social Interaction: ${action}`, {
      contentId,
      contentType,
      action,
    }, userId);
  }

  /**
   * Log system event
   */
  static systemEvent(event: string, data?: any): void {
    this.info(`System Event: ${event}`, data);
  }

  /**
   * Log security event
   */
  static securityEvent(event: string, data?: any, userId?: string): void {
    this.warn(`Security Event: ${event}`, data, userId);
  }

  /**
   * Log performance metric
   */
  static performance(metric: string, value: number, unit: string = 'ms'): void {
    this.info(`Performance: ${metric}`, {
      metric,
      value,
      unit,
    });
  }

  /**
   * Log error with stack trace
   */
  static errorWithStack(message: string, error: Error, userId?: string, requestId?: string): void {
    this.error(message, {
      name: error.name,
      message: error.message,
      stack: error.stack,
    }, userId, requestId);
  }

  /**
   * Clean old log files
   */
  static cleanOldLogs(daysToKeep: number = 30): void {
    this.initialize();

    const files = fs.readdirSync(this.logDir);
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

    files.forEach(file => {
      const filePath = path.join(this.logDir, file);
      const stats = fs.statSync(filePath);
      
      if (stats.mtime < cutoffDate) {
        fs.unlinkSync(filePath);
        this.info(`Cleaned old log file: ${file}`);
      }
    });
  }
}
