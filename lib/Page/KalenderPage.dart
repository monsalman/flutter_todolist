import 'package:flutter/material.dart';
import '../main.dart';

class KalenderPage extends StatefulWidget {
  const KalenderPage({super.key});

  @override
  State<KalenderPage> createState() => _KalenderPageState();
}

class _KalenderPageState extends State<KalenderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kalender',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: WarnaUtama,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: WarnaUtama,
        child: Center(
          child: Text(
            'Halaman Kalender',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
