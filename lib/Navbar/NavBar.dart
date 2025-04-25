import 'package:flutter/material.dart';
import '../Page/KalenderPage.dart';
import '../Page/TaskPage.dart';
import '../Page/ProfilePage.dart';
import '../main.dart';

class NavBar extends StatefulWidget {
  final int initialIndex;
  final bool expandCategories;

  const NavBar({
    super.key,
    this.initialIndex = 0,
    this.expandCategories = false,
  });

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  static List<Widget> _pages(bool expandCategories) => [
        const KalenderPage(),
        const TaskPage(),
        ProfilePage(initiallyExpanded: expandCategories),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages(widget.expandCategories)[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: WarnaUtama2,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.calendar_today),
                ),
                label: 'Kalender',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.assignment),
                ),
                label: 'Tugas',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.person),
                ),
                label: 'Profile',
              ),
            ],
            currentIndex: _selectedIndex,
            backgroundColor: WarnaUtama2,
            selectedItemColor: WarnaSecondary,
            unselectedItemColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
