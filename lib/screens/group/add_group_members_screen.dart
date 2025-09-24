import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';

class AddGroupMembersScreen extends StatefulWidget {
  final GroupModel group;

  const AddGroupMembersScreen({super.key, required this.group});

  @override
  State<AddGroupMembersScreen> createState() => _AddGroupMembersScreenState();
}

class _AddGroupMembersScreenState extends State<AddGroupMembersScreen> {
  final ChatService _chatService = ChatService();
  final GroupService _groupService = GroupService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<UserModel> _friends = [];
  final Set<String> _selectedUserIds = {};
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadFriendsNotInGroup();
  }

  Future<void> _loadFriendsNotInGroup() async {
    setState(() {
      _loading = true;
    });
    try {
      final List<UserModel> allFriends = await _chatService.getFriends();
      final Set<String> currentMembers = widget.group.members.toSet();
      final List<UserModel> candidates = allFriends
          .where((u) => !currentMembers.contains(u.uid))
          .toList();
      if (mounted) {
        setState(() {
          _friends = candidates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading friends: $e')),
        );
      }
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one friend')),
      );
      return;
    }
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || !widget.group.isAdmin(currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can add members')),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      for (final userId in _selectedUserIds) {
        await _groupService.addMemberToGroup(widget.group.groupId, userId);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add members: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _addSelectedMembers,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'ADD',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
              ? const Center(child: Text('No friends available to add'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final user = _friends[index];
                    final selected = _selectedUserIds.contains(user.uid);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.email),
                      trailing: Checkbox(
                        value: selected,
                        onChanged: _submitting
                            ? null
                            : (v) {
                                setState(() {
                                  if (selected) {
                                    _selectedUserIds.remove(user.uid);
                                  } else {
                                    _selectedUserIds.add(user.uid);
                                  }
                                });
                              },
                      ),
                      onTap: _submitting
                          ? null
                          : () {
                              setState(() {
                                if (selected) {
                                  _selectedUserIds.remove(user.uid);
                                } else {
                                  _selectedUserIds.add(user.uid);
                                }
                              });
                            },
                    );
                  },
                ),
      bottomNavigationBar: _friends.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _addSelectedMembers,
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      _submitting
                          ? 'Adding...'
                          : 'Add ${_selectedUserIds.isEmpty ? '' : '(${_selectedUserIds.length})'}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}


