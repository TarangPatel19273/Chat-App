import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import '../../services/group_service.dart';
import '../chat/chat_screen.dart';
import '../../models/user_model.dart';
import '../../models/group_model.dart';
import '../../models/notification_model.dart';
import '../../widgets/in_app_notification.dart';
import '../group/create_group_screen.dart';
import '../group/group_chat_screen.dart';
import '../profile/profile_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();
  final GroupService _groupService = GroupService();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  bool _isRefreshing = false;
  
  // Cache for friends, chats, and groups to prevent disappearing
  List<UserModel> _cachedFriends = [];
  List<Map<String, dynamic>> _cachedChats = [];
  List<GroupModel> _cachedGroups = [];
  
  // Search queries
  String _chatSearchQuery = '';
  String _groupSearchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Only Chats and Groups
    
    // Pre-load friends and groups data
    _loadFriends();
    _loadGroups();
    
    // Listen for real-time notifications
    _setupNotificationListener();
  }
  
  void _setupNotificationListener() {
    _notificationService.listenForNewNotifications(
      onNewNotification: (NotificationModel notification) {
        if (mounted) {
          // Show in-app notification for 3 seconds
          InAppNotificationOverlay.show(
            context,
            notification,
            onTap: () {
              // Handle notification tap
              _handleNotificationTap(notification);
            },
          );
        }
      },
    );
  }
  
  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read when tapped
    _notificationService.markNotificationAsRead(notification.id);
    
    // Just refresh the current view to show updated friend list
    setState(() {});
  }
  
  Future<void> _loadFriends() async {
    try {
      final friends = await _chatService.getFriends();
      if (mounted) {
        setState(() {
          _cachedFriends = friends;
        });
      }
    } catch (e) {
      print('Error loading friends: $e');
    }
  }
  
  Future<void> _loadGroups() async {
    try {
      // Listen to groups stream once to get initial data
      final subscription = _groupService.getUserGroups().listen((groups) {
        if (mounted) {
          setState(() {
            _cachedGroups = groups;
          });
          print('Loaded ${groups.length} groups into cache');
        }
      });
      
      // Cancel subscription after first load
      Future.delayed(const Duration(seconds: 2), () {
        subscription.cancel();
      });
    } catch (e) {
      print('Error loading groups: $e');
    }
  }
  
  // Refresh all data
  Future<void> _refreshAllData() async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await _loadFriends();
      await _loadGroups();
      // Clear cache to force refresh from streams
      _cachedChats.clear();
    } catch (e) {
      print('Error refreshing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Future<void> _showAddFriendDialog() async {
    final emailController = TextEditingController();
    bool isLoading = false;
    
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Friend'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Friend\'s Email',
                      prefixIcon: Icon(Icons.email),
                      hintText: 'Enter email address',
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Adding friend...'),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final email = emailController.text.trim();
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter an email address'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    
                    setDialogState(() {
                      isLoading = true;
                    });
                    
                    try {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      bool success = await authService.addFriend(email);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        
                        String message;
                        Color backgroundColor;
                        
                        if (success) {
                          message = 'Friend added successfully!';
                          backgroundColor = Colors.green;
                          // Refresh the cached friends data
                          await _loadFriends();
                          // Refresh the UI
                          setState(() {});
                        } else {
                          message = 'Failed to add friend. User may not exist or is already your friend.';
                          backgroundColor = Colors.red;
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: backgroundColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatting App'),
        centerTitle: true,
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshAllData,
              tooltip: 'Refresh Data',
            ),
          // Profile Icon
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'My Profile',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.person_add),
                    SizedBox(width: 8),
                    Text('Add Friend'),
                  ],
                ),
                onTap: () {
                  // Delay to allow popup to close
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _showAddFriendDialog();
                  });
                },
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(
              icon: Icon(Icons.chat),
              text: 'Chats',
            ),
            const Tab(
              icon: Icon(Icons.group),
              text: 'Groups',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(),
          _buildGroupsTab(),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        // Search bar for chats
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search friends and chats...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) {
              setState(() {
                _chatSearchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        // Chat content
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getChatList().asBroadcastStream(),
            builder: (context, chatSnapshot) {
              return StreamBuilder<List<UserModel>>(
                stream: _chatService.getFriendsStream().asBroadcastStream(),
                builder: (context, friendsSnapshot) {
                  return StreamBuilder<List<GroupModel>>(
                    stream: _groupService.getUserGroups().asBroadcastStream(),
                    builder: (context, groupsSnapshot) {
                      // Get chats data
                      List<Map<String, dynamic>> chats = [];
                      if (chatSnapshot.hasData && chatSnapshot.data!.isNotEmpty) {
                        chats = chatSnapshot.data!;
                        _cachedChats = chats;
                      } else if (_cachedChats.isNotEmpty) {
                        chats = _cachedChats;
                      }

                      // Get friends data
                      List<UserModel> friends = [];
                      if (friendsSnapshot.hasData && friendsSnapshot.data!.isNotEmpty) {
                        friends = friendsSnapshot.data!;
                        _cachedFriends = friends;
                      } else if (_cachedFriends.isNotEmpty) {
                        friends = _cachedFriends;
                      }
                      
                      // Get groups data
                      List<GroupModel> groups = [];
                      if (groupsSnapshot.hasData && groupsSnapshot.data!.isNotEmpty) {
                        groups = groupsSnapshot.data!;
                        _cachedGroups = groups;
                      } else if (_cachedGroups.isNotEmpty) {
                        groups = _cachedGroups;
                      }

                // Show loading if all are still loading
                if ((chatSnapshot.connectionState == ConnectionState.waiting || 
                     friendsSnapshot.connectionState == ConnectionState.waiting ||
                     groupsSnapshot.connectionState == ConnectionState.waiting) && 
                    chats.isEmpty && friends.isEmpty && groups.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Show error if all have errors
                if (chatSnapshot.hasError && friendsSnapshot.hasError && groupsSnapshot.hasError &&
                    chats.isEmpty && friends.isEmpty && groups.isEmpty) {
                  return const Center(
                    child: Text('Error loading chats, friends, and groups'),
                  );
                }

                // Get list of friend IDs who already have chats
                Set<String> friendsWithChats = {};
                for (var chat in chats) {
                  final user = chat['user'] as UserModel;
                  friendsWithChats.add(user.uid);
                }

                // Filter friends who don't have existing chats
                List<UserModel> friendsWithoutChats = friends.where(
                  (friend) => !friendsWithChats.contains(friend.uid)
                ).toList();

                // Apply search filtering BEFORE building widgets
                if (_chatSearchQuery.isNotEmpty) {
                  // Filter chats
                  chats = chats.where((chat) {
                    final user = chat['user'] as UserModel;
                    return user.displayName.toLowerCase().contains(_chatSearchQuery) ||
                           user.email.toLowerCase().contains(_chatSearchQuery) ||
                           (chat['lastMessage'] as String).toLowerCase().contains(_chatSearchQuery);
                  }).toList();
                  
                  // Filter groups
                  groups = groups.where((group) {
                    return group.groupName.toLowerCase().contains(_chatSearchQuery) ||
                           group.groupDescription.toLowerCase().contains(_chatSearchQuery) ||
                           group.lastMessage.toLowerCase().contains(_chatSearchQuery);
                  }).toList();
                  
                  // Filter friends
                  friendsWithoutChats = friendsWithoutChats.where((friend) {
                    return friend.displayName.toLowerCase().contains(_chatSearchQuery) ||
                           friend.email.toLowerCase().contains(_chatSearchQuery);
                  }).toList();
                }

                // If no chats, friends, and groups, show empty state
                if (chats.isEmpty && friends.isEmpty && groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No conversations yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add friends and start chatting!',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddFriendDialog,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Friend'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                  );
                }

                List<Widget> chatWidgets = [];
                
                // Add existing chats section
                if (chats.isNotEmpty) {
                  chatWidgets.add(
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.chat, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Recent Chats',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  
                  for (var chat in chats) {
                    chatWidgets.add(_buildChatItem(chat));
                  }
                }

                // Add groups section
                if (groups.isNotEmpty) {
                  chatWidgets.add(
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.group, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text(
                            'Group Chats',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  
                  for (var group in groups) {
                    chatWidgets.add(_buildGroupChatItem(group));
                  }
                }

                // Add friends without existing chats section
                if (friendsWithoutChats.isNotEmpty) {
                  chatWidgets.add(
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.people, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Start New Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  
                  for (var friend in friendsWithoutChats) {
                    chatWidgets.add(_buildFriendChatItem(friend));
                  }
                }

                // Add "add more friends" section if only have chats but no additional friends
                if (chats.isNotEmpty && friendsWithoutChats.isEmpty) {
                  chatWidgets.add(
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Add more friends to chat with!',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _showAddFriendDialog,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Friend'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                      return ListView(
                        children: chatWidgets,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final user = chat['user'] as UserModel;
    final lastMessage = chat['lastMessage'] as String;
    final timestamp = chat['timestamp'] as DateTime;
    final isFromMe = chat['isLastMessageFromMe'] as bool;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (user.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          if (isFromMe) ...[
            const Icon(Icons.done, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: StreamBuilder<int>(
        stream: _chatService.streamUnreadMessageCount(user.uid).asBroadcastStream(),
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(timestamp),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(friend: user),
          ),
        );
      },
    );
  }

  Widget _buildFriendChatItem(UserModel friend) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              friend.displayName.isNotEmpty
                  ? friend.displayName[0].toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
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
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        friend.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        friend.statusText,
        style: TextStyle(
          color: friend.isOnline ? Colors.green : Colors.grey,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green),
        ),
        child: const Text(
          'Start Chat',
          style: TextStyle(
            color: Colors.green,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(friend: friend),
          ),
        );
      },
    );
  }
  
  Widget _buildGroupChatItem(GroupModel group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.purple,
        child: Text(
          group.groupName.isNotEmpty
              ? group.groupName[0].toUpperCase()
              : 'G',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        group.groupName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.lastMessage.isNotEmpty)
            Text(
              group.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          Text(
            '${group.memberCount} members',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: StreamBuilder<int>(
        stream: _groupService.streamGroupUnreadCount(group.groupId).asBroadcastStream(),
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (group.lastMessage.isNotEmpty)
                Text(
                  _formatTimestamp(group.lastMessageTime),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 4),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(group: group),
          ),
        );
      },
    );
  }


  Widget _buildGroupsTab() {
    return Scaffold(
      body: Column(
        children: [
          // Search bar for groups
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search groups...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _groupSearchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Groups content
          Expanded(
            child: StreamBuilder<List<GroupModel>>(
              stream: _groupService.getUserGroups().asBroadcastStream(),
              builder: (context, snapshot) {
          // Use cached data while loading or on error if we have cache
          List<GroupModel> groups = [];
          
                // Use cached data while loading or on error if we have cache
                List<GroupModel> allGroups = [];
                
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  allGroups = snapshot.data!;
                  // Update cache with fresh data
                  _cachedGroups = allGroups;
                  print('Updated groups cache with ${allGroups.length} groups');
                } else if (_cachedGroups.isNotEmpty) {
                  // Use cached data if stream has no data but we have cache
                  allGroups = _cachedGroups;
                  print('Using cached groups: ${allGroups.length}');
                }
                
                // Apply search filtering for groups BEFORE empty checks
                List<GroupModel> filteredGroups = allGroups;
                if (_groupSearchQuery.isNotEmpty) {
                  filteredGroups = allGroups.where((group) {
                    return group.groupName.toLowerCase().contains(_groupSearchQuery) ||
                           group.groupDescription.toLowerCase().contains(_groupSearchQuery) ||
                           group.lastMessage.toLowerCase().contains(_groupSearchQuery);
                  }).toList();
                }
                
                if (snapshot.connectionState == ConnectionState.waiting && allGroups.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError && allGroups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading groups: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredGroups.isEmpty && _groupSearchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No groups found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching with different keywords',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                if (allGroups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start chatting with multiple friends!',
                    style: TextStyle(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateGroupScreen(),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Create Group'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

                return ListView.builder(
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    return _buildGroupItem(group);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupScreen(),
        child: const Icon(Icons.group_add),
        tooltip: 'Create Group',
      ),
    );
  }

  Widget _buildGroupItem(GroupModel group) {
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          group.groupName.isNotEmpty
              ? group.groupName[0].toUpperCase()
              : 'G',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        group.groupName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.lastMessage.isNotEmpty)
            Text(
              group.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[500]),
            ),
          const SizedBox(height: 2),
          Text(
            '${group.memberCount} members',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: StreamBuilder<int>(
        stream: _groupService.streamGroupUnreadCount(group.groupId).asBroadcastStream(),
        builder: (context, snapshot) {
          final unread = snapshot.data ?? 0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (group.lastMessage.isNotEmpty)
                Text(
                  _formatTimestamp(group.lastMessageTime),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 4),
              if (unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(group: group),
          ),
        );
      },
    );
  }

  Future<void> _showCreateGroupScreen() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );

    // Refresh groups if a new group was created
    if (result == true) {
      setState(() {}); // This will trigger a rebuild and refresh the groups stream
    }
  }


  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('E').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
