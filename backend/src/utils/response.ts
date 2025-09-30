import { Response } from 'express';

export interface ApiResponse<T = any> {
  success: boolean;
  message: string;
  data?: T;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages?: number;
  };
  errors?: Array<{
    field: string;
    message: string;
  }>;
}

export class ResponseHelper {
  /**
   * Send success response
   */
  static success<T>(
    res: Response,
    message: string,
    data?: T,
    statusCode: number = 200
  ): void {
    const response: ApiResponse<T> = {
      success: true,
      message,
    };

    if (data !== undefined) {
      response.data = data;
    }

    res.status(statusCode).json(response);
  }

  /**
   * Send error response
   */
  static error(
    res: Response,
    message: string,
    statusCode: number = 400,
    errors?: Array<{ field: string; message: string }>
  ): void {
    const response: ApiResponse = {
      success: false,
      message,
    };

    if (errors) {
      response.errors = errors;
    }

    res.status(statusCode).json(response);
  }

  /**
   * Send paginated response
   */
  static paginated<T>(
    res: Response,
    message: string,
    data: T[],
    pagination: {
      page: number;
      limit: number;
      total: number;
      totalPages?: number;
    },
    statusCode: number = 200
  ): void {
    const response: ApiResponse<T[]> = {
      success: true,
      message,
      data,
      pagination,
    };

    res.status(statusCode).json(response);
  }

  /**
   * Send validation error response
   */
  static validationError(
    res: Response,
    errors: Array<{ field: string; message: string }>
  ): void {
    this.error(
      res,
      'Validation failed',
      400,
      errors
    );
  }

  /**
   * Send not found response
   */
  static notFound(res: Response, message: string = 'Resource not found'): void {
    this.error(res, message, 404);
  }

  /**
   * Send unauthorized response
   */
  static unauthorized(res: Response, message: string = 'Unauthorized'): void {
    this.error(res, message, 401);
  }

  /**
   * Send forbidden response
   */
  static forbidden(res: Response, message: string = 'Forbidden'): void {
    this.error(res, message, 403);
  }

  /**
   * Send conflict response
   */
  static conflict(res: Response, message: string = 'Conflict'): void {
    this.error(res, message, 409);
  }

  /**
   * Send internal server error response
   */
  static internalError(res: Response, message: string = 'Internal server error'): void {
    this.error(res, message, 500);
  }

  /**
   * Send rate limit response
   */
  static rateLimit(res: Response, message: string = 'Too many requests'): void {
    this.error(res, message, 429);
  }

  /**
   * Send created response
   */
  static created<T>(res: Response, message: string, data?: T): void {
    this.success(res, message, data, 201);
  }

  /**
   * Send no content response
   */
  static noContent(res: Response, message: string = 'No content'): void {
    this.success(res, message, undefined, 204);
  }
}
