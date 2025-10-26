# Swagger API Documentation

## Overview

The Blue Video API now includes comprehensive OpenAPI 3.0 documentation powered by Swagger UI.

## What Was Added

### 1. **Swagger Packages Installed**
- `swagger-jsdoc` - Generates OpenAPI specification from JSDoc comments
- `swagger-ui-express` - Serves interactive Swagger UI
- `@types/swagger-jsdoc` - TypeScript types
- `@types/swagger-ui-express` - TypeScript types

### 2. **Swagger Configuration** (`src/config/swagger.ts`)
- OpenAPI 3.0 specification
- API metadata (title, description, version)
- Server configurations (development and production)
- Security schemes (JWT Bearer authentication)
- Reusable schemas for common data types:
  - User
  - Video
  - Post
  - Category
  - Comment
  - ChatRoom
  - CoinPackage
- Tagged endpoints by category:
  - Health
  - Authentication
  - Users
  - Videos
  - Categories
  - Community
  - Comments
  - Search
  - Chat
  - Social
  - Payment
  - Playlists
  - Files
  - VIP

### 3. **Swagger UI Integration** (`src/server-local.ts`)
- Added Swagger UI at `/api-docs`
- Added OpenAPI JSON endpoint at `/api-docs.json`
- Removed mock test endpoint (`/api/v1/test`)
- Updated startup console logs to highlight documentation

### 4. **Documentation Example**
The health check endpoint now includes Swagger JSDoc comments:

```typescript
/**
 * @swagger
 * /health:
 *   get:
 *     tags: [Health]
 *     summary: Health check endpoint
 *     description: Returns the health status of the API server
 *     responses:
 *       200:
 *         description: API is running successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 timestamp:
 *                   type: string
 */
```

## Accessing the Documentation

### Local Development
Once you start the server:

```bash
npm run dev
```

Visit:
- **Swagger UI**: http://localhost:3000/api-docs
- **OpenAPI JSON**: http://localhost:3000/api-docs.json

### Production
- **Swagger UI**: https://api.onlybl.com/api-docs
- **OpenAPI JSON**: https://api.onlybl.com/api-docs.json

## How to Document Endpoints

To document your API endpoints, add JSDoc comments above each route handler:

```typescript
/**
 * @swagger
 * /api/v1/auth/login:
 *   post:
 *     tags: [Authentication]
 *     summary: User login
 *     description: Authenticate user with email and password
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: password123
 *               rememberMe:
 *                 type: boolean
 *                 example: false
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     token:
 *                       type: string
 *                       description: JWT access token
 *                     refreshToken:
 *                       type: string
 *                       description: JWT refresh token
 *                     user:
 *                       $ref: '#/components/schemas/User'
 *       401:
 *         description: Invalid credentials
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *     security: []
 */
app.post('/api/v1/auth/login', async (req, res) => {
  // ... implementation
});
```

### For Protected Endpoints

Add security requirements for endpoints that require authentication:

```typescript
/**
 * @swagger
 * /api/v1/users/profile:
 *   get:
 *     tags: [Users]
 *     summary: Get current user profile
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved successfully
 *       401:
 *         description: Unauthorized
 */
```

## Reusing Schemas

Instead of defining schemas inline, reference the common schemas defined in `swagger.ts`:

```typescript
/**
 * @swagger
 * /api/v1/videos/{id}:
 *   get:
 *     responses:
 *       200:
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   $ref: '#/components/schemas/Video'
 */
```

## Next Steps

### Current Status
✅ Swagger configuration created  
✅ Swagger UI integrated  
✅ Mock endpoints removed  
✅ Health endpoint documented  
✅ Build successful  

### To Complete Full Documentation
The following endpoints still need JSDoc Swagger comments added:

1. **Authentication** (8 endpoints)
   - `/api/v1/auth/login` ✅ (example provided above)
   - `/api/v1/auth/register`
   - `/api/v1/auth/logout`
   - `/api/v1/auth/forgot-password`
   - `/api/v1/auth/reset-password`
   - etc.

2. **Videos** (15+ endpoints)
3. **Community/Posts** (10+ endpoints)
4. **Users** (10+ endpoints)
5. **Chat** (6 endpoints)
6. **Search** (3 endpoints)
7. **Payment** (8 endpoints)
8. **Social** (10+ endpoints)
9. **Playlists** (5 endpoints)
10. **VIP** (4 endpoints)

### Gradual Documentation Approach
You don't need to document everything at once. The Swagger UI will:
- Show all endpoints that have JSDoc comments
- Hide endpoints that don't have documentation yet

Start with the most important endpoints (auth, videos, posts) and add more over time.

## Benefits

1. **Interactive API Testing**: Test endpoints directly from the browser
2. **Automatic Documentation**: Documentation stays in sync with code
3. **Client Code Generation**: Generate client SDKs in multiple languages
4. **Better Onboarding**: New developers can explore the API easily
5. **No More Mock Endpoints**: Real API with proper documentation

## Configuration Files Modified

1. `backend/src/config/swagger.ts` - New file with OpenAPI configuration
2. `backend/src/server-local.ts` - Integrated Swagger UI middleware
3. `backend/package.json` - Added Swagger dependencies

## Deployment

The Swagger documentation will automatically deploy with your backend:
- The `/api-docs` endpoint is available in production
- The deployment workflow already includes the swagger config in the build

## Troubleshooting

### Swagger UI not loading
- Check that `swagger-ui-express` is installed
- Verify the server started successfully
- Check browser console for errors

### Endpoint not showing in Swagger
- Make sure JSDoc comments use the `@swagger` tag
- Verify the file path is included in `swagger.ts` `apis` array
- Check that the JSDoc syntax is valid YAML

### Authentication not working in Swagger UI
1. Click the "Authorize" button in Swagger UI
2. Enter your JWT token in the format: `Bearer your_token_here`
3. Click "Authorize"

## Resources

- [Swagger/OpenAPI Specification](https://swagger.io/specification/)
- [swagger-jsdoc Documentation](https://github.com/Surnet/swagger-jsdoc)
- [Swagger UI Express](https://github.com/scottie1984/swagger-ui-express)
- [OpenAPI 3.0 Tutorial](https://swagger.io/docs/specification/about/)

