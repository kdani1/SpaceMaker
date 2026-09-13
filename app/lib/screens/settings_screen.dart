import 'package:flutter/material.dart';
import 'package:spacemaker/api.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/screens/paywall_screen.dart';
import 'package:spacemaker/theme.dart';
import 'package:spacemaker/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController server;

  @override
  void initState() {
    super.initState();
    server = TextEditingController(text: Api.instance.baseUrl);
  }

  @override
  void dispose() {
    server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Api.instance.user;
    final bill = Entitlement.instance;
    return Scaffold(
      appBar: AppBar(title: const BrandMark(size: 28, showWordmark: true, compact: true)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(user?.email ?? 'This phone', style: SM.title),
          const SizedBox(height: 4),
          Text(bill.statusLabel, style: const TextStyle(color: SM.muted, fontSize: 14)),
          const SizedBox(height: 20),
          if (!bill.isPlus) ...[
            GoldButton(
              label: 'Unlock Plus',
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 20),
          ],
          GhostField(controller: server, label: 'Backend URL'),
          const SizedBox(height: 12),
          GoldButton(
            label: 'Save server',
            onTap: () async {
              await Api.instance.setBaseUrl(server.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server saved')));
              }
            },
          ),
          const SizedBox(height: 28),
          const Text(
            'Deletes go to the system trash. Photos stay on this phone. The five free deletes are remembered on the device, so closing the app will not start a new trial.',
            style: SM.body,
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () async {
              await Api.instance.logout();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Log out', style: TextStyle(color: SM.toss)),
          ),
        ],
      ),
    );
  }
}
