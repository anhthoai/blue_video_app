import { StorageService } from '../config/storage';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

interface UploadJob {
  id: string;
  episodeId: string;
  thumbnailUrl?: string;
  videoPreviewUrl?: string;
  movieId: string;
  episodeNumber: number;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  retries: number;
  error?: string;
  createdAt: Date;
}

class UploadQueueService {
  private queue: UploadJob[] = [];
  private processing = false;
  private maxRetries = 3;
  private concurrency = 2; // Process 2 jobs at a time

  /**
   * Add episode preview upload job to queue
   */
  addJob(job: Omit<UploadJob, 'id' | 'status' | 'retries' | 'createdAt'>): string {
    const jobId = `${job.episodeId}-${Date.now()}`;
    const uploadJob: UploadJob = {
      ...job,
      id: jobId,
      status: 'pending',
      retries: 0,
      createdAt: new Date(),
    };

    this.queue.push(uploadJob);
    console.log(`📋 Added upload job to queue: ${jobId} (Queue size: ${this.queue.length})`);

    // Start processing if not already running
    if (!this.processing) {
      this.processQueue();
    }

    return jobId;
  }

  /**
   * Process jobs in the queue
   */
  private async processQueue(): Promise<void> {
    if (this.processing) return;
    
    this.processing = true;
    console.log(`🔄 Starting queue processing (${this.queue.length} jobs pending)...`);

    while (this.queue.length > 0) {
      // Get pending jobs (up to concurrency limit)
      const pendingJobs = this.queue
        .filter(job => job.status === 'pending')
        .slice(0, this.concurrency);

      if (pendingJobs.length === 0) {
        // No pending jobs, check if any are still processing
        const processingJobs = this.queue.filter(job => job.status === 'processing');
        if (processingJobs.length === 0) {
          break; // All done
        }
        // Wait a bit for processing jobs to complete
        await new Promise(resolve => setTimeout(resolve, 1000));
        continue;
      }

      // Process jobs in parallel
      await Promise.all(
        pendingJobs.map(job => this.processJob(job))
      );

      // Remove completed and failed jobs
      this.queue = this.queue.filter(
        job => job.status !== 'completed' && job.status !== 'failed'
      );
    }

    this.processing = false;
    console.log(`✅ Queue processing complete`);
  }

  /**
   * Process a single job
   */
  private async processJob(job: UploadJob): Promise<void> {
    job.status = 'processing';
    console.log(`⚙️  Processing upload job: ${job.id} (Episode ${job.episodeNumber})`);

    try {
      // Fetch episode to get slug for filenameId
      const episode = await prisma.movieEpisode.findUnique({
        where: { id: job.episodeId },
        select: { slug: true },
      });

      if (!episode) {
        throw new Error(`Episode ${job.episodeId} not found`);
      }

      // Use episode slug as filenameId (same for both thumbnail and video preview)
      const filenameId = episode.slug;

      let thumbnailKey: string | null = null;
      let videoPreviewKey: string | null = null;

      // Build date-based storage prefix using job creation timestamp
      const createdAt = job.createdAt || new Date();
      const year = createdAt.getFullYear();
      const month = String(createdAt.getMonth() + 1).padStart(2, '0');
      const day = String(createdAt.getDate()).padStart(2, '0');
      const datePath = `${year}/${month}/${day}`;

      // Upload thumbnail if provided
      if (job.thumbnailUrl && !job.thumbnailUrl.startsWith('s3://')) {
        console.log(`📥 Uploading thumbnail for episode ${job.episodeNumber}...`);
        const result = await StorageService.uploadFromUrl(
          job.thumbnailUrl,
          `thumbnails/${datePath}`,
          filenameId
        );
        
        if (result) {
          thumbnailKey = `s3://${result.key}`;
          console.log(`✅ Thumbnail uploaded: ${result.key}`);
        }
      }

      // Upload video preview if provided
      if (job.videoPreviewUrl && !job.videoPreviewUrl.startsWith('s3://')) {
        console.log(`📥 Uploading video preview for episode ${job.episodeNumber}...`);
        const result = await StorageService.uploadFromUrl(
          job.videoPreviewUrl,
          `previews/${datePath}`,
          filenameId
        );
        
        if (result) {
          videoPreviewKey = `s3://${result.key}`;
          console.log(`✅ Video preview uploaded: ${result.key}`);
        }
      }

      // Update episode in database with S3 keys
      const updateData: any = {};
      if (thumbnailKey) updateData.thumbnailUrl = thumbnailKey;
      if (videoPreviewKey) updateData.videoPreviewUrl = videoPreviewKey;

      if (Object.keys(updateData).length > 0) {
        await prisma.movieEpisode.update({
          where: { id: job.episodeId },
          data: updateData,
        });
        console.log(`✅ Updated episode ${job.episodeNumber} with S3 URLs`);
      }

      job.status = 'completed';
    } catch (error: any) {
      console.error(`❌ Upload job failed: ${job.id}`, error.message);
      job.retries++;

      if (job.retries < this.maxRetries) {
        // Retry
        job.status = 'pending';
        console.log(`🔄 Retrying job ${job.id} (attempt ${job.retries + 1}/${this.maxRetries})`);
      } else {
        // Max retries reached
        job.status = 'failed';
        job.error = error.message;
        console.error(`❌ Job ${job.id} failed after ${this.maxRetries} attempts`);
      }
    }
  }

  /**
   * Get queue status
   */
  getStatus(): {
    queueLength: number;
    processing: boolean;
    jobs: Array<{ id: string; status: string; retries: number }>;
  } {
    return {
      queueLength: this.queue.length,
      processing: this.processing,
      jobs: this.queue.map(job => ({
        id: job.id,
        status: job.status,
        retries: job.retries,
      })),
    };
  }

  /**
   * Clear completed and failed jobs
   */
  clearFinished(): void {
    const before = this.queue.length;
    this.queue = this.queue.filter(
      job => job.status === 'pending' || job.status === 'processing'
    );
    const cleared = before - this.queue.length;
    console.log(`🗑️  Cleared ${cleared} finished jobs from queue`);
  }
}

// Singleton instance
export const uploadQueue = new UploadQueueService();

