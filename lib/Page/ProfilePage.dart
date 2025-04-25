import 'package:flutter/material.dart';
import 'package:flutter_todolist/Page/KategoriPage.dart';
import '../Form/LoginPage.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

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
  int overdueCount = 0;
  String? profileImageUrl;
  String? profileImagePath;
  bool isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();

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

            if (data['profile_image_url'] != null) {
              final String storedValue = data['profile_image_url'];

              if (storedValue.startsWith('http')) {
                try {
                  final uri = Uri.parse(storedValue);
                  final pathSegments = uri.pathSegments;

                  for (var segment in pathSegments) {
                    if (segment.contains(user.id) ||
                        segment.endsWith('.jpg') ||
                        segment.endsWith('.png') ||
                        segment.endsWith('.jpeg')) {
                      profileImagePath = segment;
                      break;
                    }
                  }

                  if (profileImagePath != null) {
                    _generateFreshImageUrl();
                  } else {
                    profileImageUrl = storedValue;
                  }
                } catch (e) {
                  print('Error parsing URL: $e');
                  profileImageUrl = storedValue;
                }
              } else {
                profileImagePath = storedValue;
                _generateFreshImageUrl();
              }
            }

            isLoading = false;
          });
        }
      }
    } catch (error) {
      print('Error loading user data: $error');
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
        final tasks = await Supabase.instance.client
            .from('tasks')
            .select()
            .eq('user_id', user.id);

        final completedTasks =
            tasks.where((task) => task['is_completed'] == true).toList();

        final today = DateTime.now();
        final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

        int todayCount = 0;
        for (var task in completedTasks) {
          if (task['date_completed'] != null) {
            final completedDate =
                task['date_completed'].toString().split('T')[0];
            if (completedDate == todayFormatted) {
              todayCount++;
            }
          }
        }

        final now = DateTime.now();
        final todayDate = DateTime(now.year, now.month, now.day);

        int overdue = 0;
        for (var task in tasks) {
          if (task['is_completed'] == true) continue;

          if (task['due_date'] != null) {
            final taskDate = DateTime.parse(task['due_date']).toLocal();
            final taskDay =
                DateTime(taskDate.year, taskDate.month, taskDate.day);

            if (taskDay.isBefore(todayDate)) {
              overdue++;
            }
          }
        }

        if (mounted) {
          setState(() {
            totalCompleted = completedTasks.length;
            todayCompleted = todayCount;
            overdueCount = overdue;
          });
        }
      }
    } catch (error) {
      print('Error loading tasks data: $error');
    }
  }

  Future<void> _generateFreshImageUrl() async {
    if (profileImagePath == null) return;

    try {
      final freshUrl = await Supabase.instance.client.storage
          .from('profile_images')
          .createSignedUrl(profileImagePath!, 60 * 60);

      if (mounted) {
        setState(() {
          profileImageUrl = freshUrl;
        });
      }
    } catch (error) {
      print('Error generating fresh image URL: $error');
    }
  }

  Future<void> _uploadProfileImage() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(
              color: WarnaUtama2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Choose Image Source',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: WarnaUtama.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.photo_library, color: WarnaSecondary),
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: WarnaUtama.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.camera_alt, color: WarnaSecondary),
                  ),
                  title: Text(
                    'Take a Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: WarnaSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        isUploadingImage = true;
      });

      final User? user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userData = await Supabase.instance.client
          .from('users')
          .select('profile_image_url')
          .eq('id', user.id)
          .single();

      final currentValue = userData['profile_image_url'] as String?;

      if (currentValue != null && currentValue.isNotEmpty) {
        try {
          String? fileToDelete;

          if (currentValue.startsWith('http')) {
            try {
              final uri = Uri.parse(currentValue);
              final pathSegments = uri.pathSegments;

              for (var segment in pathSegments) {
                if (segment.contains(user.id) ||
                    segment.endsWith('.jpg') ||
                    segment.endsWith('.png') ||
                    segment.endsWith('.jpeg')) {
                  fileToDelete = segment;
                  break;
                }
              }
            } catch (e) {
              print('Error parsing URL: $e');
            }
          } else {
            fileToDelete = currentValue;
          }

          if (fileToDelete != null) {
            print('Attempting to delete old image: $fileToDelete');
            await Supabase.instance.client.storage
                .from('profile_images')
                .remove([fileToDelete]);
            print('Old image successfully deleted');
          } else {
            final listResult = await Supabase.instance.client.storage
                .from('profile_images')
                .list();

            final userFilePrefix = '${user.id}_';
            for (var file in listResult) {
              if (file.name.startsWith(userFilePrefix)) {
                print('Deleting old image: ${file.name}');
                await Supabase.instance.client.storage
                    .from('profile_images')
                    .remove([file.name]);
              }
            }
          }
        } catch (deleteError) {
          print('Error deleting old image: $deleteError');
        }
      }

      final String fileExtension = path.extension(image.path);
      final String fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      final File file = File(image.path);
      await Supabase.instance.client.storage.from('profile_images').upload(
          fileName, file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

      print('Profile image successfully uploaded');

      final String signedUrl = await Supabase.instance.client.storage
          .from('profile_images')
          .createSignedUrl(fileName, 60 * 60);

      await Supabase.instance.client
          .from('users')
          .update({'profile_image_url': fileName}).eq('id', user.id);

      print('Profile image filename stored in database');

      setState(() {
        profileImageUrl = signedUrl;
        profileImagePath = fileName;
        isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      print('Error uploading profile image: $error');

      if (error is StorageException) {
        print('Storage error code: ${error.statusCode}');
        print('Storage error message: ${error.message}');
        print('Storage error details: ${error.error}');
      }

      setState(() {
        isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to upload profile image: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: _uploadProfileImage,
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor:
                                          WarnaSecondary.withOpacity(0.3),
                                      backgroundImage: profileImageUrl != null
                                          ? NetworkImage(profileImageUrl!)
                                          : null,
                                      child: profileImageUrl == null
                                          ? Icon(
                                              Icons.person,
                                              size: 70,
                                              color: WarnaSecondary,
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: WarnaSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        color: WarnaUtama,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  if (isUploadingImage)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: WarnaSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to change profile picture',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 20),
                            ],
                          ),
                        ),
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
                          width: double.infinity,
                          height: 100,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Overdue Tasks',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                overdueCount.toString(),
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
                              ).then((_) {
                                _loadUserData();
                                _loadCompletedTasksData();
                              });
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
                                          Navigator.of(context).pop();
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
                                          Navigator.of(context).pop();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (profileImagePath != null) {
      _generateFreshImageUrl();
    }
  }
}
