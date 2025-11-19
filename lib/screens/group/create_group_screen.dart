import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/group_service.dart';
import '../../services/chat_service.dart';

// CreateGroupScreen: allows user to create a new group by selecting friends and entering group details
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  // Controllers for group name and description inputs
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();

  // Services for managing groups and accessing friends list
  final GroupService _groupService = GroupService();
  final ChatService _chatService = ChatService();

  // Local state variables
  List<UserModel> _allFriends = []; // all friends fetched from chat service
  List<UserModel> _selectedMembers = []; // selected members for the group
  bool _isLoading = false; // true while loading friends
  bool _isCreating = false; // true while creating group

  @override
  void initState() {
    super.initState();
    _loadFriends(); // load friends when screen initializes
  }

  // Load user's friends from chat service
  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<UserModel> friends = await _chatService.getFriends();
      setState(() {
        _allFriends = friends;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading friends: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        // Show error SnackBar if loading fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading friends: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    super.dispose();
  }

  // Toggle a friend's selection in the group
  void _toggleMemberSelection(UserModel user) {
    setState(() {
      if (_selectedMembers.contains(user)) {
        _selectedMembers.remove(user);
      } else {
        _selectedMembers.add(user);
      }
    });
  }

  // Create group with entered details and selected members
  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    final groupDescription = _groupDescriptionController.text.trim();

    // Validation: group name required
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a group name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validation: at least one member required
    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true; // show progress
    });

    try {
      // Extract member IDs from selected users
      List<String> memberIds = _selectedMembers.map((user) => user.uid).toList();

      // Call group service to create the group
      String? groupId = await _groupService.createGroup(
        groupName: groupName,
        groupDescription: groupDescription,
        memberIds: memberIds,
      );

      if (mounted) {
        if (groupId != null) {
          // If group created successfully, close screen and show success message
          Navigator.pop(context, true); // return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Group "$groupName" created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Show failure message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create group. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error creating group: $e');
      if (mounted) {
        // Show error message in SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false; // stop showing progress
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          // CREATE button in app bar
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'CREATE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
      // Show loader while friends are being fetched
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group avatar placeholder (with camera icon)
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      Icons.group,
                      size: 60,
                      color: Colors.grey[600],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Group name input
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name *',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
                hintText: 'Enter group name',
              ),
              maxLength: 50,
              enabled: !_isCreating,
            ),
            const SizedBox(height: 16),

            // Group description input
            TextField(
              controller: _groupDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Group Description (Optional)',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
                hintText: 'Enter group description',
              ),
              maxLines: 3,
              maxLength: 200,
              enabled: !_isCreating,
            ),
            const SizedBox(height: 24),

            // Selected members count title
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected Members (${_selectedMembers.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Selected members shown as chips (removable)
            if (_selectedMembers.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedMembers
                      .map((member) => Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    label: Text(member.displayName),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _toggleMemberSelection(member),
                  ))
                      .toList(),
                ),
              )
            else
            // If no members selected yet, show placeholder
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No members selected',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select friends from the list below',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Friends list title
            Row(
              children: [
                Icon(
                  Icons.contacts,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Friends (${_allFriends.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Friends list with selection checkboxes
            if (_allFriends.isEmpty)
            // If no friends available
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No friends found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add friends to create a group',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
            // List of friends with checkbox selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _allFriends.length,
                  itemBuilder: (context, index) {
                    UserModel friend = _allFriends[index];
                    bool isSelected = _selectedMembers.contains(friend);

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              friend.displayName.isNotEmpty
                                  ? friend.displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          // Online indicator dot if friend is online
                          if (friend.isOnline)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        friend.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(friend.email),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: _isCreating
                            ? null
                            : (bool? value) {
                          _toggleMemberSelection(friend);
                        },
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      onTap: _isCreating
                          ? null
                          : () => _toggleMemberSelection(friend),
                      enabled: !_isCreating,
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Bottom Create Group button (alternative to app bar button)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createGroup,
                icon: _isCreating
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.group_add),
                label: Text(
                  _isCreating ? 'Creating Group...' : 'Create Group',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





// import 'package:flutter/material.dart';
// import '../../models/user_model.dart';
// import '../../services/group_service.dart';
// import '../../services/chat_service.dart';
//
// class CreateGroupScreen extends StatefulWidget {
//   const CreateGroupScreen({super.key});
//
//   @override
//   State<CreateGroupScreen> createState() => _CreateGroupScreenState();
// }
//
// class _CreateGroupScreenState extends State<CreateGroupScreen> {
//   final TextEditingController _groupNameController = TextEditingController();
//   final TextEditingController _groupDescriptionController = TextEditingController();
//   final GroupService _groupService = GroupService();
//   final ChatService _chatService = ChatService();
//
//   List<UserModel> _allFriends = [];
//   List<UserModel> _selectedMembers = [];
//   bool _isLoading = false;
//   bool _isCreating = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadFriends();
//   }
//
//   Future<void> _loadFriends() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       List<UserModel> friends = await _chatService.getFriends();
//       setState(() {
//         _allFriends = friends;
//         _isLoading = false;
//       });
//     } catch (e) {
//       print('Error loading friends: $e');
//       setState(() {
//         _isLoading = false;
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error loading friends: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _groupNameController.dispose();
//     _groupDescriptionController.dispose();
//     super.dispose();
//   }
//
//   void _toggleMemberSelection(UserModel user) {
//     setState(() {
//       if (_selectedMembers.contains(user)) {
//         _selectedMembers.remove(user);
//       } else {
//         _selectedMembers.add(user);
//       }
//     });
//   }
//
//   Future<void> _createGroup() async {
//     final groupName = _groupNameController.text.trim();
//     final groupDescription = _groupDescriptionController.text.trim();
//
//     if (groupName.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please enter a group name'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }
//
//     if (_selectedMembers.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select at least one member'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }
//
//     setState(() {
//       _isCreating = true;
//     });
//
//     try {
//       List<String> memberIds = _selectedMembers.map((user) => user.uid).toList();
//
//       String? groupId = await _groupService.createGroup(
//         groupName: groupName,
//         groupDescription: groupDescription,
//         memberIds: memberIds,
//       );
//
//       if (mounted) {
//         if (groupId != null) {
//           Navigator.pop(context, true); // Return true to indicate success
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Group "$groupName" created successfully!'),
//               backgroundColor: Colors.green,
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Failed to create group. Please try again.'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       print('Error creating group: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error creating group: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isCreating = false;
//         });
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Create Group'),
//         actions: [
//           TextButton(
//             onPressed: _isCreating ? null : _createGroup,
//             child: _isCreating
//                 ? const SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                     ),
//                   )
//                 : const Text(
//                     'CREATE',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Group avatar placeholder
//                   Center(
//                     child: Stack(
//                       children: [
//                         CircleAvatar(
//                           radius: 60,
//                           backgroundColor: Colors.grey[300],
//                           child: Icon(
//                             Icons.group,
//                             size: 60,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                         Positioned(
//                           bottom: 0,
//                           right: 0,
//                           child: Container(
//                             decoration: BoxDecoration(
//                               color: Theme.of(context).primaryColor,
//                               shape: BoxShape.circle,
//                             ),
//                             child: const Padding(
//                               padding: EdgeInsets.all(8),
//                               child: Icon(
//                                 Icons.camera_alt,
//                                 color: Colors.white,
//                                 size: 20,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//
//                   // Group name input
//                   TextField(
//                     controller: _groupNameController,
//                     decoration: const InputDecoration(
//                       labelText: 'Group Name *',
//                       prefixIcon: Icon(Icons.group),
//                       border: OutlineInputBorder(),
//                       hintText: 'Enter group name',
//                     ),
//                     maxLength: 50,
//                     enabled: !_isCreating,
//                   ),
//                   const SizedBox(height: 16),
//
//                   // Group description input
//                   TextField(
//                     controller: _groupDescriptionController,
//                     decoration: const InputDecoration(
//                       labelText: 'Group Description (Optional)',
//                       prefixIcon: Icon(Icons.description),
//                       border: OutlineInputBorder(),
//                       hintText: 'Enter group description',
//                     ),
//                     maxLines: 3,
//                     maxLength: 200,
//                     enabled: !_isCreating,
//                   ),
//                   const SizedBox(height: 24),
//
//                   // Selected members count
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.people,
//                         color: Theme.of(context).primaryColor,
//                       ),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Selected Members (${_selectedMembers.length})',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.grey[700],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//
//                   // Selected members chips
//                   if (_selectedMembers.isNotEmpty)
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey[300]!),
//                         borderRadius: BorderRadius.circular(8),
//                         color: Colors.grey[50],
//                       ),
//                       child: Wrap(
//                         spacing: 8,
//                         runSpacing: 8,
//                         children: _selectedMembers
//                             .map((member) => Chip(
//                                   avatar: CircleAvatar(
//                                     backgroundColor: Theme.of(context).primaryColor,
//                                     child: Text(
//                                       member.displayName.isNotEmpty
//                                           ? member.displayName[0].toUpperCase()
//                                           : 'U',
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ),
//                                   label: Text(member.displayName),
//                                   deleteIcon: const Icon(Icons.close, size: 18),
//                                   onDeleted: () => _toggleMemberSelection(member),
//                                 ))
//                             .toList(),
//                       ),
//                     )
//                   else
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey[300]!),
//                         borderRadius: BorderRadius.circular(8),
//                         color: Colors.grey[50],
//                       ),
//                       child: Column(
//                         children: [
//                           Icon(
//                             Icons.person_add,
//                             size: 48,
//                             color: Colors.grey[400],
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'No members selected',
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 16,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             'Select friends from the list below',
//                             style: TextStyle(
//                               color: Colors.grey[500],
//                               fontSize: 14,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   const SizedBox(height: 24),
//
//                   // Friends list title
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.contacts,
//                         color: Theme.of(context).primaryColor,
//                       ),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Your Friends (${_allFriends.length})',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.grey[700],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 8),
//
//                   // Friends list
//                   if (_allFriends.isEmpty)
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(40),
//                       child: Column(
//                         children: [
//                           Icon(
//                             Icons.people_outline,
//                             size: 64,
//                             color: Colors.grey[400],
//                           ),
//                           const SizedBox(height: 16),
//                           Text(
//                             'No friends found',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w500,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             'Add friends to create a group',
//                             style: TextStyle(
//                               color: Colors.grey[500],
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                   else
//                     Container(
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.grey[300]!),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: ListView.builder(
//                         shrinkWrap: true,
//                         physics: const NeverScrollableScrollPhysics(),
//                         itemCount: _allFriends.length,
//                         itemBuilder: (context, index) {
//                           UserModel friend = _allFriends[index];
//                           bool isSelected = _selectedMembers.contains(friend);
//
//                           return ListTile(
//                             leading: Stack(
//                               children: [
//                                 CircleAvatar(
//                                   backgroundColor: Theme.of(context).primaryColor,
//                                   child: Text(
//                                     friend.displayName.isNotEmpty
//                                         ? friend.displayName[0].toUpperCase()
//                                         : 'U',
//                                     style: const TextStyle(color: Colors.white),
//                                   ),
//                                 ),
//                                 if (friend.isOnline)
//                                   Positioned(
//                                     bottom: 0,
//                                     right: 0,
//                                     child: Container(
//                                       width: 12,
//                                       height: 12,
//                                       decoration: BoxDecoration(
//                                         color: Colors.green,
//                                         shape: BoxShape.circle,
//                                         border: Border.all(
//                                           color: Colors.white,
//                                           width: 2,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                               ],
//                             ),
//                             title: Text(
//                               friend.displayName,
//                               style: const TextStyle(fontWeight: FontWeight.w600),
//                             ),
//                             subtitle: Text(friend.email),
//                             trailing: Checkbox(
//                               value: isSelected,
//                               onChanged: _isCreating
//                                   ? null
//                                   : (bool? value) {
//                                       _toggleMemberSelection(friend);
//                                     },
//                               activeColor: Theme.of(context).primaryColor,
//                             ),
//                             onTap: _isCreating
//                                 ? null
//                                 : () => _toggleMemberSelection(friend),
//                             enabled: !_isCreating,
//                           );
//                         },
//                       ),
//                     ),
//                   const SizedBox(height: 24),
//
//                   // Create button (alternative)
//                   SizedBox(
//                     width: double.infinity,
//                     height: 50,
//                     child: ElevatedButton.icon(
//                       onPressed: _isCreating ? null : _createGroup,
//                       icon: _isCreating
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                               ),
//                             )
//                           : const Icon(Icons.group_add),
//                       label: Text(
//                         _isCreating ? 'Creating Group...' : 'Create Group',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       style: ElevatedButton.styleFrom(
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(25),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }
// }
