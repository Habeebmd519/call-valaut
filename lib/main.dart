import 'package:callvault/screens/home_screen.dart';
import 'package:callvault/screens/test_screem.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(myApp());
}

class myApp extends StatelessWidget {
  const myApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: TestPage());
  }
}
