#!/bin/bash

# Blue Video Backend Deployment Script
# This script helps with manual deployment to CloudPanel VPS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_USER="${VPS_USER:-cloudpanel}"
VPS_HOST="${VPS_HOST}"
VPS_PORT="${VPS_PORT:-22}"
DEPLOY_PATH="${DEPLOY_PATH:-/home/cloudpanel/htdocs/api.example.com}"
PM2_APP_NAME="${PM2_APP_NAME:-blue-video-backend}"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_requirements() {
    log_info "Checking requirements..."
    
    if [ -z "$VPS_HOST" ]; then
        log_error "VPS_HOST environment variable is not set"
        log_info "Usage: VPS_HOST=your-vps-ip ./deploy.sh"
        exit 1
    fi
    
    if ! command -v ssh &> /dev/null; then
        log_error "ssh command not found. Please install OpenSSH client"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm command not found. Please install Node.js"
        exit 1
    fi
    
    log_success "All requirements met"
}

build_project() {
    log_info "Building project..."
    
    # Install dependencies
    npm ci --production=false
    
    # Generate Prisma client
    npx prisma generate
    
    # Build TypeScript
    npm run build
    
    log_success "Project built successfully"
}

create_deployment_package() {
    log_info "Creating deployment package..."
    
    # Clean previous package
    rm -rf deploy
    rm -f backend-deploy.tar.gz
    
    # Create deployment directory
    mkdir -p deploy
    
    # Copy essential files
    cp -r dist deploy/
    cp -r node_modules deploy/
    cp -r prisma deploy/
    cp package*.json deploy/
    cp tsconfig.json deploy/
    
    # Copy environment file template
    if [ -f .env.example ]; then
        cp .env.example deploy/.env.example
    fi
    
    # Create PM2 ecosystem file if it exists
    if [ -f ecosystem.config.js ]; then
        cp ecosystem.config.js deploy/
    fi
    
    # Create tarball
    cd deploy
    tar -czf ../backend-deploy.tar.gz .
    cd ..
    
    # Get file size
    FILE_SIZE=$(du -h backend-deploy.tar.gz | cut -f1)
    
    log_success "Deployment package created: backend-deploy.tar.gz ($FILE_SIZE)"
}

upload_to_vps() {
    log_info "Uploading to VPS..."
    
    scp -P "$VPS_PORT" backend-deploy.tar.gz "$VPS_USER@$VPS_HOST:/tmp/"
    
    log_success "Upload complete"
}

deploy_on_vps() {
    log_info "Deploying on VPS..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        set -e
        
        echo "🚀 Starting deployment..."
        
        # Navigate to deployment directory
        cd "$DEPLOY_PATH"
        
        # Backup current deployment
        if [ -d "current" ]; then
            echo "📦 Creating backup..."
            BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p backups
            mv current "backups/$BACKUP_DIR"
            echo "✅ Backup created: backups/$BACKUP_DIR"
        fi
        
        # Extract new deployment
        echo "📂 Extracting new deployment..."
        mkdir -p current
        tar -xzf /tmp/backend-deploy.tar.gz -C current/
        rm /tmp/backend-deploy.tar.gz
        
        # Navigate to current deployment
        cd current
        
        # Preserve .env file
        if [ -f "../backups/$(ls -t ../backups | head -1)/.env" ]; then
            echo "🔧 Copying .env from backup..."
            cp "../backups/$(ls -t ../backups | head -1)/.env" .env
        elif [ ! -f ".env" ]; then
            echo "⚠️  .env file not found!"
            if [ -f ".env.example" ]; then
                cp .env.example .env
                echo "📝 Created .env from .env.example - UPDATE WITH REAL VALUES!"
            fi
        fi
        
        # Install production dependencies
        echo "📦 Installing production dependencies..."
        npm ci --production
        
        # Run database migrations
        echo "🗄️  Running database migrations..."
        npx prisma migrate deploy || echo "⚠️  Migration failed or no migrations to run"
        
        # Generate Prisma client
        echo "🔨 Generating Prisma client..."
        npx prisma generate
        
        # Create logs directory
        mkdir -p logs
        
        # Restart application with PM2
        echo "🔄 Restarting application..."
        
        if ! command -v pm2 &> /dev/null; then
            echo "❌ PM2 is not installed. Installing globally..."
            npm install -g pm2
        fi
        
        if pm2 describe "$PM2_APP_NAME" > /dev/null 2>&1; then
            echo "🔄 Reloading existing PM2 process..."
            pm2 reload "$PM2_APP_NAME" --update-env
        else
            if [ -f "ecosystem.config.js" ]; then
                echo "🚀 Starting PM2 with ecosystem config..."
                pm2 start ecosystem.config.js --env production
            else
                echo "🚀 Starting new PM2 process..."
                pm2 start dist/server.js --name "$PM2_APP_NAME" \
                    --time \
                    --instances 2 \
                    --exec-mode cluster \
                    --max-memory-restart 500M \
                    --env production
            fi
        fi
        
        # Save PM2 configuration
        pm2 save
        
        # Display application status
        echo "✅ Deployment completed!"
        pm2 status
        
        # Keep only last 5 backups
        echo "🧹 Cleaning old backups..."
        cd ../backups
        ls -t | tail -n +6 | xargs -r rm -rf
        
        echo "🎉 Deployment successful!"
ENDSSH
    
    log_success "Deployment on VPS complete"
}

health_check() {
    log_info "Performing health check..."
    
    sleep 5
    
    # Perform health check via SSH
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        MAX_RETRIES=5
        RETRY_COUNT=0
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
            if curl -f -s "http://localhost:3000/health" > /dev/null; then
                echo "✅ Health check passed!"
                curl -s "http://localhost:3000/health" | python3 -m json.tool 2>/dev/null || curl -s "http://localhost:3000/health"
                exit 0
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                echo "⏳ Health check attempt $RETRY_COUNT/$MAX_RETRIES failed. Retrying in 3s..."
                sleep 3
            fi
        done
        
        echo "❌ Health check failed after $MAX_RETRIES attempts"
        echo "Recent logs:"
        pm2 logs "$PM2_APP_NAME" --lines 30 --nostream
        exit 1
ENDSSH
    
    if [ $? -eq 0 ]; then
        log_success "Health check passed"
    else
        log_error "Health check failed"
        exit 1
    fi
}

cleanup() {
    log_info "Cleaning up..."
    
    rm -rf deploy
    rm -f backend-deploy.tar.gz
    
    log_success "Cleanup complete"
}

show_logs() {
    log_info "Fetching recent logs..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" "pm2 logs $PM2_APP_NAME --lines 50 --nostream"
}

rollback() {
    log_warning "Rolling back to previous deployment..."
    
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" bash << 'ENDSSH'
        cd "$DEPLOY_PATH"
        
        if [ ! -d "backups" ] || [ -z "$(ls -A backups)" ]; then
            echo "❌ No backups available for rollback"
            exit 1
        fi
        
        LATEST_BACKUP=$(ls -t backups | head -1)
        echo "📦 Rolling back to: $LATEST_BACKUP"
        
        # Backup current (failed) deployment
        if [ -d "current" ]; then
            mv current "backups/failed-$(date +%Y%m%d-%H%M%S)"
        fi
        
        # Restore from backup
        cp -r "backups/$LATEST_BACKUP" current
        
        # Restart PM2
        cd current
        pm2 restart "$PM2_APP_NAME"
        
        echo "✅ Rollback complete"
        pm2 status
ENDSSH
    
    log_success "Rollback complete"
}

# Main deployment flow
main() {
    echo ""
    log_info "Blue Video Backend Deployment"
    echo "======================================"
    echo ""
    
    case "${1:-deploy}" in
        deploy)
            check_requirements
            build_project
            create_deployment_package
            upload_to_vps
            deploy_on_vps
            health_check
            cleanup
            echo ""
            log_success "🎉 Deployment completed successfully!"
            ;;
        logs)
            show_logs
            ;;
        rollback)
            rollback
            ;;
        health)
            health_check
            ;;
        *)
            echo "Usage: $0 {deploy|logs|rollback|health}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the backend to VPS (default)"
            echo "  logs     - Show recent application logs"
            echo "  rollback - Rollback to previous deployment"
            echo "  health   - Perform health check"
            echo ""
            echo "Environment variables:"
            echo "  VPS_HOST       - VPS IP address or hostname (required)"
            echo "  VPS_USER       - SSH username (default: cloudpanel)"
            echo "  VPS_PORT       - SSH port (default: 22)"
            echo "  DEPLOY_PATH    - Deployment path (default: /home/cloudpanel/htdocs/api.example.com)"
            echo "  PM2_APP_NAME   - PM2 application name (default: blue-video-backend)"
            echo ""
            echo "Example:"
            echo "  VPS_HOST=123.45.67.89 ./deploy.sh deploy"
            echo "  VPS_HOST=vps.example.com VPS_USER=ubuntu ./deploy.sh logs"
            exit 1
            ;;
    esac
}

main "$@"

