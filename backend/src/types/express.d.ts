declare namespace Express {
  export interface Request {
    userId?: string;
    userCreatedAt?: Date;
    currentUser?: {
      id: string;
      createdAt: Date;
      fileDirectory: string | null;
      avatar: string | null;
      banner: string | null;
    };
  }
}

