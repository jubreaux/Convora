import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:convora/core/providers/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  String? _selectedVoice;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedVoice = user?.preferredVoice;

    _nameController.addListener(_checkForChanges);
    _emailController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final user = ref.read(authProvider).user;
    setState(() {
      _hasChanges =
          _nameController.text.trim() != (user?.name ?? '') ||
          _emailController.text.trim() != (user?.email ?? '') ||
          _selectedVoice != user?.preferredVoice;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email cannot be empty')),
      );
      return;
    }

    // Basic email validation
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    final user = ref.read(authProvider).user;
    final updatedName = name != user?.name ? name : null;
    final updatedEmail = email != user?.email ? email : null;
    final voiceChanged = _selectedVoice != user?.preferredVoice;

    // Only call if something changed
    if (updatedName != null || updatedEmail != null || voiceChanged) {
      await ref.read(authProvider.notifier).updateProfile(
        name: updatedName,
        email: updatedEmail,
        updateVoice: voiceChanged,
        voicePreference: voiceChanged ? _selectedVoice : null,
      );
    }

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.error ?? 'Update failed')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    setState(() => _hasChanges = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isLoading = authState.isLoading;

    // Get initials from name
    final initials = user?.name.isNotEmpty == true
        ? user!.name
            .split(' ')
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1F7A7E),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'User',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Organization info section (if member of org)
              if (user?.orgId != null && user?.orgId != 0) ...[
                Card(
                  elevation: 0,
                  color: Colors.teal.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.teal.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organization Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Organization ID: ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: Text(
                                '#${user?.orgId}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Role: ',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Expanded(
                              child: _RoleBadge(role: user?.orgRole ?? ''),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Profile form card
              Card(
                elevation: 0,
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name field
                      TextField(
                        controller: _nameController,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'John Doe',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Email field
                      TextField(
                        controller: _emailController,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'john@example.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),

                      // Voice preference section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Voice Preference',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Use scenario default option
                          RadioListTile<String?>(
                            value: null,
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) => setState(() => _checkForChanges()),
                            title: const Text('Use scenario default'),
                            subtitle: Text(
                              'Voice determined by personality type (D/I/S/C)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Alloy voice option
                          RadioListTile<String?>(
                            value: 'alloy',
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVoice = value;
                                _checkForChanges();
                              });
                            },
                            title: const Text('Alloy'),
                            subtitle: Text(
                              'Neutral & balanced',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Echo voice option
                          RadioListTile<String?>(
                            value: 'echo',
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVoice = value;
                                _checkForChanges();
                              });
                            },
                            title: const Text('Echo'),
                            subtitle: Text(
                              'Analytical & measured (C default)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Fable voice option
                          RadioListTile<String?>(
                            value: 'fable',
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVoice = value;
                                _checkForChanges();
                              });
                            },
                            title: const Text('Fable'),
                            subtitle: Text(
                              'Expressive & warm',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Onyx voice option
                          RadioListTile<String?>(
                            value: 'onyx',
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVoice = value;
                                _checkForChanges();
                              });
                            },
                            title: const Text('Onyx'),
                            subtitle: Text(
                              'Authoritative & deep (D default)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Nova voice option
                          RadioListTile<String?>(
                            value: 'nova',
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVoice = value;
                                _checkForChanges();
                              });
                            },
                            title: const Text('Nova'),
                            subtitle: Text(
                              'Enthusiastic & bright (I default)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          // Shimmer voice option
                          RadioListTile<String?>(
                            value: 'shimmer',
                            groupValue: _selectedVoice,
                            onChanged: isLoading ? null : (value) {
                              setState(() {
                                _selectedVoice = value;
                                _checkForChanges();
                              });
                            },
                            title: const Text('Shimmer'),
                            subtitle: Text(
                              'Gentle & calm (S default)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: (_hasChanges && !isLoading) ? _handleSave : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1F7A7E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                'Changes are saved to your account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Role Badge Widget
// ===========================================================================

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
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
