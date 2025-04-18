import 'package:flutter/material.dart';
import 'package:flutter_todolist/Form/LoginPage.dart';
import 'package:flutter_todolist/main.dart';
import 'package:flutter_todolist/Navbar/NavBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(Duration(seconds: 3));

    final Session? session = Supabase.instance.client.auth.currentSession;

    if (mounted) {
      if (session != null) {
        // User is logged in, navigate to NavBar
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => NavBar()),
        );
      } else {
        // User is not logged in, navigate to LoginPage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WarnaUtama,
      body: Center(
        child: Image.asset(
          'Assets/TodoSplash.png',
          width: 200,
          height: 200,
        ),
      ),
    );
  }
}
