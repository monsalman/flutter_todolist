import 'package:flutter/material.dart';
import 'package:flutter_todolist/Page/KategoriPage.dart';
import '../Form/LoginPage.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  final bool initiallyExpanded;

  const ProfilePage({
    super.key,
    this.initiallyExpanded = false,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = '';
  String email = '';
  List<String> categories = [];
  bool isLoading = true;
  int todayCompleted = 0;
  int totalCompleted = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCompletedTasksData();
  }

  Future<void> _loadUserData() async {
    try {
      final User? user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        final data = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        if (mounted) {
          setState(() {
            username = data['username'] ?? '';
            email = user.email ?? '';
            categories = List<String>.from(data['categories'] ?? []);
            isLoading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No Internet Connection'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCompletedTasksData() async {
    try {
      final User? user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Get all completed tasks
        final completedTasks = await Supabase.instance.client
            .from('tasks')
            .select()
            .eq('user_id', user.id)
            .eq('is_completed', true);

        // Get today's date in the format stored in Supabase
        final today = DateTime.now();
        final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

        // Count tasks completed today
        int todayCount = 0;
        for (var task in completedTasks) {
          // Check if the task has a date_completed field
          if (task['date_completed'] != null) {
            // Extract just the date part for comparison
            final completedDate =
                task['date_completed'].toString().split('T')[0];
            if (completedDate == todayFormatted) {
              todayCount++;
            }
          }
        }

        if (mounted) {
          setState(() {
            totalCompleted = completedTasks.length;
            todayCompleted = todayCount;
          });
        }
      }
    } catch (error) {
      print('Error loading completed tasks: $error');
      // Continue silently, keeping the default values (0)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: WarnaUtama,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 40),
                  if (isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: WarnaSecondary,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Username:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              username,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Email:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 5),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 25),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 100,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Today Completed',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      todayCompleted.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                height: 100,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Total Completed',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      totalCompleted.toString(),
                                      style: TextStyle(
                                        color: WarnaSecondary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => KategoriPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Manage Categories',
                              style: TextStyle(
                                color: WarnaSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Divider(
                          color: Colors.white24,
                          height: 1,
                        ),
                        SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: WarnaUtama,
                                    title: Text(
                                      'Konfirmasi Logout',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      'Apakah anda yakin ingin keluar?',
                                      style: TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context)
                                              .pop(); // Close dialog
                                        },
                                        child: Text(
                                          'Batal',
                                          style: TextStyle(
                                            color: WarnaSecondary,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.of(context)
                                              .pop(); // Close dialog
                                          try {
                                            await Supabase.instance.client.auth
                                                .signOut();
                                            if (mounted) {
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        LoginPage()),
                                                (route) => false,
                                              );
                                            }
                                          } catch (error) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      // 'Error logging out: ${error.toString()}'),
                                                      'Logout gagal Silahkan Coba Lagi!'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Text(
                                          'Logout',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WarnaUtama,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                                side: BorderSide(color: Colors.red, width: 2),
                              ),
                            ),
                            child: Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
