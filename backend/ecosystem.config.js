module.exports = {
  apps: [
    {
      name: 'blue-video-backend',
      script: './dist/server-local.js',
      instances: 2, // Use cluster mode with 2 instances
      exec_mode: 'cluster',
      
      // Environment variables
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      
      // Restart configuration
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      
      // Error handling
      max_restarts: 10,
      min_uptime: '10s',
      
      // Logging
      error_file: './logs/err.log',
      out_file: './logs/out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      
      // Process management
      kill_timeout: 5000,
      listen_timeout: 10000,
      shutdown_with_message: true,
      
      // Advanced features
      time: true, // Prefix logs with timestamps
      instance_var: 'INSTANCE_ID',
      
      // Health check
      wait_ready: true,
      listen_timeout: 30000,
      
      // Cron restart (optional - restart every day at 3 AM)
      // cron_restart: '0 3 * * *',
      
      // Environment-specific settings
      node_args: [
        '--max-old-space-size=512', // Limit memory usage
        '--optimize-for-size',
      ],
    },
  ],
  
  // Deployment configuration
  deploy: {
    production: {
      user: 'cloudpanel',
      host: process.env.VPS_HOST || 'YOUR_VPS_IP',
      ref: 'origin/main',
      repo: 'git@github.com:YOUR_USERNAME/YOUR_REPO.git',
      path: '/home/cloudpanel/htdocs/api.example.com',
      'post-deploy': [
        'cd backend',
        'npm install --production',
        'npx prisma generate',
        'npx prisma migrate deploy',
        'npm run build',
        'pm2 reload ecosystem.config.js --env production',
      ].join(' && '),
      'post-setup': [
        'npm install -g pm2',
        'pm2 install pm2-logrotate',
        'pm2 startup',
      ].join(' && '),
      env: {
        NODE_ENV: 'production',
      },
    },
  },
};

