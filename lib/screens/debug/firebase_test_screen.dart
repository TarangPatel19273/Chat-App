import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/database_service.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService();
  String _status = 'Ready to test';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _testFirebaseConnection() async {
    setState(() {
      _status = 'Testing Firebase connection...';
      _isLoading = true;
    });

    try {
      // Test Firebase Database connection
      final DatabaseReference database = FirebaseDatabase.instance.ref();
      await database.child('test').set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Firebase connection test'
      });
      
      setState(() {
        _status = 'Firebase Database: Connected ✓';
      });
    } catch (e) {
      setState(() {
        _status = 'Firebase Database Error: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _testRegistration() async {
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nameController.text.isEmpty) {
      setState(() {
        _status = 'Please fill all fields';
      });
      return;
    }

    setState(() {
      _status = 'Testing registration...';
      _isLoading = true;
    });

    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final DatabaseReference database = FirebaseDatabase.instance.ref();

      print('Step 1: Creating user with Firebase Auth...');
      setState(() {
        _status = 'Step 1: Creating user with Firebase Auth...';
      });

      UserCredential result = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('Step 2: User created: ${result.user?.uid}');
      setState(() {
        _status = 'Step 2: User created: ${result.user?.uid}';
      });

      if (result.user != null) {
        print('Step 3: Updating display name...');
        setState(() {
          _status = 'Step 3: Updating display name...';
        });
        
        await result.user!.updateDisplayName(_nameController.text.trim());

        print('Step 4: Saving to database...');
        setState(() {
          _status = 'Step 4: Saving to database...';
        });

        final userData = {
          'uid': result.user!.uid,
          'email': _emailController.text.trim(),
          'displayName': _nameController.text.trim(),
          'isOnline': true,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
          'friends': [],
        };

        await database.child('users/${result.user!.uid}').set(userData);

        print('Step 5: Registration completed successfully!');
        setState(() {
          _status = 'Registration completed successfully! ✓\nUser ID: ${result.user!.uid}';
        });

        // Clear fields
        _emailController.clear();
        _passwordController.clear();
        _nameController.clear();
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      setState(() {
        _status = 'Firebase Auth Error: ${e.code}\n${e.message}';
      });
    } catch (e) {
      print('General Error: $e');
      setState(() {
        _status = 'Error: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Debug Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Firebase Connection Test',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testFirebaseConnection,
                      child: const Text('Test Firebase Connection'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Database Verification',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setState(() {
                                _status = 'Verifying database connection...';
                                _isLoading = true;
                              });
                              
                              await _databaseService.verifyDatabaseConnection();
                              
                              setState(() {
                                _status = 'Database verification completed. Check console for details.';
                                _isLoading = false;
                              });
                            },
                            child: const Text('Verify Connection'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setState(() {
                                _status = 'Getting all users...';
                                _isLoading = true;
                              });
                              
                              await _databaseService.getAllUsers();
                              
                              setState(() {
                                _status = 'All users retrieved. Check console for details.';
                                _isLoading = false;
                              });
                            },
                            child: const Text('Show Users'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setState(() {
                                _status = 'Getting all chats...';
                                _isLoading = true;
                              });
                              
                              await _databaseService.getAllChats();
                              
                              setState(() {
                                _status = 'All chats retrieved. Check console for details.';
                                _isLoading = false;
                              });
                            },
                            child: const Text('Show Chats'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setState(() {
                                _status = 'Forcing database sync...';
                                _isLoading = true;
                              });
                              
                              await _databaseService.forceDatabaseSync();
                              
                              setState(() {
                                _status = 'Database sync completed.';
                                _isLoading = false;
                              });
                            },
                            child: const Text('Force Sync'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Registration Test',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _testRegistration,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Test Registration'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
