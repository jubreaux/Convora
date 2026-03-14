import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:convora/core/providers/providers.dart';

// ===== Shared helper: show a dialog to change the server URL =====
Future<void> showServerDialog(BuildContext context, WidgetRef ref) async {
  final current = ref.read(serverConfigProvider);
  final controller = TextEditingController(text: current);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Server URL'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://192.168.1.100:8400/api',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            onSubmitted: (_) {
              _saveAndPop(ctx, controller, ref);
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Examples:\n'
            '• http://10.0.2.2:8400/api  (Android emulator)\n'
            '• http://192.168.x.x:8400/api  (LAN / physical device)',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _saveAndPop(ctx, controller, ref),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
}

void _saveAndPop(
    BuildContext ctx, TextEditingController ctrl, WidgetRef ref) {
  final url = ctrl.text.trim();
  if (url.isNotEmpty) {
    ref.read(serverConfigProvider.notifier).setUrl(url);
  }
  Navigator.of(ctx).pop();
}

// ===== Server URL tile (reused in both login & register) =====
class _ServerTile extends ConsumerWidget {
  const _ServerTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(serverConfigProvider);
    return InkWell(
      onTap: () => showServerDialog(context, ref),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.dns_outlined, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.edit_outlined, size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

// ===== Login Screen =====
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    await ref.read(authProvider.notifier).login(
          email: email,
          password: password,
        );

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      if (mounted) context.go('/home');
    } else if (authState.error != null) {
      // Show error as an AlertDialog so user can't miss it
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Login Failed'),
            content: Text(authState.error ?? 'Login failed. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Convora',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ISA Training Platform',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'your@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => authState.isLoading ? null : _handleLogin(),
                ),
                const SizedBox(height: 12),
                // Server URL row — tap to change the backend server
                const _ServerTile(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Register Screen =====
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    await ref.read(authProvider.notifier).register(
          name: name,
          email: email,
          password: password,
        );

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      if (mounted) context.go('/home');
    } else if (authState.error != null) {
      // Show error as an AlertDialog so user can't miss it
      if (mounted) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Registration Failed'),
            content: Text(authState.error ?? 'Registration failed. Please try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 12),
              // Server URL row — tap to change the backend server
              const _ServerTile(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _handleRegister,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

