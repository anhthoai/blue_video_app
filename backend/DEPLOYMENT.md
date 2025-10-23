# Backend Deployment Guide - CloudPanel VPS

This guide explains how to deploy the Blue Video backend to an Ubuntu CloudPanel VPS using GitHub Actions.

## Prerequisites

### 1. CloudPanel VPS Setup
- Ubuntu 20.04+ with CloudPanel installed
- Node.js 18.x or higher installed
- PM2 process manager installed globally: `npm install -g pm2`
- PostgreSQL database setup
- Domain/subdomain configured in CloudPanel (e.g., `api.example.com`)

### 2. GitHub Repository Secrets

Add the following secrets to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Description | Example |
|------------|-------------|---------|
| `VPS_HOST` | Your VPS IP address or domain | `123.45.67.89` or `vps.example.com` |
| `VPS_USERNAME` | SSH username (typically CloudPanel user) | `cloudpanel` |
| `VPS_SSH_KEY` | Private SSH key for authentication | *Your private key content* |
| `VPS_SSH_PORT` | SSH port (optional, default: 22) | `22` |
| `API_URL` | Your API base URL for health checks | `https://api.example.com` |

#### Generate SSH Key Pair

On your local machine:
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy
```

Copy the public key to your VPS:
```bash
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub cloudpanel@YOUR_VPS_IP
```

Copy the **private key** content to GitHub Secrets:
```bash
cat ~/.ssh/github_actions_deploy
# Copy the entire output including BEGIN and END lines
```

## CloudPanel VPS Setup

### 1. Create Site in CloudPanel

1. Log in to CloudPanel: `https://YOUR_VPS_IP:8443`
2. Create a new site:
   - Domain: `api.example.com`
   - Type: Node.js
   - Version: 18.x

### 2. Configure Application Directory

SSH into your VPS:
```bash
ssh cloudpanel@YOUR_VPS_IP
```

Create the deployment structure:
```bash
cd /home/cloudpanel/htdocs/api.example.com
mkdir -p current backups
```

### 3. Setup Environment Variables

Create the `.env` file in the deployment directory:
```bash
cd /home/cloudpanel/htdocs/api.example.com/current
nano .env
```

Add your environment variables:
```env
# Server Configuration
NODE_ENV=production
PORT=3000
API_VERSION=v1

# Database
DATABASE_URL="postgresql://username:password@localhost:5432/blue_video_db"

# JWT Secrets
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_REFRESH_SECRET=your-super-secret-refresh-key-change-this-in-production
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# S3/R2 Storage (Cloudflare R2)
S3_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
S3_ACCESS_KEY_ID=your-r2-access-key-id
S3_SECRET_ACCESS_KEY=your-r2-secret-access-key
S3_REGION=auto
S3_BUCKET_NAME=your-bucket-name
CDN_URL=https://your-custom-domain.com

# Email Configuration (Optional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# Frontend URL (for email links)
FRONTEND_URL=https://your-app.com

# CORS Origins (comma-separated)
CORS_ORIGIN=https://your-app.com,https://www.your-app.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# File Upload Limits
MAX_FILE_SIZE=104857600
ALLOWED_IMAGE_TYPES=image/jpeg,image/png,image/webp,image/gif
ALLOWED_VIDEO_TYPES=video/mp4,video/webm,video/quicktime
MAX_VIDEO_DURATION=300

# Redis (Optional - for caching)
USE_REDIS=false
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

Save and exit (`Ctrl+X`, then `Y`, then `Enter`).

### 4. Setup Database

Run database migrations:
```bash
cd /home/cloudpanel/htdocs/api.example.com/current
npx prisma migrate deploy
npx prisma generate
```

(Optional) Seed the database:
```bash
npx ts-node prisma/seed.ts
```

### 5. Install PM2 and Start Application

Install PM2 globally if not already installed:
```bash
npm install -g pm2
```

Start the application:
```bash
cd /home/cloudpanel/htdocs/api.example.com/current
pm2 start dist/server-local.js --name blue-video-backend \
  --time \
  --instances 2 \
  --exec-mode cluster \
  --max-memory-restart 500M \
  --env production
```

Save PM2 configuration:
```bash
pm2 save
pm2 startup
# Follow the instructions to enable PM2 on system startup
```

### 6. Configure Nginx Reverse Proxy

CloudPanel should have already configured Nginx for your site. Verify or update the configuration:

```bash
sudo nano /etc/nginx/sites-available/api.example.com.conf
```

Ensure it includes:
```nginx
location / {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_cache_bypass $http_upgrade;
    
    # Timeout settings for long-running requests
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}

# Increase upload size for video files
client_max_body_size 100M;
```

Reload Nginx:
```bash
sudo systemctl reload nginx
```

## GitHub Actions Workflow

The workflow file `.github/workflows/deploy-backend.yml` is already configured and will:

1. ✅ Trigger on push to `main` or `production` branches
2. ✅ Build the TypeScript code
3. ✅ Generate Prisma client
4. ✅ Create deployment package
5. ✅ Transfer files to VPS via SSH
6. ✅ Extract and backup previous deployment
7. ✅ Run database migrations
8. ✅ Restart application with PM2
9. ✅ Perform health check
10. ✅ Notify on success/failure

### Manual Deployment Trigger

You can manually trigger the deployment from GitHub:
1. Go to your repository
2. Click **Actions** tab
3. Select **Deploy Backend to CloudPanel VPS**
4. Click **Run workflow**

## Monitoring and Management

### PM2 Commands

Check application status:
```bash
pm2 status
```

View logs:
```bash
pm2 logs blue-video-backend
pm2 logs blue-video-backend --lines 100
```

Restart application:
```bash
pm2 restart blue-video-backend
```

Stop application:
```bash
pm2 stop blue-video-backend
```

Monitor resource usage:
```bash
pm2 monit
```

### Application Logs

View recent logs:
```bash
cd /home/cloudpanel/htdocs/api.example.com/current
pm2 logs blue-video-backend --lines 50
```

### Health Check

Test the health endpoint:
```bash
curl https://api.example.com/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-10-23T12:00:00.000Z",
  "uptime": 123.456,
  "version": "v1"
}
```

## Rollback Procedure

If the deployment fails, you can quickly rollback:

```bash
cd /home/cloudpanel/htdocs/api.example.com

# List available backups
ls -lt backups/

# Restore from a backup
rm -rf current
cp -r backups/backup-YYYYMMDD-HHMMSS current

# Restart PM2
cd current
pm2 restart blue-video-backend
```

## Troubleshooting

### Issue: Application not starting

Check logs:
```bash
pm2 logs blue-video-backend --err --lines 100
```

Common fixes:
- Verify `.env` file exists and has correct values
- Check database connection: `DATABASE_URL`
- Ensure port 3000 is not already in use: `netstat -tlnp | grep 3000`

### Issue: Database connection failed

Test database connection:
```bash
cd /home/cloudpanel/htdocs/api.example.com/current
npx prisma db pull
```

Check PostgreSQL status:
```bash
sudo systemctl status postgresql
```

### Issue: File upload fails

Check S3/R2 credentials in `.env`:
```bash
cd /home/cloudpanel/htdocs/api.example.com/current
cat .env | grep S3
```

Test S3 connection manually from the VPS.

### Issue: High memory usage

Restart PM2 with lower memory limit:
```bash
pm2 delete blue-video-backend
pm2 start dist/server-local.js --name blue-video-backend \
  --instances 1 \
  --max-memory-restart 300M
pm2 save
```

### Issue: SSL certificate errors

Renew SSL certificate in CloudPanel:
```bash
sudo clpctl lets-encrypt:install:certificate --domainName=api.example.com
```

## Security Best Practices

1. **Keep secrets secure**: Never commit `.env` files to Git
2. **Use strong passwords**: For database and JWT secrets
3. **Enable firewall**: Allow only necessary ports (22, 80, 443)
4. **Regular updates**: Keep Ubuntu, Node.js, and dependencies updated
5. **Monitor logs**: Set up log monitoring and alerts
6. **Backup database**: Schedule regular database backups
7. **Rate limiting**: Configure appropriate rate limits in `.env`
8. **HTTPS only**: Always use SSL/TLS for API access

## Performance Optimization

### Enable Redis Caching

Install Redis:
```bash
sudo apt update
sudo apt install redis-server
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

Update `.env`:
```env
USE_REDIS=true
REDIS_HOST=localhost
REDIS_PORT=6379
```

Restart application:
```bash
pm2 restart blue-video-backend
```

### Enable Nginx Caching

Add to Nginx configuration:
```nginx
# Cache static assets
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|webp)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Cache API responses (optional, be careful with dynamic content)
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=100m inactive=60m;
proxy_cache_key "$scheme$request_method$host$request_uri";
```

## Maintenance Tasks

### Weekly Tasks
- Check disk space: `df -h`
- Review application logs: `pm2 logs --lines 500`
- Check PM2 status: `pm2 status`

### Monthly Tasks
- Update dependencies: `npm update`
- Clean old backups: `find backups/ -mtime +30 -delete`
- Review and optimize database: `VACUUM ANALYZE`

### Quarterly Tasks
- Update Node.js version
- Update Ubuntu packages: `sudo apt update && sudo apt upgrade`
- Review and update security policies

## Support

If you encounter issues:
1. Check application logs: `pm2 logs blue-video-backend`
2. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
3. Check system logs: `sudo journalctl -xe`
4. Review GitHub Actions workflow logs in the Actions tab

For CloudPanel specific issues, refer to: https://www.cloudpanel.io/docs/

---

**Last Updated**: October 2024
**Version**: 1.0.0

