import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// A test screen to debug Firebase Authentication and Realtime Database connectivity
class FirebaseDebugTest extends StatefulWidget {
  const FirebaseDebugTest({super.key});

  @override
  State<FirebaseDebugTest> createState() => _FirebaseDebugTestState();
}

class _FirebaseDebugTestState extends State<FirebaseDebugTest> {
  // Current status message shown on screen
  String _status = 'Testing...';
  // Whether the test is currently running
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Start the Firebase test when the widget is initialized
    _testFirebaseConnection();
  }

  // Method to test Firebase Authentication and Database connection
  Future<void> _testFirebaseConnection() async {
    try {
      setState(() {
        _status = 'Testing Firebase Auth...';
      });

      // Get the FirebaseAuth instance
      final auth = FirebaseAuth.instance;
      // Check the currently signed-in user (if any)
      final currentUser = auth.currentUser;

      // Update status message with Auth state
      setState(() {
        _status = 'Auth Status: ${currentUser != null ? "Signed in as ${currentUser.email}" : "Not signed in"}';
      });

      // Start testing Realtime Database connection
      setState(() {
        _status += '\nTesting Firebase Database...';
      });

      // Get the FirebaseDatabase instance
      final database = FirebaseDatabase.instance;
      // Reference to a test node
      final testRef = database.ref('test/connection');

      // Write a test message to database
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Connection test from Flutter Web',
      });

      // Read the test message back
      final snapshot = await testRef.once();
      if (snapshot.snapshot.exists) {
        // Database connection successful
        setState(() {
          _status += '\n✅ Database connection successful!';
          _isLoading = false;
        });
      } else {
        // Database connection failed
        setState(() {
          _status += '\n❌ Database connection failed!';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle any errors during testing
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
              // Show progress indicator while testing
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              // Show current status messages
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Button to re-run the test
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





// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
//
// class FirebaseDebugTest extends StatefulWidget {
//   const FirebaseDebugTest({super.key});
//
//   @override
//   State<FirebaseDebugTest> createState() => _FirebaseDebugTestState();
// }
//
// class _FirebaseDebugTestState extends State<FirebaseDebugTest> {
//   String _status = 'Testing...';
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _testFirebaseConnection();
//   }
//
//   Future<void> _testFirebaseConnection() async {
//     try {
//       setState(() {
//         _status = 'Testing Firebase Auth...';
//       });
//
//       // Test Firebase Auth
//       final auth = FirebaseAuth.instance;
//       final currentUser = auth.currentUser;
//
//       setState(() {
//         _status = 'Auth Status: ${currentUser != null ? "Signed in as ${currentUser.email}" : "Not signed in"}';
//       });
//
//       // Test Firebase Database
//       setState(() {
//         _status += '\nTesting Firebase Database...';
//       });
//
//       final database = FirebaseDatabase.instance;
//       final testRef = database.ref('test/connection');
//
//       await testRef.set({
//         'timestamp': DateTime.now().millisecondsSinceEpoch,
//         'message': 'Connection test from Flutter Web',
//       });
//
//       final snapshot = await testRef.once();
//       if (snapshot.snapshot.exists) {
//         setState(() {
//           _status += '\n✅ Database connection successful!';
//           _isLoading = false;
//         });
//       } else {
//         setState(() {
//           _status += '\n❌ Database connection failed!';
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _status += '\n❌ Error: $e';
//         _isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Firebase Debug Test'),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               if (_isLoading) const CircularProgressIndicator(),
//               const SizedBox(height: 20),
//               Text(
//                 _status,
//                 style: const TextStyle(fontSize: 16),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: _testFirebaseConnection,
//                 child: const Text('Test Again'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
