import 'package:flutter/material.dart';

import '../main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Home Page',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: WarnaUtama,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: WarnaUtama,
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: 10,
          itemBuilder: (context, index) {
            return Card(
              margin: EdgeInsets.only(bottom: 20),
              color: Color(0xFF2F253D),
              child: ListTile(
                // leading: CircleAvatar(
                //   backgroundColor: WarnaSecondary,
                //   child: Text(
                //     '${index + 1}',
                //     style: TextStyle(color: WarnaUtama),
                //   ),
                // ),
                title: Text(
                  'Item ${index + 1}',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'Deskripsi untuk item ${index + 1}',
                  style: TextStyle(color: Colors.white70),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: WarnaSecondary,
                ),
                onTap: () {
                  print('Item ${index + 1} ditekan');
                },
              ),
            );
          },
        ),
      ),
    );
  }
}