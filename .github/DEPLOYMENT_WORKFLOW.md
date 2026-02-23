# Deployment Workflow Diagram

## 🔄 Automated Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Developer Pushes Code                            │
│                    git push origin main                             │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Triggered                         │
│                    Workflow: deploy-backend.yml                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 1: Checkout Code                                              │
│  ✓ Clone repository                                                 │
│  ✓ Fetch all branches                                               │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 2: Setup Node.js Environment                                  │
│  ✓ Install Node.js 18.x                                             │
│  ✓ Setup npm cache                                                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 3: Build Application                                          │
│  ✓ npm ci --production=false                                        │
│  ✓ npx prisma generate                                              │
│  ✓ npm run build (TypeScript → JavaScript)                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 4: Create Deployment Package                                  │
│  ✓ Copy dist/, node_modules/, prisma/                               │
│  ✓ Copy package.json, tsconfig.json                                 │
│  ✓ Create tarball: backend-deploy.tar.gz                            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 5: Upload to VPS                                              │
│  ✓ Connect via SSH (using VPS_SSH_KEY)                              │
│  ✓ Upload tarball to /tmp/                                          │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 6: Deploy on VPS                                              │
│                                                                      │
│  6.1 Backup Current Version                                         │
│      ✓ mv current backups/backup-YYYYMMDD-HHMMSS                    │
│                                                                      │
│  6.2 Extract New Version                                            │
│      ✓ mkdir current                                                │
│      ✓ tar -xzf /tmp/backend-deploy.tar.gz -C current/              │
│                                                                      │
│  6.3 Preserve Environment                                           │
│      ✓ Copy .env from backup                                        │
│                                                                      │
│  6.4 Install Dependencies                                           │
│      ✓ npm ci --production                                          │
│                                                                      │
│  6.5 Run Database Migrations                                        │
│      ✓ npx prisma migrate deploy                                    │
│      ✓ npx prisma generate                                          │
│                                                                      │
│  6.6 Restart Application                                            │
│      ✓ pm2 reload blue-video-backend                                │
│      OR                                                              │
│      ✓ pm2 start ecosystem.config.js --env production               │
│                                                                      │
│  6.7 Save PM2 Configuration                                         │
│      ✓ pm2 save                                                     │
│                                                                      │
│  6.8 Cleanup Old Backups                                            │
│      ✓ Keep only last 5 backups                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Step 7: Health Check                                               │
│  ✓ Wait 10 seconds for app to start                                 │
│  ✓ Test health endpoint: GET /health                                │
│  ✓ Retry up to 5 times if failed                                    │
│  ✓ Verify response status: 200 OK                                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
                    ┌────────┴─────────┐
                    │                  │
                    ▼                  ▼
      ┌─────────────────┐  ┌──────────────────┐
      │  ✅ SUCCESS      │  │  ❌ FAILURE      │
      │                 │  │                  │
      │  • Notify       │  │  • Notify        │
      │  • Log success  │  │  • Log error     │
      │  • Display info │  │  • Show logs     │
      └─────────────────┘  │  • Manual check  │
                           └──────────────────┘
```

## 📦 Deployment Package Contents

```
backend-deploy.tar.gz
├── dist/                       # Compiled JavaScript files
│   ├── server.js
│   ├── config/
│   ├── controllers/
│   ├── middleware/
│   ├── models/
│   ├── routes/
│   ├── services/
│   └── utils/
├── node_modules/              # Production dependencies
├── prisma/                    # Database schema and migrations
│   ├── schema.prisma
│   └── migrations/
├── package.json
├── package-lock.json
├── tsconfig.json
├── ecosystem.config.js       # PM2 configuration
└── .env.example              # Environment template
```

## 🔀 Rollback Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Issue Detected                                   │
│                    (Manual or Automatic)                            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Option 1: GitHub Actions Rollback                                  │
│                                                                      │
│  1. Identify last working commit                                    │
│  2. git revert HEAD                                                 │
│  3. git push origin main                                            │
│  4. Automatic deployment of previous version                        │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Option 2: Manual VPS Rollback                                      │
│                                                                      │
│  1. SSH to VPS                                                      │
│  2. cd /home/cloudpanel/htdocs/api.example.com                      │
│  3. ls -lt backups/  (find latest backup)                           │
│  4. rm -rf current                                                  │
│  5. cp -r backups/backup-YYYYMMDD-HHMMSS current                    │
│  6. cd current && pm2 restart blue-video-backend                    │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Option 3: Script-based Rollback                                    │
│                                                                      │
│  VPS_HOST=your-vps-ip ./backend/deploy.sh rollback                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Verification                                                        │
│  ✓ Application is running                                           │
│  ✓ Health check passes                                              │
│  ✓ Critical endpoints working                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## 🏗️ VPS Directory Structure

```
/home/cloudpanel/htdocs/api.example.com/
│
├── current/                           # Active deployment
│   ├── dist/                         # Compiled application
│   ├── node_modules/                 # Dependencies
│   ├── prisma/                       # Database schema
│   ├── logs/                         # Application logs
│   │   ├── out.log                   # Standard output
│   │   └── err.log                   # Error output
│   ├── .env                          # Environment variables
│   ├── package.json
│   └── ecosystem.config.js           # PM2 config
│
└── backups/                          # Previous deployments
    ├── backup-20241023-120000/       # Backup 1
    ├── backup-20241023-140000/       # Backup 2
    ├── backup-20241023-160000/       # Backup 3
    ├── backup-20241023-180000/       # Backup 4
    └── backup-20241023-200000/       # Backup 5 (oldest kept)
```

## 🔍 Monitoring Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Application Running                              │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
         ┌───────────────────┴──────────────────┐
         │                                       │
         ▼                                       ▼
┌──────────────────┐                  ┌──────────────────┐
│   PM2 Monitor    │                  │  Health Endpoint │
│                  │                  │                  │
│  • CPU usage     │                  │  GET /health     │
│  • Memory usage  │                  │                  │
│  • Restart count │                  │  Response:       │
│  • Uptime        │                  │  {              │
│                  │                  │    status: OK    │
│  Command:        │                  │    uptime: 123s  │
│  pm2 monit       │                  │    version: v1   │
└──────────────────┘                  │  }              │
                                       └──────────────────┘
         │                                       │
         └───────────────────┬──────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│  Application Logs                                                   │
│                                                                      │
│  Standard Output: logs/out.log                                      │
│  Error Output: logs/err.log                                         │
│                                                                      │
│  View with:                                                         │
│  • pm2 logs blue-video-backend                                      │
│  • tail -f logs/out.log                                             │
│  • tail -f logs/err.log                                             │
└─────────────────────────────────────────────────────────────────────┘
```

## 🎯 Decision Tree: When to Deploy

```
                    Change Made to Code
                             │
                             ▼
                    Is it in backend/?
                             │
                   ┌─────────┴─────────┐
                   │                   │
                   ▼ YES               ▼ NO
         Push to main/production    No deployment
                   │                  needed
                   ▼
         GitHub Actions Triggered
                   │
                   ▼
            Is it urgent?
                   │
         ┌─────────┴─────────┐
         │                   │
         ▼ YES               ▼ NO
    Manual trigger      Wait for tests
    from Actions tab    to complete
         │                   │
         └─────────┬─────────┘
                   │
                   ▼
         All checks passed?
                   │
         ┌─────────┴─────────┐
         │                   │
         ▼ YES               ▼ NO
    Deploy to VPS       Fix issues
         │              Push again
         ▼
    Deployment Success?
         │
   ┌─────┴─────┐
   │           │
   ▼ YES       ▼ NO
  Done!     Rollback
            │
            ▼
         Fix issues
            │
            ▼
      Deploy again
```

## 📊 Performance Metrics

### Typical Deployment Times

```
Build Phase:                ~2-3 minutes
├── Install dependencies   ~1-2 min
├── Generate Prisma        ~10 sec
└── Build TypeScript       ~20 sec

Upload Phase:               ~30 seconds
└── Transfer tarball       ~30 sec (depends on size)

Deployment Phase:           ~1-2 minutes
├── Backup current         ~10 sec
├── Extract files          ~20 sec
├── Install dependencies   ~30 sec
├── Run migrations         ~10 sec
└── Restart PM2            ~20 sec

Health Check:               ~15 seconds
├── Wait for startup       ~10 sec
└── Test endpoint          ~5 sec

Total Deployment Time:      ~4-6 minutes
```

### Resource Usage

```
Development:
├── CPU: 10-20%
├── Memory: 200-300MB
└── Disk: ~500MB

Production (2 instances):
├── CPU: 20-40%
├── Memory: 400-600MB
└── Disk: ~1GB (with logs)
```

## 🎓 Best Practices

### ✅ DO

1. **Test locally before pushing**
   ```bash
   npm run build
   npm test
   ```

2. **Use feature branches**
   ```bash
   git checkout -b feature/new-feature
   git push origin feature/new-feature
   # Deploy only after PR review
   ```

3. **Monitor after deployment**
   ```bash
   pm2 logs blue-video-backend --lines 100
   curl https://api.example.com/health
   ```

4. **Keep backups**
   - Last 5 backups retained automatically
   - Manual backups before major changes

5. **Use staging environment**
   - Test on staging first
   - Deploy to production after verification

### ❌ DON'T

1. **Don't push directly to main**
   - Use pull requests
   - Get code review

2. **Don't skip testing**
   - Always test locally first
   - Run automated tests

3. **Don't ignore failed deployments**
   - Check logs immediately
   - Rollback if necessary

4. **Don't deploy during peak hours**
   - Schedule during low-traffic times
   - Unless it's a critical hotfix

5. **Don't ignore security**
   - Keep secrets secure
   - Rotate keys regularly
   - Monitor for vulnerabilities

---

**Last Updated**: October 2024  
**Version**: 1.0.0  
**Status**: Production Ready 🚀

