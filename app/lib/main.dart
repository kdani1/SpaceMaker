import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spacemaker/api.dart';
import 'package:spacemaker/entitlement.dart';
import 'package:spacemaker/screens/home_screen.dart';
import 'package:spacemaker/screens/login_screen.dart';
import 'package:spacemaker/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Entitlement.instance.load();
  await Api.instance.load();
  runApp(const SpaceMakerApp());
}

class SpaceMakerApp extends StatelessWidget {
  const SpaceMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpaceMaker',
      debugShowCheckedModeBanner: false,
      theme: SM.dark,
      home: Api.instance.user == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
