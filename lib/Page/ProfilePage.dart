import 'package:flutter/material.dart';
import '../Form/LoginPage.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String username = '';
  String email = '';
  List<String> categories = [];
  bool isLoading = true;
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
            content: Text('Error loading profile: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _addCategory() async {
    if (_categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama kategori tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final newCategories = [...categories, _categoryController.text.trim()];

      await Supabase.instance.client
          .from('users')
          .update({'categories': newCategories}).eq(
              'id', Supabase.instance.client.auth.currentUser!.id);

      setState(() {
        categories = newCategories;
      });

      _categoryController.clear();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kategori berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menambah kategori: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateCategory(int index, String newName) async {
    if (newName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nama kategori tidak boleh kosong'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final newCategories = [...categories];
      newCategories[index] = newName.trim();

      await Supabase.instance.client
          .from('users')
          .update({'categories': newCategories}).eq(
              'id', Supabase.instance.client.auth.currentUser!.id);

      setState(() {
        categories = newCategories;
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kategori berhasil diupdate'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengupdate kategori: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(int index) async {
    try {
      final newCategories = [...categories];
      newCategories.removeAt(index);

      await Supabase.instance.client
          .from('users')
          .update({'categories': newCategories}).eq(
              'id', Supabase.instance.client.auth.currentUser!.id);

      setState(() {
        categories = newCategories;
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kategori berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menghapus kategori: ${error.toString()}'),
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
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              'Kategori',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            iconColor: WarnaSecondary,
                            collapsedIconColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            childrenPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              Column(
                                children: [
                                  if (categories.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 16),
                                      child: Center(
                                        child: Text(
                                          'Belum ada kategori',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                                0.4,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            ListView.separated(
                                              shrinkWrap: true,
                                              physics:
                                                  NeverScrollableScrollPhysics(),
                                              itemCount: categories.length,
                                              separatorBuilder:
                                                  (context, index) => Divider(
                                                color: Colors.white24,
                                                height: 1,
                                              ),
                                              itemBuilder: (context, index) {
                                                return ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    categories[index],
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  trailing: Container(
                                                    width: 100,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(Icons.edit,
                                                              color:
                                                                  WarnaSecondary,
                                                              size: 20),
                                                          onPressed: () {
                                                            _categoryController
                                                                    .text =
                                                                categories[
                                                                    index];
                                                            showDialog(
                                                              context: context,
                                                              builder:
                                                                  (context) =>
                                                                      AlertDialog(
                                                                backgroundColor:
                                                                    WarnaUtama,
                                                                title: Text(
                                                                  'Edit Kategori',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                content:
                                                                    TextField(
                                                                  controller:
                                                                      _categoryController,
                                                                  autofocus:
                                                                      true,
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                  cursorColor:
                                                                      WarnaSecondary,
                                                                  decoration:
                                                                      InputDecoration(
                                                                    hintText:
                                                                        'Nama Kategori',
                                                                    hintStyle: TextStyle(
                                                                        color: Colors
                                                                            .white54),
                                                                    enabledBorder:
                                                                        UnderlineInputBorder(
                                                                      borderSide:
                                                                          BorderSide(
                                                                              color: WarnaSecondary),
                                                                    ),
                                                                    focusedBorder:
                                                                        UnderlineInputBorder(
                                                                      borderSide:
                                                                          BorderSide(
                                                                              color: WarnaSecondary),
                                                                    ),
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context),
                                                                    child: Text(
                                                                      'Batal',
                                                                      style:
                                                                          TextStyle(
                                                                        color:
                                                                            WarnaSecondary,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed:
                                                                        () {
                                                                      if (_categoryController
                                                                          .text
                                                                          .trim()
                                                                          .isEmpty) {
                                                                        ScaffoldMessenger.of(context)
                                                                            .showSnackBar(
                                                                          SnackBar(
                                                                            content:
                                                                                Text('Nama kategori tidak boleh kosong'),
                                                                            backgroundColor:
                                                                                Colors.red,
                                                                          ),
                                                                        );
                                                                        return;
                                                                      }
                                                                      _updateCategory(
                                                                          index,
                                                                          _categoryController
                                                                              .text);
                                                                    },
                                                                    child: Text(
                                                                      'Simpan',
                                                                      style:
                                                                          TextStyle(
                                                                        color:
                                                                            WarnaSecondary,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        IconButton(
                                                          icon: Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color: Colors.red,
                                                              size: 20),
                                                          onPressed: () =>
                                                              showDialog(
                                                            context: context,
                                                            builder:
                                                                (context) =>
                                                                    AlertDialog(
                                                              backgroundColor:
                                                                  WarnaUtama,
                                                              title: Text(
                                                                'Hapus Kategori',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white),
                                                              ),
                                                              content: Text(
                                                                'Yakin ingin menghapus kategori ini?',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white70),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context),
                                                                  child: Text(
                                                                    'Batal',
                                                                    style: TextStyle(
                                                                        color:
                                                                            WarnaSecondary),
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      _deleteCategory(
                                                                          index),
                                                                  child: Text(
                                                                    'Hapus',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .red),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.add, color: WarnaUtama),
                                      label: Text(
                                        'Tambah Kategori',
                                        style: TextStyle(
                                          color: WarnaUtama,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onPressed: () {
                                        _categoryController.clear();
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: WarnaUtama,
                                            title: Text(
                                              'Tambah Kategori',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            content: TextField(
                                              controller: _categoryController,
                                              autofocus: true,
                                              style: TextStyle(
                                                  color: Colors.white),
                                              cursorColor: WarnaSecondary,
                                              decoration: InputDecoration(
                                                hintText: 'Nama Kategori',
                                                hintStyle: TextStyle(
                                                    color: Colors.white54),
                                                enabledBorder:
                                                    UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: WarnaSecondary),
                                                ),
                                                focusedBorder:
                                                    UnderlineInputBorder(
                                                  borderSide: BorderSide(
                                                      color: WarnaSecondary),
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  'Batal',
                                                  style: TextStyle(
                                                    color: WarnaSecondary,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  if (_categoryController.text
                                                      .trim()
                                                      .isEmpty) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Nama kategori tidak boleh kosong'),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  _addCategory();
                                                },
                                                child: Text(
                                                  'Simpan',
                                                  style: TextStyle(
                                                    color: WarnaSecondary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: WarnaSecondary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                ],
                              ),
                            ],
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
