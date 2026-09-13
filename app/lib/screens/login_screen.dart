import 'package:flutter/material.dart';
import 'package:spacemaker/api.dart';
import 'package:spacemaker/screens/home_screen.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'test@spacemaker.app');
  final password = TextEditingController(text: 'SpaceMaker1!');
  final name = TextEditingController(text: 'Test User');
  final server = TextEditingController(text: Api.instance.baseUrl);
  bool register = false;
  bool advanced = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.instance.setBaseUrl(server.text.trim());
      if (register) {
        await Api.instance.register(name.text.trim(), email.text.trim(), password.text);
      } else {
        await Api.instance.login(email.text.trim(), password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _offline() async {
    setState(() {
      busy = true;
      error = null;
    });
    await Api.instance.continueOffline();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: 20),
            const Text('SpaceMaker', style: SM.display),
            const SizedBox(height: 6),
            const Text('Swipe left for storage', style: TextStyle(color: SM.muted, fontSize: 16, letterSpacing: -0.2)),
            const SizedBox(height: 28),
            if (register) ...[
              GhostField(controller: name, label: 'Name'),
              const SizedBox(height: 12),
            ],
            GhostField(controller: email, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            GhostField(controller: password, label: 'Password', obscure: true),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => advanced = !advanced),
              style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
              child: Text(advanced ? 'Hide server' : 'Advanced · local server', style: SM.caption.copyWith(color: SM.muted)),
            ),
            if (advanced) ...[
              GhostField(controller: server, label: 'Local server URL'),
              const SizedBox(height: 8),
              const Text('On a phone use your PC LAN IP, e.g. http://192.168.0.249:51810', style: SM.caption),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: SM.toss, fontSize: 13, height: 1.4)),
            ],
            const SizedBox(height: 20),
            GoldButton(label: busy ? 'Please wait…' : (register ? 'Create account' : 'Sign in'), onTap: busy ? () {} : _submit, enabled: !busy),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : _offline,
              style: OutlinedButton.styleFrom(
                foregroundColor: SM.cream,
                side: const BorderSide(color: SM.line),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Continue on this phone', style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Five free deletes. After that, Plus. Closing the app will not reset the trial.',
              style: SM.caption,
            ),
            TextButton(
              onPressed: () => setState(() => register = !register),
              child: Text(register ? 'Already have an account? Sign in' : 'Need an account? Register', style: SM.caption),
            ),
          ],
        ),
      ),
    );
  }
}
