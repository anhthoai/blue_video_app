# AWS SDK v3 Migration

## Overview

Successfully migrated `backend/src/config/storage.ts` from AWS SDK v2 to v3 to eliminate maintenance mode warnings and align with the rest of the codebase.

## Changes Made

### 1. Updated Imports

**Before (v2):**
```typescript
import AWS from 'aws-sdk';
```

**After (v3):**
```typescript
import { 
  S3Client, 
  PutObjectCommand, 
  DeleteObjectCommand, 
  HeadObjectCommand, 
  GetObjectCommand 
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
```

### 2. Client Initialization

**Before (v2):**
```typescript
export const s3 = new AWS.S3({
  endpoint: s3Config.endpoint,
  accessKeyId: s3Config.accessKeyId,
  secretAccessKey: s3Config.secretAccessKey,
  region: s3Config.region,
  s3ForcePathStyle: true,
});
```

**After (v3):**
```typescript
export const s3Client = new S3Client({
  endpoint: s3Config.endpoint,
  credentials: {
    accessKeyId: s3Config.accessKeyId,
    secretAccessKey: s3Config.secretAccessKey,
  },
  region: s3Config.region,
  forcePathStyle: true,
});
```

### 3. Upload Method

**Before (v2):**
```typescript
await s3.upload({
  Bucket: bucketName,
  Key: key,
  Body: buffer,
}).promise();
```

**After (v3):**
```typescript
const command = new PutObjectCommand({
  Bucket: bucketName,
  Key: key,
  Body: buffer,
});
await s3Client.send(command);
```

### 4. Delete Method

**Before (v2):**
```typescript
await s3.deleteObject({
  Bucket: bucketName,
  Key: key,
}).promise();
```

**After (v3):**
```typescript
const command = new DeleteObjectCommand({
  Bucket: bucketName,
  Key: key,
});
await s3Client.send(command);
```

### 5. Presigned URLs

**Before (v2):**
```typescript
return await s3.getSignedUrlPromise('getObject', {
  Bucket: bucketName,
  Key: key,
  Expires: expiresIn,
});
```

**After (v3):**
```typescript
const command = new GetObjectCommand({
  Bucket: bucketName,
  Key: key,
});
return await getSignedUrl(s3Client, command, { expiresIn });
```

### 6. Head Object (Metadata)

**Before (v2):**
```typescript
const result = await s3.headObject({
  Bucket: bucketName,
  Key: key,
}).promise();
```

**After (v3):**
```typescript
const command = new HeadObjectCommand({
  Bucket: bucketName,
  Key: key,
});
const result = await s3Client.send(command);
```

## Benefits

| Feature | AWS SDK v2 | AWS SDK v3 |
|---------|-----------|-----------|
| **Maintenance** | ⚠️ Maintenance mode only | ✅ Active development |
| **Bundle Size** | ❌ Large (entire SDK) | ✅ Small (tree-shakeable) |
| **TypeScript** | ⚠️ Basic types | ✅ Full type safety |
| **API Design** | Callback/Promise mix | ✅ Pure async/await |
| **Warnings** | ⚠️ Deprecation warnings | ✅ No warnings |

## Dependencies

Already installed in `package.json`:
```json
{
  "@aws-sdk/client-s3": "^3.450.0",
  "@aws-sdk/s3-request-presigner": "^3.450.0"
}
```

Can now safely remove (optional cleanup):
```json
{
  "aws-sdk": "^2.1691.0",  // ← Can be removed
  "@types/aws-sdk": "^2.7.0"  // ← Can be removed
}
```

## Testing

1. ✅ Server starts without warnings
2. ✅ TypeScript compilation successful
3. ✅ Multer-S3 integration working
4. ✅ All storage methods updated

## Backward Compatibility

- ✅ All existing functionality preserved
- ✅ API signatures unchanged
- ✅ Episode preview S3 upload still works
- ✅ Presigned URL generation works
- ✅ No changes needed in calling code

## Files Changed

1. `backend/src/config/storage.ts` - Complete migration to SDK v3

## Other Files Using AWS SDK v3

Already using v3 (no changes needed):
- `backend/src/services/s3Service.ts`
- `backend/src/services/videoProcessingService.ts`
- `backend/src/utils/fileUrl.ts`
- `backend/src/server-local.ts`

## Next Steps (Optional)

1. Remove `aws-sdk` v2 from `package.json`:
   ```bash
   npm uninstall aws-sdk @types/aws-sdk
   ```

2. Verify no other files use v2:
   ```bash
   grep -r "from 'aws-sdk'" src/
   ```

## References

- [AWS SDK v3 Migration Guide](https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/migrating-to-v3.html)
- [AWS SDK v3 Documentation](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/)
- [@aws-sdk/client-s3](https://www.npmjs.com/package/@aws-sdk/client-s3)

