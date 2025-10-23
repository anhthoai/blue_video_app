# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the Blue Video project.

## Available Workflows

### 1. Deploy Backend to CloudPanel VPS
**File**: `deploy-backend.yml`

Automatically deploys the backend application to your CloudPanel VPS when code is pushed to `main` or `production` branches.

#### Triggers
- Push to `main` or `production` branch (when backend files change)
- Manual workflow dispatch from GitHub Actions tab

#### What it does
1. ✅ Checks out code
2. ✅ Sets up Node.js environment
3. ✅ Installs dependencies
4. ✅ Generates Prisma client
5. ✅ Builds TypeScript to JavaScript
6. ✅ Creates deployment package
7. ✅ Uploads to VPS via SSH
8. ✅ Backs up current deployment
9. ✅ Extracts new files
10. ✅ Runs database migrations
11. ✅ Restarts application with PM2
12. ✅ Performs health check
13. ✅ Notifies on success/failure

## Setup Instructions

### 1. Configure GitHub Secrets

Go to your repository: **Settings → Secrets and variables → Actions**

Click **New repository secret** and add each of these:

| Secret Name | Description | Where to find it |
|------------|-------------|------------------|
| `VPS_HOST` | Your VPS IP or domain | From your hosting provider |
| `VPS_USERNAME` | SSH username | Usually `cloudpanel` |
| `VPS_SSH_KEY` | Private SSH key | Generate with `ssh-keygen` |
| `VPS_SSH_PORT` | SSH port (optional) | Default is `22` |
| `API_URL` | Your API base URL | e.g., `https://api.example.com` |

#### How to generate and add SSH key:

**On your local machine** (Linux/Mac/WSL):
```bash
# Generate SSH key pair
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions_deploy

# Copy public key to VPS
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub cloudpanel@YOUR_VPS_IP

# Display private key (copy this to GitHub Secrets)
cat ~/.ssh/github_actions_deploy
```

**On Windows** (using PowerShell):
```powershell
# Generate SSH key pair
ssh-keygen -t ed25519 -C "github-actions" -f $env:USERPROFILE\.ssh\github_actions_deploy

# Copy public key to VPS (manual step - copy content and add to VPS ~/.ssh/authorized_keys)
Get-Content $env:USERPROFILE\.ssh\github_actions_deploy.pub

# Display private key (copy this to GitHub Secrets)
Get-Content $env:USERPROFILE\.ssh\github_actions_deploy
```

### 2. Update Workflow Configuration

Edit `.github/workflows/deploy-backend.yml`:

```yaml
env:
  NODE_VERSION: '18.x'  # Update if needed
  DEPLOY_PATH: '/home/cloudpanel/htdocs/api.example.com'  # Update with your path
  PM2_APP_NAME: 'blue-video-backend'  # Update if needed
```

### 3. Commit and Push

```bash
git add .github/workflows/
git commit -m "Add GitHub Actions deployment workflow"
git push origin main
```

The workflow will automatically run on the next push to `main` or `production` branch.

## Manual Deployment

### Trigger from GitHub UI

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. Select **Deploy Backend to CloudPanel VPS** from the left sidebar
4. Click **Run workflow** button
5. Select branch (usually `main`)
6. Click **Run workflow**

### Using GitHub CLI

```bash
# Install GitHub CLI if needed: https://cli.github.com/

# Trigger workflow manually
gh workflow run deploy-backend.yml

# View workflow runs
gh run list --workflow=deploy-backend.yml

# View logs of latest run
gh run view
```

## Monitoring Deployments

### View Workflow Status

1. Go to **Actions** tab in your repository
2. Click on a workflow run to see detailed logs
3. Each step shows execution time and output

### Check Application Status on VPS

```bash
# SSH into your VPS
ssh cloudpanel@YOUR_VPS_IP

# Check PM2 status
pm2 status

# View logs
pm2 logs blue-video-backend --lines 100

# Monitor in real-time
pm2 monit
```

## Troubleshooting

### Workflow fails at "Deploy to VPS via SSH"

**Problem**: SSH connection failed

**Solutions**:
1. Verify `VPS_HOST` secret is correct
2. Verify `VPS_USERNAME` secret is correct
3. Verify `VPS_SSH_KEY` contains the complete private key (including BEGIN/END lines)
4. Verify SSH port is correct (default: 22)
5. Test SSH connection manually: `ssh -i ~/.ssh/github_actions_deploy cloudpanel@YOUR_VPS_IP`

### Workflow fails at "Health check"

**Problem**: Application not responding after deployment

**Solutions**:
1. Check application logs: `pm2 logs blue-video-backend`
2. Verify `.env` file exists on VPS with correct values
3. Check database connection
4. Verify port 3000 is not blocked by firewall
5. Restart application manually: `pm2 restart blue-video-backend`

### Workflow fails at "Build TypeScript"

**Problem**: Build errors

**Solutions**:
1. Test build locally: `npm run build`
2. Check for TypeScript errors in your code
3. Verify `tsconfig.json` is correct
4. Check Node.js version matches workflow

### Database migration fails

**Problem**: Prisma migrations fail during deployment

**Solutions**:
1. SSH to VPS and run migrations manually:
   ```bash
   cd /home/cloudpanel/htdocs/api.example.com/current
   npx prisma migrate deploy
   ```
2. Check database connection in `.env`
3. Verify PostgreSQL is running: `sudo systemctl status postgresql`
4. Check migration files in `prisma/migrations/`

## Rollback Procedure

If deployment fails or introduces issues:

### Option 1: Via GitHub Actions
1. Find the last successful deployment commit
2. Revert to that commit: `git revert HEAD`
3. Push to trigger automatic deployment

### Option 2: Manual rollback on VPS
```bash
ssh cloudpanel@YOUR_VPS_IP

cd /home/cloudpanel/htdocs/api.example.com

# List available backups
ls -lt backups/

# Restore from backup
rm -rf current
cp -r backups/backup-YYYYMMDD-HHMMSS current

# Restart application
cd current
pm2 restart blue-video-backend
```

### Option 3: Using deploy.sh script
```bash
# From your local machine
VPS_HOST=YOUR_VPS_IP ./backend/deploy.sh rollback
```

## Best Practices

### Before Deploying
- ✅ Test locally: `npm run build && npm start`
- ✅ Run tests: `npm test` (if available)
- ✅ Check for linting errors: `npm run lint`
- ✅ Review changes: `git diff`
- ✅ Update version in `package.json`

### After Deploying
- ✅ Monitor application logs for errors
- ✅ Test critical endpoints
- ✅ Check database for data integrity
- ✅ Verify file uploads work
- ✅ Test authentication flow

### Security
- 🔒 Never commit secrets to Git
- 🔒 Rotate SSH keys regularly
- 🔒 Use separate deployment keys (not personal SSH keys)
- 🔒 Limit VPS_USERNAME permissions
- 🔒 Enable 2FA on GitHub
- 🔒 Review workflow logs for sensitive data

### Performance
- ⚡ Use cache for npm packages
- ⚡ Minimize deployment package size
- ⚡ Enable gzip compression on nginx
- ⚡ Use PM2 cluster mode (already configured)
- ⚡ Monitor memory usage

## Customization

### Add Environment-Specific Deployments

Create multiple workflows for different environments:

- `deploy-backend-staging.yml` → Deploys to staging server
- `deploy-backend-production.yml` → Deploys to production server

### Add Pre-deployment Tests

Add before "Deploy to VPS":
```yaml
- name: Run tests
  run: |
    cd backend
    npm test

- name: Run lint
  run: |
    cd backend
    npm run lint
```

### Add Slack/Discord Notifications

Add after health check:
```yaml
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

### Add Database Backup Before Deployment

Add before "Deploy to VPS":
```yaml
- name: Backup database
  uses: appleboy/ssh-action@master
  with:
    host: ${{ secrets.VPS_HOST }}
    username: ${{ secrets.VPS_USERNAME }}
    key: ${{ secrets.VPS_SSH_KEY }}
    script: |
      pg_dump -U postgres blue_video_db > /backups/db-$(date +%Y%m%d-%H%M%S).sql
```

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [CloudPanel Documentation](https://www.cloudpanel.io/docs/)
- [PM2 Documentation](https://pm2.keymetrics.io/docs/usage/quick-start/)
- [Prisma Deployment Guides](https://www.prisma.io/docs/guides/deployment)

## Support

For issues related to:
- **GitHub Actions**: Check workflow logs and GitHub Actions status
- **CloudPanel**: Refer to CloudPanel documentation or support
- **Application errors**: Check PM2 logs and application code

---

**Last Updated**: October 2024  
**Version**: 1.0.0

