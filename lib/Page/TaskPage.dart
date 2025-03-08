import 'package:flutter/material.dart';
import '../main.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tugas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: WarnaUtama,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: WarnaUtama,
        child: Center(
          child: Text(
            'Halaman Tugas',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
