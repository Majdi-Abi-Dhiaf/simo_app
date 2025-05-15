import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:simo_app_scada/LoginScreen.dart';
import 'NotiService.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotiService().initNotification();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Firestore',
      home: LoginScreen(),
    );
  }
}
