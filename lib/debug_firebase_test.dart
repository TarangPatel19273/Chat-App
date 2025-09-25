import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseDebugTest extends StatefulWidget {
  const FirebaseDebugTest({super.key});

  @override
  State<FirebaseDebugTest> createState() => _FirebaseDebugTestState();
}

class _FirebaseDebugTestState extends State<FirebaseDebugTest> {
  String _status = 'Testing...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testFirebaseConnection();
  }

  Future<void> _testFirebaseConnection() async {
    try {
      setState(() {
        _status = 'Testing Firebase Auth...';
      });

      // Test Firebase Auth
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;
      
      setState(() {
        _status = 'Auth Status: ${currentUser != null ? "Signed in as ${currentUser.email}" : "Not signed in"}';
      });

      // Test Firebase Database
      setState(() {
        _status += '\nTesting Firebase Database...';
      });

      final database = FirebaseDatabase.instance;
      final testRef = database.ref('test/connection');
      
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Connection test from Flutter Web',
      });

      final snapshot = await testRef.once();
      if (snapshot.snapshot.exists) {
        setState(() {
          _status += '\n✅ Database connection successful!';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status += '\n❌ Database connection failed!';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status += '\n❌ Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Debug Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testFirebaseConnection,
                child: const Text('Test Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
