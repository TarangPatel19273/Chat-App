import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully!');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
  
  runApp(TestFirebaseApp());
}

class TestFirebaseApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Test',
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String status = 'Testing Firebase connection...';
  
  @override
  void initState() {
    super.initState();
    testFirebaseConnection();
  }
  
  Future<void> testFirebaseConnection() async {
    try {
      // Test basic Firebase connection
      final database = FirebaseDatabase.instance.ref();
      
      // Try to read from database (without auth)
      final snapshot = await database.child('test').once();
      
      setState(() {
        status = '✅ Firebase connection successful!\nProject ID: ${DefaultFirebaseOptions.currentPlatform.projectId}';
      });
    } catch (e) {
      setState(() {
        status = '❌ Firebase connection failed:\n$e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Firebase Test'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud,
                size: 80,
                color: Colors.blue,
              ),
              SizedBox(height: 20),
              Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              Text(
                'API Key: ${DefaultFirebaseOptions.currentPlatform.apiKey.substring(0, 20)}...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
