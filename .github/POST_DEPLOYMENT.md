# Post-Deployment Configuration Guide

## ⚠️ Important: First Time Deployment

After the first successful deployment, you need to configure the environment variables and database.

### 1. Configure Environment Variables

SSH into your VPS and edit the `.env` file:

```bash
ssh your-user@your-vps-host
cd /home/onlybl-api/htdocs/api.onlybl.com/current
nano .env
```

### 2. Required Environment Variables

Update the following variables with your actual values:

#### **Database Configuration**
```env
DATABASE_URL="postgresql://username:password@host:5432/database_name?schema=public"
```

#### **JWT Secrets**
```env
JWT_SECRET="your-super-secret-jwt-key-min-32-chars"
JWT_REFRESH_SECRET="your-super-secret-refresh-key-min-32-chars"
```

#### **S3/R2 Storage (Cloudflare R2 or AWS S3)**
```env
S3_ENDPOINT="https://your-account-id.r2.cloudflarestorage.com"
S3_ACCESS_KEY_ID="your-r2-access-key-id"
S3_SECRET_ACCESS_KEY="your-r2-secret-access-key"
S3_BUCKET_NAME="your-bucket-name"
S3_REGION="auto"
CDN_URL="https://your-cdn-domain.com"
```

#### **Email Configuration (Optional)**
```env
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-specific-password"
```

#### **Redis Configuration (Optional)**
```env
USE_REDIS="false"
# If using Redis:
# USE_REDIS="true"
# REDIS_HOST="localhost"
# REDIS_PORT="6379"
# REDIS_PASSWORD="your-redis-password"
```

#### **Application Configuration**
```env
NODE_ENV="production"
PORT="3000"
API_VERSION="v1"
FRONTEND_URL="https://your-frontend-domain.com"
```

### 3. Run Database Migrations

After configuring the database credentials:

```bash
cd /home/onlybl-api/htdocs/api.onlybl.com/current
npx prisma migrate deploy
```

### 4. Restart the Application

```bash
pm2 restart blue-video-backend
pm2 save
```

### 5. Verify Deployment

Check application logs:
```bash
pm2 logs blue-video-backend
```

Check application status:
```bash
pm2 status
```

Test the health endpoint:
```bash
curl http://localhost:3000/health
```

### 6. Configure Nginx (CloudPanel)

In CloudPanel:
1. Go to your site settings
2. Set up reverse proxy to port 3000
3. Enable SSL certificate

Example Nginx configuration:
```nginx
location / {
    proxy_pass http://localhost:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### 7. Setup PM2 Startup Script

Ensure PM2 starts on server reboot:

```bash
pm2 startup
# Follow the instructions provided by the command
pm2 save
```

## 🔒 Security Checklist

- [ ] All environment variables are configured with production values
- [ ] Database password is strong and secure
- [ ] JWT secrets are unique and at least 32 characters
- [ ] S3/R2 credentials are restricted to minimum permissions
- [ ] Nginx is configured with SSL/TLS
- [ ] Firewall allows only necessary ports (80, 443, SSH)
- [ ] PM2 is configured to restart on crashes
- [ ] Backups are configured for database and uploaded files

## 📊 Monitoring

### View Application Logs
```bash
pm2 logs blue-video-backend --lines 100
```

### Monitor Resource Usage
```bash
pm2 monit
```

### View Detailed Process Info
```bash
pm2 show blue-video-backend
```

## 🔄 Manual Redeployment

If you need to manually redeploy:

```bash
cd /home/onlybl-api/htdocs/api.onlybl.com/current
git pull  # If using git
npm ci --production
npx prisma generate
pm2 restart blue-video-backend
```

## 🐛 Troubleshooting

### Application won't start
1. Check logs: `pm2 logs blue-video-backend --lines 200`
2. Verify .env file exists and has correct values
3. Check database connectivity: `npx prisma db pull`
4. Verify Node.js version: `node -v` (should be 18.x)

### Database connection errors
1. Verify DATABASE_URL in .env
2. Test database connection from server
3. Check PostgreSQL is running
4. Verify database user permissions

### File upload errors
1. Verify S3/R2 credentials in .env
2. Test credentials with AWS CLI or similar
3. Check bucket permissions
4. Verify CDN_URL is correct

### PM2 process crashes
1. Check logs for error messages
2. Verify all dependencies are installed
3. Check available memory and disk space
4. Review recent code changes

## 📞 Support

For issues with:
- **CloudPanel**: Check CloudPanel documentation
- **Database**: Verify PostgreSQL logs
- **Storage**: Check Cloudflare R2 or AWS S3 console
- **Application**: Check PM2 logs and application error logs

## 🔗 Useful Commands

```bash
# Restart application
pm2 restart blue-video-backend

# Stop application
pm2 stop blue-video-backend

# View logs (real-time)
pm2 logs blue-video-backend

# View logs (last 100 lines)
pm2 logs blue-video-backend --lines 100

# Clear logs
pm2 flush

# List all PM2 processes
pm2 list

# Show detailed process info
pm2 show blue-video-backend

# Monitor resource usage
pm2 monit

# Save PM2 process list
pm2 save

# Resurrect saved processes after reboot
pm2 resurrect
```

