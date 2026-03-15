import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convora/core/providers/providers.dart';
import 'package:convora/core/models/models.dart';

class OrgMembersScreen extends ConsumerWidget {
  const OrgMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(orgMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Team'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite Member'),
        backgroundColor: Colors.teal,
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load members',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(orgMembersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (members) {
          if (members.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No team members yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('Tap the button below to invite your first member.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              return _MemberTile(
                member: member,
                onDeactivate: () async {
                  final confirmed =
                      await _confirmDeactivate(context, member.userName ?? 'this member');
                  if (!confirmed) return;
                  try {
                    final apiClient = ref.read(apiClientProvider);
                    await apiClient.deactivateOrgMember(member.userId);
                    ref.refresh(orgMembersProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Member deactivated'),
                            backgroundColor: Colors.orange),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDeactivate(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Deactivate Member'),
            content: Text('Remove $name from your organization?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Deactivate'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InviteSheet(
        onInvited: () => ref.refresh(orgMembersProvider),
      ),
    );
  }
}

// ===========================================================================
// Member Tile
// ===========================================================================

class _MemberTile extends StatelessWidget {
  final OrgMember member;
  final VoidCallback onDeactivate;

  const _MemberTile({required this.member, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    final name = member.userName ?? 'User #${member.userId}';
    final email = member.userEmail ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((p) => p[0].toUpperCase()).join()
        : '?';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _roleColor(member.orgRole).withOpacity(0.15),
          child: Text(
            initials,
            style: TextStyle(
                color: _roleColor(member.orgRole),
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty)
              Text(email,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Row(
              children: [
                _RoleBadge(role: member.orgRole),
                if (!member.isActive) ...[
                  const SizedBox(width: 8),
                  _RoleBadge(role: 'inactive'),
                ],
              ],
            ),
          ],
        ),
        trailing: member.isActive
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'deactivate') onDeactivate();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: ListTile(
                      leading: Icon(Icons.person_off_outlined,
                          color: Colors.red),
                      title: Text('Deactivate',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'org_admin':
        return Colors.teal;
      case 'team_lead':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (role) {
      case 'org_admin':
        color = Colors.teal;
        label = 'Admin';
        break;
      case 'team_lead':
        color = Colors.blue;
        label = 'Team Lead';
        break;
      case 'inactive':
        color = Colors.red;
        label = 'Inactive';
        break;
      default:
        color = Colors.grey;
        label = 'Member';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ===========================================================================
// Invite Bottom Sheet
// ===========================================================================

class _InviteSheet extends ConsumerStatefulWidget {
  final VoidCallback onInvited;

  const _InviteSheet({required this.onInvited});

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'member';
  bool _isSubmitting = false;
  String? _tempPasswordShown;

  @override
  void initState() {
    super.initState();
    _generateTempPassword();
  }

  void _generateTempPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final password = List.generate(
        12,
        (i) => chars[
            DateTime.now().microsecondsSinceEpoch * (i + 1) % chars.length]);
    _passwordController.text = password.join();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invite Team Member',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_tempPasswordShown != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.teal.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Member invited!',
                          style: TextStyle(
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Share this temporary password with the new member:',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  SelectableText(
                    _tempPasswordShown!,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('They will be prompted to change it on first login.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onInvited();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: 'Role',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(
                    value: 'team_lead', child: Text('Team Lead')),
                DropdownMenuItem(value: 'org_admin', child: Text('Admin')),
              ],
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Temporary Password',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generateTempPassword,
                  tooltip: 'Regenerate',
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48)),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Invite'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email')));
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name')));
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set a temporary password')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.inviteOrgMember(
        email: email,
        name: name,
        tempPassword: password,
        orgRole: _selectedRole,
      );
      setState(() {
        _tempPasswordShown = password;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to invite member: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
