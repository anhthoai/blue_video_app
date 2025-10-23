# Deployment Checklist

Use this checklist to ensure proper setup of GitHub Actions deployment to CloudPanel VPS.

## Initial Setup

### 1. VPS Prerequisites
- [ ] Ubuntu 20.04+ installed
- [ ] CloudPanel installed and configured
- [ ] Domain/subdomain configured (e.g., `api.example.com`)
- [ ] SSL certificate installed
- [ ] Node.js 18.x installed
- [ ] PostgreSQL installed and configured
- [ ] PM2 installed globally: `npm install -g pm2`
- [ ] Nginx configured as reverse proxy

### 2. GitHub Repository Secrets
- [ ] `VPS_HOST` - VPS IP or domain
- [ ] `VPS_USERNAME` - SSH username (usually `cloudpanel`)
- [ ] `VPS_SSH_KEY` - Complete private SSH key
- [ ] `VPS_SSH_PORT` - SSH port (if not 22)
- [ ] `API_URL` - API URL for health checks

### 3. SSH Key Setup
- [ ] Generated SSH key pair: `ssh-keygen -t ed25519 -C "github-actions"`
- [ ] Added public key to VPS: `~/.ssh/authorized_keys`
- [ ] Tested SSH connection from local machine
- [ ] Added private key to GitHub Secrets

### 4. VPS Directory Structure
- [ ] Created deployment directory: `/home/cloudpanel/htdocs/api.example.com`
- [ ] Created `current` subdirectory
- [ ] Created `backups` subdirectory
- [ ] Set correct permissions: `chown -R cloudpanel:cloudpanel`

### 5. Environment Configuration
- [ ] Created `.env` file in deployment directory
- [ ] Configured all required environment variables
- [ ] Tested database connection
- [ ] Tested S3/R2 connection
- [ ] Configured CORS origins
- [ ] Set secure JWT secrets

### 6. Database Setup
- [ ] Created PostgreSQL database
- [ ] Created database user with appropriate permissions
- [ ] Ran initial migrations: `npx prisma migrate deploy`
- [ ] Generated Prisma client: `npx prisma generate`
- [ ] (Optional) Seeded initial data: `npx ts-node prisma/seed.ts`

### 7. PM2 Configuration
- [ ] PM2 installed globally
- [ ] PM2 startup configured: `pm2 startup`
- [ ] PM2 logrotate installed: `pm2 install pm2-logrotate`
- [ ] Created logs directory: `mkdir -p logs`

### 8. Nginx Configuration
- [ ] Reverse proxy configured for port 3000
- [ ] Client max body size set: `client_max_body_size 100M`
- [ ] WebSocket support enabled (if needed)
- [ ] Timeout settings configured
- [ ] SSL/TLS configured
- [ ] Nginx config tested: `sudo nginx -t`
- [ ] Nginx reloaded: `sudo systemctl reload nginx`

### 9. Firewall Configuration
- [ ] Opened port 22 (SSH)
- [ ] Opened port 80 (HTTP)
- [ ] Opened port 443 (HTTPS)
- [ ] Opened port 8443 (CloudPanel - if needed)
- [ ] Closed port 3000 (application runs behind nginx)

### 10. GitHub Actions Workflow
- [ ] Workflow file created: `.github/workflows/deploy-backend.yml`
- [ ] Environment variables configured in workflow
- [ ] Deployment path matches VPS path
- [ ] PM2 app name is correct
- [ ] Node.js version matches
- [ ] Health check URL is correct

## Pre-Deployment Checks

### Before Each Deployment
- [ ] All tests passing locally
- [ ] Code builds without errors: `npm run build`
- [ ] Database migrations are up to date
- [ ] Environment variables documented
- [ ] Breaking changes documented
- [ ] Version number updated in `package.json`
- [ ] Changelog updated

### Staging Environment (Recommended)
- [ ] Deploy to staging first
- [ ] Run smoke tests
- [ ] Verify database migrations
- [ ] Test critical endpoints
- [ ] Load test (if significant changes)

## First Deployment

### 1. Manual Test Deployment
- [ ] Tested deployment script locally: `./backend/deploy.sh`
- [ ] Verified files uploaded correctly
- [ ] Verified application starts: `pm2 status`
- [ ] Checked logs for errors: `pm2 logs`
- [ ] Tested health endpoint: `curl https://api.example.com/health`
- [ ] Tested main API endpoints

### 2. GitHub Actions Test
- [ ] Pushed code to trigger workflow
- [ ] Monitored workflow execution
- [ ] Verified deployment succeeded
- [ ] Checked application status on VPS
- [ ] Tested rollback procedure

## Post-Deployment Verification

### After Each Deployment
- [ ] Application is running: `pm2 status`
- [ ] Health check passes
- [ ] Database migrations completed
- [ ] No errors in logs: `pm2 logs --lines 100`
- [ ] API endpoints responding
- [ ] Authentication working
- [ ] File uploads working
- [ ] WebSocket connections (if applicable)
- [ ] Email sending (if applicable)

### Performance Checks
- [ ] Response times acceptable
- [ ] Memory usage normal
- [ ] CPU usage normal
- [ ] No memory leaks
- [ ] Database queries optimized

### Security Checks
- [ ] HTTPS working correctly
- [ ] CORS configured properly
- [ ] Rate limiting active
- [ ] SQL injection protection
- [ ] XSS protection
- [ ] Authentication/authorization working
- [ ] Sensitive data not exposed in logs

## Monitoring Setup (Recommended)

### Application Monitoring
- [ ] PM2 monitoring: `pm2 monit`
- [ ] Log aggregation configured
- [ ] Error tracking (e.g., Sentry)
- [ ] Uptime monitoring (e.g., UptimeRobot)
- [ ] Performance monitoring (e.g., New Relic)

### Alerts Configured
- [ ] Application down alerts
- [ ] High memory usage alerts
- [ ] High CPU usage alerts
- [ ] Disk space alerts
- [ ] Database connection alerts
- [ ] Error rate alerts

## Backup Strategy

### Regular Backups
- [ ] Database backup schedule configured
- [ ] Automated daily backups
- [ ] Backup retention policy (30 days recommended)
- [ ] Backup restoration tested
- [ ] Backup monitoring

### Disaster Recovery
- [ ] Recovery procedure documented
- [ ] Recovery time objective (RTO) defined
- [ ] Recovery point objective (RPO) defined
- [ ] Recovery procedure tested

## Maintenance

### Weekly Tasks
- [ ] Check disk space
- [ ] Review error logs
- [ ] Check PM2 status
- [ ] Monitor resource usage

### Monthly Tasks
- [ ] Update dependencies: `npm update`
- [ ] Security audit: `npm audit`
- [ ] Clean old backups
- [ ] Review and optimize database
- [ ] Update SSL certificates (if needed)

### Quarterly Tasks
- [ ] Update Node.js version
- [ ] Update Ubuntu packages
- [ ] Review security policies
- [ ] Load testing
- [ ] Disaster recovery drill

## Troubleshooting Resources

### Quick Checks
```bash
# Check application status
pm2 status

# View logs
pm2 logs blue-video-backend --lines 100

# Check nginx
sudo nginx -t
sudo systemctl status nginx

# Check database
sudo systemctl status postgresql
psql -U postgres -c "SELECT version();"

# Check disk space
df -h

# Check memory
free -h

# Check CPU
top
```

### Common Issues
- [ ] Application not starting → Check `.env` file
- [ ] Database connection failed → Check `DATABASE_URL`
- [ ] File upload failed → Check S3/R2 credentials
- [ ] High memory usage → Restart PM2 with lower limit
- [ ] SSL errors → Renew certificate in CloudPanel
- [ ] 502 Bad Gateway → Check PM2 status and nginx config

## Documentation

### Required Documentation
- [ ] API documentation updated
- [ ] Environment variables documented
- [ ] Deployment procedure documented
- [ ] Rollback procedure documented
- [ ] Troubleshooting guide updated
- [ ] Changelog maintained

## Sign-off

### Deployment Approved By
- [ ] Developer: _______________
- [ ] DevOps: _______________
- [ ] Project Manager: _______________

### Deployment Date
- Date: _______________
- Time: _______________
- Deployed Version: _______________
- Deployed By: _______________

### Notes
```
Add any special notes or issues encountered during deployment:




```

---

**Pro Tip**: Keep this checklist updated as your deployment process evolves!

