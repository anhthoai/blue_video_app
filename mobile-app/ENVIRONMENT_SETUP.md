# Environment Configuration Guide

## Overview
The Flutter app uses environment variables to configure API endpoints for different environments (development, staging, production).

## Environment Variables

### API Configuration
- `API_BASE_URL`: Base URL for REST API endpoints
- `API_SOCKET_URL`: WebSocket URL for real-time features

## Configuration Files

### `.env` File
Located at `blue_video_app/mobile-app/.env`

```env
# API Configuration
API_BASE_URL=http://192.168.1.100:3000/api/v1
API_SOCKET_URL=http://192.168.1.100:3000

# For production, change to your domain:
# API_BASE_URL=https://api.yourapp.com/api/v1
# API_SOCKET_URL=https://api.yourapp.com

# For local development with emulator:
# API_BASE_URL=http://10.0.2.2:3000/api/v1
# API_SOCKET_URL=http://10.0.2.2:3000
```

## Environment Setup

### Development (Local Network)
```env
API_BASE_URL=http://192.168.1.100:3000/api/v1
API_SOCKET_URL=http://192.168.1.100:3000
```
- Use your computer's local IP address
- Make sure both devices are on the same network
- Backend server must be running on the specified port

### Android Emulator
```env
API_BASE_URL=http://10.0.2.2:3000/api/v1
API_SOCKET_URL=http://10.0.2.2:3000
```
- `10.0.2.2` is the special IP that Android emulator uses to access the host machine's localhost

### Production
```env
API_BASE_URL=https://api.yourapp.com/api/v1
API_SOCKET_URL=https://api.yourapp.com
```
- Use your production domain
- Ensure HTTPS is configured
- Update CORS settings on the backend

## Finding Your Local IP Address

### Windows
```cmd
ipconfig
```
Look for "IPv4 Address" under your network adapter.

### macOS/Linux
```bash
ifconfig
```
Look for "inet" address under your network interface.

## Backend Configuration

### CORS Settings
Update your backend `.env` file:
```env
CORS_ORIGIN=http://192.168.1.100:3000,http://localhost:8080
SOCKET_CORS_ORIGIN=http://192.168.1.100:3000,http://localhost:8080
```

### Network Access
Make sure your backend server is accessible from the network:
1. Check firewall settings
2. Ensure the server binds to `0.0.0.0:3000` (not just `localhost:3000`)
3. Test with `curl http://YOUR_IP:3000/health` from another device

## Testing Connectivity

### From Mobile Device
1. Open a browser on your mobile device
2. Navigate to `http://YOUR_IP:3000/health`
3. You should see the API health response

### From Flutter App
The app will automatically use the configured URLs from the `.env` file.

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Check if backend server is running
   - Verify IP address is correct
   - Check firewall settings

2. **CORS Errors**
   - Update backend CORS settings
   - Add your mobile device IP to allowed origins

3. **Network Unreachable**
   - Ensure both devices are on the same network
   - Check router settings
   - Try using mobile hotspot

### Debug Steps

1. **Test Backend Directly**
   ```bash
   curl http://YOUR_IP:3000/health
   ```

2. **Check Flutter App Logs**
   ```bash
   flutter logs
   ```

3. **Verify Environment Loading**
   Add debug prints in `main.dart`:
   ```dart
   print('API_BASE_URL: ${dotenv.env['API_BASE_URL']}');
   print('API_SOCKET_URL: ${dotenv.env['API_SOCKET_URL']}');
   ```

## Security Notes

- Never commit production API keys to version control
- Use different `.env` files for different environments
- Consider using environment-specific configuration files
- Implement proper authentication and HTTPS in production

## File Structure
```
blue_video_app/mobile-app/
├── .env                    # Environment variables
├── lib/
│   └── core/
│       └── services/
│           └── api_service.dart  # Uses environment variables
└── pubspec.yaml           # Includes flutter_dotenv dependency
```
