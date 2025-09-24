import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Your existing CloudinaryService (keep as-is)
class CloudinaryService {
  final String cloudName = "Root";
  final String uploadPreset = "FLUTTER UNSIGNED";

  Future<String?> uploadImage(File imageFile) async {
    // 🔴 BUG: Extra spaces in URL!
    // ❌ "https://api.cloudinary.com/v1_1/  $cloudName/image/upload"
    // ✅ Fix: Remove spaces
    final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

    final request = http.MultipartRequest("POST", url);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath("file", imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final data = json.decode(resStr);
      return data["secure_url"];
    } else {
      print("Upload failed: ${response.statusCode}");
      // Optional: print full error
      final errorStr = await response.stream.bytesToString();
      print("Cloudinary error: $errorStr");
      return null;
    }
  }
}

// ✅ Main upload function
Future<void> pickAndUploadImageToCloudinary() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile == null) return;

  try {
    // 🔹 Step 1: Upload to Cloudinary
    final cloudinary = CloudinaryService();
    final imageUrl = await cloudinary.uploadImage(File(pickedFile.path));

    if (imageUrl == null) {
      print("❌ Cloudinary upload failed");
      return;
    }

    print("✅ Uploaded Image URL: $imageUrl");

    // 🔹 Step 2: Save to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ No authenticated user");
      return;
    }

    // Save to Firestore collection (e.g., 'user_images' or 'posts')
    await FirebaseFirestore.instance.collection('user_images').add({
      'imageUrl': imageUrl,
      'uploadedAt': FieldValue.serverTimestamp(),
      'userId': user.uid,
      'fileName': pickedFile.name ?? 'unnamed',
    });

    print("✅ Image URL saved to Firestore!");

    // 🔹 Optional: Run debug services (comment out in production)
    // final debugStorage = StorageDebugService();
    // await debugStorage.debugStorageConfiguration();

    // final dbService = DatabaseService();
    // await dbService.verifyDatabaseConnection();

  } catch (e) {
    print("❌ Full error during upload/save: $e");
    // Show error to user in UI
  }
}