import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/group_service.dart';
import 'package:intl/intl.dart';

// GroupChatScreen: UI for group conversations. Shows messages, allows sending,
// viewing group info, adding members (if admin), and leaving the group.
class GroupChatScreen extends StatefulWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  // Controller for the message input field
  final TextEditingController _messageController = TextEditingController();
  // Controller for scrolling the messages list
  final ScrollController _scrollController = ScrollController();
  // Service to manage group-related operations (messages, members, etc.)
  final GroupService _groupService = GroupService();
  // Firebase Auth instance to get current user info
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache member details locally for quick lookup (uid -> UserModel)
  Map<String, UserModel> _membersCache = {}; // Cache for member details
  bool _isLoading = false; // indicates loading state while fetching members

  @override
  void initState() {
    super.initState();
    // Load full details for group members
    _loadMembersDetails();
    // Mark the group messages as read when opening the chat screen
    _groupService.markGroupAsRead(widget.group.groupId);
  }

  // Fetch detailed user info for all group members and store in local cache
  Future<void> _loadMembersDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<UserModel> members = await _groupService.getGroupMembersDetails(widget.group.groupId);
      Map<String, UserModel> cache = {};
      for (UserModel member in members) {
        cache[member.uid] = member;
      }

      if (mounted) {
        setState(() {
          _membersCache = cache;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading members details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Send a text message to the group
  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return; // don't send empty messages

    // Clear input immediately for good UX
    _messageController.clear();

    try {
      // Use GroupService to write message to backend
      await _groupService.sendGroupMessage(widget.group.groupId, message);

      // Scroll to bottom shortly after sending to reveal the new message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      // Show error to user if message send fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show group info bottom sheet
  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildGroupInfoSheet(),
    );
  }

  // Navigate to add members screen and refresh if members were added
  Future<void> _openAddMembers() async {
    final result = await Navigator.pushNamed(
      context,
      '/group/addMembers',
      arguments: widget.group,
    );
    if (result == true) {
      // Refresh members and UI after adding
      await _loadMembersDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Members added successfully')),
        );
      }
    }
  }

  // Build the bottom sheet that displays group information and member list
  Widget _buildGroupInfoSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small handle bar to indicate draggable sheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Group header: avatar + name + member count
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  widget.group.groupName.isNotEmpty
                      ? widget.group.groupName[0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.groupName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.group.memberCount} members',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Show group description if available
          if (widget.group.groupDescription.isNotEmpty) ...[
            Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.group.groupDescription,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Members header
          Text(
            'Members (${widget.group.memberCount})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),

          // Members list using cached member details
          Expanded(
            child: ListView.builder(
              itemCount: _membersCache.length,
              itemBuilder: (context, index) {
                UserModel member = _membersCache.values.elementAt(index);
                bool isAdmin = widget.group.isAdmin(member.uid);
                bool isCreator = widget.group.createdBy == member.uid;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(member.displayName),
                  subtitle: Text(member.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show badges for creator/admin roles
                      if (isCreator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Creator',
                            style: TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // Online indicator dot
                      if (member.isOnline)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showGroupInfo, // tap header to open group info sheet
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  widget.group.groupName.isNotEmpty
                      ? widget.group.groupName[0].toUpperCase()
                      : 'G',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.groupName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.group.memberCount} members',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Popup menu with group actions: info, add member (admin only), leave
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('Group Info'),
                  ],
                ),
                onTap: () {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _showGroupInfo();
                  });
                },
              ),
              if (widget.group.isAdmin(_auth.currentUser?.uid ?? ''))
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.person_add),
                      SizedBox(width: 8),
                      Text('Add Member'),
                    ],
                  ),
                  onTap: () {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _openAddMembers();
                    });
                  },
                ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Leave Group', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onTap: () {
                  _showLeaveGroupDialog();
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _groupService.getGroupMessages(widget.group.groupId).asBroadcastStream(),
              builder: (context, snapshot) {
                // Show loading indicator when member details are still loading
                if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                List<MessageModel> messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  // Empty group placeholder
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Welcome to the group!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation by sending a message.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Auto scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // Mark as read on scroll/render for the newest message
                    if (index == messages.length - 1) {
                      // newest visible
                      _groupService.markGroupAsRead(widget.group.groupId);
                    }
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),

          // Message input area at the bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build a single message bubble for the group chat
  Widget _buildMessageBubble(MessageModel message) {
    final currentUser = _auth.currentUser;
    final isMyMessage = message.senderId == currentUser?.uid;
    final sender = _membersCache[message.senderId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
        isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            // Show sender avatar for other people's messages
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                sender?.displayName.isNotEmpty == true
                    ? sender!.displayName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // For others' messages show sender name above the text
                  if (!isMyMessage && sender != null) ...[
                    Text(
                      sender.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isMyMessage ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Message timestamp
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMyMessage ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            // Small avatar for current user next to own messages
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                currentUser?.displayName?.isNotEmpty == true
                    ? currentUser!.displayName![0].toUpperCase()
                    : 'Y',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Dialog to confirm leaving the group and call service to remove user
  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Are you sure you want to leave "${widget.group.groupName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // Call service to leave
                await _groupService.leaveGroup(widget.group.groupId);
                if (mounted) {
                  Navigator.pop(context); // close chat screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left group successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error leaving group: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}





// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../../models/group_model.dart';
// import '../../models/message_model.dart';
// import '../../models/user_model.dart';
// import '../../services/group_service.dart';
// import 'package:intl/intl.dart';
//
// class GroupChatScreen extends StatefulWidget {
//   final GroupModel group;
//
//   const GroupChatScreen({super.key, required this.group});
//
//   @override
//   State<GroupChatScreen> createState() => _GroupChatScreenState();
// }
//
// class _GroupChatScreenState extends State<GroupChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final GroupService _groupService = GroupService();
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//
//   Map<String, UserModel> _membersCache = {}; // Cache for member details
//   bool _isLoading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadMembersDetails();
//     // Mark as read when opening group chat
//     _groupService.markGroupAsRead(widget.group.groupId);
//   }
//
//   Future<void> _loadMembersDetails() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       List<UserModel> members = await _groupService.getGroupMembersDetails(widget.group.groupId);
//       Map<String, UserModel> cache = {};
//       for (UserModel member in members) {
//         cache[member.uid] = member;
//       }
//
//       if (mounted) {
//         setState(() {
//           _membersCache = cache;
//           _isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error loading members details: $e');
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   void _sendMessage() async {
//     final message = _messageController.text.trim();
//     if (message.isEmpty) return;
//
//     _messageController.clear();
//
//     try {
//       await _groupService.sendGroupMessage(widget.group.groupId, message);
//
//       // Scroll to bottom after sending message
//       Future.delayed(const Duration(milliseconds: 100), () {
//         if (_scrollController.hasClients) {
//           _scrollController.animateTo(
//             _scrollController.position.maxScrollExtent,
//             duration: const Duration(milliseconds: 300),
//             curve: Curves.easeOut,
//           );
//         }
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Failed to send message: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
//
//   void _showGroupInfo() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (context) => _buildGroupInfoSheet(),
//     );
//   }
//
//   Future<void> _openAddMembers() async {
//     final result = await Navigator.pushNamed(
//       context,
//       '/group/addMembers',
//       arguments: widget.group,
//     );
//     if (result == true) {
//       // Refresh members and UI after adding
//       await _loadMembersDetails();
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Members added successfully')),
//         );
//       }
//     }
//   }
//
//   Widget _buildGroupInfoSheet() {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.7,
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Handle bar
//           Center(
//             child: Container(
//               width: 40,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: Colors.grey[300],
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),
//
//           // Group info header
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 30,
//                 backgroundColor: Theme.of(context).primaryColor,
//                 child: Text(
//                   widget.group.groupName.isNotEmpty
//                       ? widget.group.groupName[0].toUpperCase()
//                       : 'G',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.group.groupName,
//                       style: const TextStyle(
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       '${widget.group.memberCount} members',
//                       style: TextStyle(
//                         color: Colors.grey[600],
//                         fontSize: 16,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//
//           // Group description
//           if (widget.group.groupDescription.isNotEmpty) ...[
//             Text(
//               'Description',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey[700],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               widget.group.groupDescription,
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 20),
//           ],
//
//           // Members section
//           Text(
//             'Members (${widget.group.memberCount})',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.grey[700],
//             ),
//           ),
//           const SizedBox(height: 10),
//
//           // Members list
//           Expanded(
//             child: ListView.builder(
//               itemCount: _membersCache.length,
//               itemBuilder: (context, index) {
//                 UserModel member = _membersCache.values.elementAt(index);
//                 bool isAdmin = widget.group.isAdmin(member.uid);
//                 bool isCreator = widget.group.createdBy == member.uid;
//
//                 return ListTile(
//                   leading: CircleAvatar(
//                     backgroundColor: Theme.of(context).primaryColor,
//                     child: Text(
//                       member.displayName.isNotEmpty
//                           ? member.displayName[0].toUpperCase()
//                           : 'U',
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ),
//                   title: Text(member.displayName),
//                   subtitle: Text(member.email),
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (isCreator)
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: Colors.purple.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: const Text(
//                             'Creator',
//                             style: TextStyle(
//                               color: Colors.purple,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         )
//                       else if (isAdmin)
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: Colors.orange.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: const Text(
//                             'Admin',
//                             style: TextStyle(
//                               color: Colors.orange,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       if (member.isOnline)
//                         Container(
//                           margin: const EdgeInsets.only(left: 8),
//                           width: 12,
//                           height: 12,
//                           decoration: const BoxDecoration(
//                             color: Colors.green,
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: GestureDetector(
//           onTap: _showGroupInfo,
//           child: Row(
//             children: [
//               CircleAvatar(
//                 backgroundColor: Theme.of(context).primaryColor,
//                 child: Text(
//                   widget.group.groupName.isNotEmpty
//                       ? widget.group.groupName[0].toUpperCase()
//                       : 'G',
//                   style: const TextStyle(color: Colors.white),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.group.groupName,
//                       style: const TextStyle(fontSize: 16),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     Text(
//                       '${widget.group.memberCount} members',
//                       style: const TextStyle(fontSize: 12, color: Colors.white70),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           PopupMenuButton(
//             itemBuilder: (context) => [
//               PopupMenuItem(
//                 child: const Row(
//                   children: [
//                     Icon(Icons.info),
//                     SizedBox(width: 8),
//                     Text('Group Info'),
//                   ],
//                 ),
//                 onTap: () {
//                   Future.delayed(const Duration(milliseconds: 100), () {
//                     _showGroupInfo();
//                   });
//                 },
//               ),
//               if (widget.group.isAdmin(_auth.currentUser?.uid ?? ''))
//                 PopupMenuItem(
//                   child: const Row(
//                     children: [
//                       Icon(Icons.person_add),
//                       SizedBox(width: 8),
//                       Text('Add Member'),
//                     ],
//                   ),
//                   onTap: () {
//                     Future.delayed(const Duration(milliseconds: 100), () {
//                       _openAddMembers();
//                     });
//                   },
//                 ),
//               PopupMenuItem(
//                 child: const Row(
//                   children: [
//                     Icon(Icons.exit_to_app, color: Colors.red),
//                     SizedBox(width: 8),
//                     Text('Leave Group', style: TextStyle(color: Colors.red)),
//                   ],
//                 ),
//                 onTap: () {
//                   _showLeaveGroupDialog();
//                 },
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Messages list
//           Expanded(
//             child: StreamBuilder<List<MessageModel>>(
//               stream: _groupService.getGroupMessages(widget.group.groupId).asBroadcastStream(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
//                   return const Center(child: CircularProgressIndicator());
//                 }
//
//                 if (snapshot.hasError) {
//                   return Center(
//                     child: Text('Error loading messages: ${snapshot.error}'),
//                   );
//                 }
//
//                 List<MessageModel> messages = snapshot.data ?? [];
//
//                 if (messages.isEmpty) {
//                   return const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.group,
//                           size: 80,
//                           color: Colors.grey,
//                         ),
//                         SizedBox(height: 16),
//                         Text(
//                           'Welcome to the group!',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w500,
//                             color: Colors.grey,
//                           ),
//                         ),
//                         SizedBox(height: 8),
//                         Text(
//                           'Start the conversation by sending a message.',
//                           style: TextStyle(color: Colors.grey),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//
//                 // Auto scroll to bottom when new messages arrive
//                 WidgetsBinding.instance.addPostFrameCallback((_) {
//                   if (_scrollController.hasClients) {
//                     _scrollController.animateTo(
//                       _scrollController.position.maxScrollExtent,
//                       duration: const Duration(milliseconds: 300),
//                       curve: Curves.easeOut,
//                     );
//                   }
//                 });
//
//                 return ListView.builder(
//                   controller: _scrollController,
//                   padding: const EdgeInsets.all(16),
//                   itemCount: messages.length,
//                   itemBuilder: (context, index) {
//                     // Mark as read on scroll/render
//                     if (index == messages.length - 1) {
//                       // newest visible
//                       _groupService.markGroupAsRead(widget.group.groupId);
//                     }
//                     return _buildMessageBubble(messages[index]);
//                   },
//                 );
//               },
//             ),
//           ),
//
//           // Message input
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 5,
//                   offset: const Offset(0, -2),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Type a message...',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(25),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey[100],
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 10,
//                       ),
//                     ),
//                     maxLines: null,
//                     onSubmitted: (_) => _sendMessage(),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 FloatingActionButton(
//                   mini: true,
//                   onPressed: _sendMessage,
//                   child: const Icon(Icons.send),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildMessageBubble(MessageModel message) {
//     final currentUser = _auth.currentUser;
//     final isMyMessage = message.senderId == currentUser?.uid;
//     final sender = _membersCache[message.senderId];
//
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         mainAxisAlignment:
//             isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
//         children: [
//           if (!isMyMessage) ...[
//             CircleAvatar(
//               radius: 16,
//               backgroundColor: Theme.of(context).primaryColor,
//               child: Text(
//                 sender?.displayName.isNotEmpty == true
//                     ? sender!.displayName[0].toUpperCase()
//                     : 'U',
//                 style: const TextStyle(color: Colors.white, fontSize: 12),
//               ),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Flexible(
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: isMyMessage
//                     ? Theme.of(context).primaryColor
//                     : Colors.grey[200],
//                 borderRadius: BorderRadius.circular(18),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (!isMyMessage && sender != null) ...[
//                     Text(
//                       sender.displayName,
//                       style: TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                         color: Theme.of(context).primaryColor,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                   ],
//                   Text(
//                     message.message,
//                     style: TextStyle(
//                       color: isMyMessage ? Colors.white : Colors.black87,
//                       fontSize: 16,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     DateFormat('HH:mm').format(message.timestamp),
//                     style: TextStyle(
//                       color: isMyMessage ? Colors.white70 : Colors.grey[600],
//                       fontSize: 12,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           if (isMyMessage) ...[
//             const SizedBox(width: 8),
//             CircleAvatar(
//               radius: 16,
//               backgroundColor: Theme.of(context).primaryColor,
//               child: Text(
//                 currentUser?.displayName?.isNotEmpty == true
//                     ? currentUser!.displayName![0].toUpperCase()
//                     : 'Y',
//                 style: const TextStyle(color: Colors.white, fontSize: 12),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
//
//   void _showLeaveGroupDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Leave Group'),
//         content: Text('Are you sure you want to leave "${widget.group.groupName}"?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               try {
//                 await _groupService.leaveGroup(widget.group.groupId);
//                 if (mounted) {
//                   Navigator.pop(context);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Left group successfully')),
//                   );
//                 }
//               } catch (e) {
//                 if (mounted) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text('Error leaving group: $e'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }
//               }
//             },
//             child: const Text('Leave', style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//   }
// }
