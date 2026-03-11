import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convora Greeting',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const GreetPage(),
    );
  }
}

class GreetPage extends StatefulWidget {
  const GreetPage({super.key});

  @override
  State<GreetPage> createState() => _GreetPageState();
}

class _GreetPageState extends State<GreetPage> {
  final TextEditingController _controller = TextEditingController();
  String _greeting = '';
  String _error = '';
  bool _loading = false;

  static const String _baseUrl = 'http://10.0.2.2:8000';

  Future<void> _callGreet() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Please enter a name';
        _greeting = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _greeting = '';
    });

    try {
      final uri = Uri.parse('$_baseUrl/greet/${Uri.encodeComponent(name)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        setState(() {
          _greeting = resp.body; // plain text expected: Hello, Name
          _error = '';
        });
      } else {
        setState(() {
          _error = 'Server error: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Greeting Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter your name:'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'e.g., Justin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _callGreet,
              child: _loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Greet Me'),
            ),
            const SizedBox(height: 24),
            if (_greeting.isNotEmpty)
              Text(
                _greeting,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            if (_error.isNotEmpty)
              Text(
                _error,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
