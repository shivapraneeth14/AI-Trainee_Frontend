import 'package:flutter/material.dart';
import '/Pages/Videoupload.dart';
import 'Mainscreen.dart';
import 'Pages/Login.dart';

void main() {
  runApp(MyApp()); // removed const
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIH Platform',
      theme: ThemeData(primarySwatch: Colors.orange),

      // Start with LoginPage first
      initialRoute: '/login',

      routes: {
        '/': (context) => const MainScreen(),
        '/login': (context) => const LoginPage(),
        '/videoupload': (context) => const VideoUploadPage(),
      },
    );
  }
}
