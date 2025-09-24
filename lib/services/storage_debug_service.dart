import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class StorageDebugService {
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(bucket: 'gs://chat-app-1ca15.GeoFirestore.app');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> debugStorageConfiguration() async {
    print('=== Firebase Storage Debug Info ===');
    print('Expected bucket: gs://chat-app-1ca15.firebasestorage.app');
    
    try {
      // Check storage instance
      print('Storage app: ${_storage.app.name}');
      print('Configured bucket: ${_storage.bucket}');
      print('Bucket URL: gs://${_storage.bucket}');
      
      // Check if bucket exists
      if (_storage.bucket.isEmpty) {
        print('ERROR: Storage bucket is empty! Firebase Storage not configured.');
        return;
      }
      
      // Check authentication
      final user = _auth.currentUser;
      print('Current user: ${user?.uid ?? "Not authenticated"}');
      print('User email: ${user?.email ?? "No email"}');
      
      if (user == null) {
        print('ERROR: User not authenticated! Please login first.');
        return;
      }
      
      // Test basic storage access
      final testRef = _storage.ref().child('test');
      print('Test reference created: ${testRef.fullPath}');
      
      // Try to get metadata (this will fail if bucket doesn't exist)
      try {
        await testRef.getMetadata();
        print('Storage bucket exists and is accessible');
      } catch (metaError) {
        if (metaError.toString().contains('object-not-found')) {
          print('Storage bucket exists but test file not found (this is normal)');
        } else {
          print('Storage bucket access error: $metaError');
        }
      }
      
      // Try to list files in root (this will fail if no read access but gives us error info)
      try {
        final ListResult result = await _storage.ref().list(const ListOptions(maxResults: 1));
        print('Root directory accessible, found ${result.items.length} items');
        print('Storage is properly configured!');
      } catch (e) {
        if (e.toString().contains('bucket') && e.toString().contains('not found')) {
          print('CRITICAL ERROR: Storage bucket does not exist!');
          print('Solution: Enable Firebase Storage in Firebase Console');
        } else {
          print('Root directory access failed: $e');
        }
      }
      
    } catch (e) {
      print('Storage debug error: $e');
      if (e.toString().contains('bucket')) {
        print('SOLUTION: Go to Firebase Console > Storage > Get Started');
      }
    }
    
    print('=== End Debug Info ===');
  }
  
  Future<void> testImageUpload(File imageFile) async {
    print('=== Testing Image Upload ===');
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      // Check file
      print('File path: ${imageFile.path}');
      print('File exists: ${await imageFile.exists()}');
      print('File size: ${await imageFile.length()} bytes');
      
      // Test upload to a simple path first
      final String testPath = 'test_upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('Test upload path: $testPath');
      
      final Reference ref = _storage.ref().child(testPath);
      print('Reference created: ${ref.fullPath}');
      
      // Try upload
      final UploadTask task = ref.putFile(imageFile);
      print('Upload task started');
      
      final TaskSnapshot snapshot = await task;
      print('Upload completed: ${snapshot.state}');
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL: $downloadUrl');
      
      // Clean up test file
      await snapshot.ref.delete();
      print('Test file cleaned up');
      
    } catch (e) {
      print('Test upload failed: $e');
      print('Stack trace: ${StackTrace.current}');
    }
    
    print('=== End Test Upload ===');
  }
  
  /// Comprehensive storage test - tests all aspects
  Future<void> fullStorageTest() async {
    print('\n🔬 === COMPREHENSIVE STORAGE TEST ===');
    
    try {
      // Step 1: Configuration check
      print('\n📋 Step 1: Configuration Check');
      await debugStorageConfiguration();
      
      // Step 2: Authentication check
      print('\n🔐 Step 2: Authentication Check');
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ ERROR: Not authenticated! Please login first.');
        return;
      }
      print('✅ User authenticated: ${user.email}');
      
      // Step 3: Basic connectivity test
      print('\n🌐 Step 3: Storage Connectivity Test');
      try {
        final testRef = _storage.ref().child('connectivity_test.txt');
        print('✅ Can create storage reference');
        
        // Try to upload a simple text file
        final testData = 'Storage test - ${DateTime.now().toIso8601String()}';
        await testRef.putString(testData);
        print('✅ Successfully uploaded test data');
        
        // Try to download it back
        final downloadedData = await testRef.getData();
        if (downloadedData != null) {
          print('✅ Successfully downloaded test data');
        }
        
        // Get download URL
        final downloadUrl = await testRef.getDownloadURL();
        print('✅ Got download URL: ${downloadUrl.substring(0, 50)}...');
        
        // Clean up
        await testRef.delete();
        print('✅ Test cleanup completed');
        
        print('\n🎉 ALL TESTS PASSED! Storage is working correctly.');
        
      } catch (storageError) {
        print('❌ Storage test failed: $storageError');
        
        if (storageError.toString().contains('object-not-found')) {
          print('💡 This might mean the bucket exists but has restrictive rules.');
        } else if (storageError.toString().contains('unauthorized')) {
          print('💡 Permission denied - check storage rules.');
        }
      }
      
    } catch (e) {
      print('❌ Comprehensive test failed: $e');
    }
    
    print('\n🔬 === END COMPREHENSIVE TEST ===\n');
  }
}
