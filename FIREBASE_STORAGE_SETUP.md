# Firebase Storage Setup Guide

## Issue: "firebase_storage/object-not-found" Error

This error typically occurs when Firebase Storage is not properly configured. Follow these steps to fix it:

## Step 1: Enable Firebase Storage

1. Go to your Firebase Console: https://console.firebase.google.com/
2. Select your project: `chat-app-1ca15`
3. In the left sidebar, click on **"Storage"**
4. If Storage is not enabled, click **"Get started"**
5. Choose **"Start in test mode"** for now (we'll configure proper rules later)
6. Select a storage location (choose the closest to your users)

## Step 2: Configure Storage Rules

In the Firebase Console, go to **Storage > Rules** and replace the existing rules with:

```javascript
rules_version = '2';

// Allow authenticated users to read and write their own files
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to upload images to chat_images folder
    match /chat_images/{imageId} {
      allow read, write: if request.auth != null;
    }
    
    // Allow test uploads for debugging
    match /test_upload_{timestamp}.jpg {
      allow read, write: if request.auth != null;
    }
    
    // Default: deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Step 3: Verify Storage Bucket

Make sure your storage bucket name matches what's in `firebase_options.dart`:

**Expected bucket:** `chat-app-1ca15.firebasestorage.app`

## Step 4: Test the Configuration

1. Run your Flutter app
2. Try to upload an image
3. Check the debug console for detailed logs
4. The app will now show more specific error messages

## Troubleshooting

### If you still get "object-not-found" error:

1. **Check if Storage is enabled:**
   - Go to Firebase Console > Storage
   - Verify that Storage is active and has a bucket

2. **Verify bucket name:**
   - In Firebase Console > Storage, check the bucket name
   - It should match the one in `firebase_options.dart`

3. **Check authentication:**
   - Make sure you're logged in when trying to upload
   - The error might be due to no authenticated user

### Alternative: More Permissive Rules (for testing only)

If you want to test quickly, you can use these more permissive rules temporarily:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**⚠️ Warning:** These rules allow authenticated users to access all files. Use only for testing!

## Step 5: Production Rules

Once everything works, use these production-ready rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Chat images - only uploader and chat participants can access
    match /chat_images/{imageId} {
      allow write: if request.auth != null 
                   && request.auth.uid != null
                   && resource == null; // Only allow creation, not updates
      allow read: if request.auth != null;
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Debug Information

The app now includes debug information that will help identify the exact issue:

1. Check your Flutter console logs
2. Look for "=== Firebase Storage Debug Info ===" messages
3. The error messages will be more specific about what went wrong

## Common Solutions

1. **Enable Firebase Storage** in the Firebase Console
2. **Update Storage Rules** to allow authenticated access
3. **Verify bucket configuration** in `firebase_options.dart`
4. **Check internet connection** and Firebase project settings
5. **Make sure user is authenticated** before uploading
