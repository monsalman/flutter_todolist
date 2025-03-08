import 'package:flutter/material.dart';
import '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: WarnaUtama,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: WarnaUtama,
        child: Center(
          child: Text(
            'Halaman Profile',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
