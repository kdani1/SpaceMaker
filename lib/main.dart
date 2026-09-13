import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spacemaker/ads.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/subscriptions.dart';
import 'package:spacemaker/screens/home_screen.dart';
import 'package:spacemaker/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Entitlement.instance.load();
  runApp(const SpaceMakerApp());
}

class SpaceMakerApp extends StatefulWidget {
  const SpaceMakerApp({super.key});
  @override
  State<SpaceMakerApp> createState() => _SpaceMakerAppState();
}

class _SpaceMakerAppState extends State<SpaceMakerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Subscriptions.instance.initialize();
      if (Entitlement.instance.adsChosen) unawaited(Ads.instance.start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(Subscriptions.instance.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SpaceMaker',
    debugShowCheckedModeBanner: false,
    theme: SM.dark,
    builder: (context, child) => SafeArea(top: false, child: child!),
    home: const HomeScreen(),
  );
}
