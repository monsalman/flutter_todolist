import 'package:flutter/material.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KategoriPage extends StatefulWidget {
  const KategoriPage({Key? key}) : super(key: key);

  @override
  State<KategoriPage> createState() => _KategoriPageState();
}

class _KategoriPageState extends State<KategoriPage> {
  List<String> categories = [];
  bool isLoading = true;
  final TextEditingController _categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
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
      final oldCategoryName = categories[index];
      final newCategories = [...categories];
      newCategories[index] = newName.trim();

      await Supabase.instance.client
          .from('users')
          .update({'categories': newCategories}).eq(
              'id', Supabase.instance.client.auth.currentUser!.id);

      await Supabase.instance.client
          .from('tasks')
          .update({'category': newName.trim()})
          .eq('category', oldCategoryName)
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

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
      final categoryToDelete = categories[index];
      final newCategories = [...categories];
      newCategories.removeAt(index);

      await Supabase.instance.client
          .from('users')
          .update({'categories': newCategories}).eq(
              'id', Supabase.instance.client.auth.currentUser!.id);

      await Supabase.instance.client
          .from('tasks')
          .update({'category': null})
          .eq('category', categoryToDelete)
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

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
      backgroundColor: WarnaUtama,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 16.0, top: 35.0, right: 16.0, bottom: 10.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Kategori',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: WarnaSecondary,
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categories.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 50.0),
                                child: Text(
                                  'Belum ada kategori',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              padding:
                                  EdgeInsets.only(top: 8, left: 16, right: 16),
                              itemCount: categories.length,
                              separatorBuilder: (context, index) => Divider(
                                color: Colors.white24,
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                return Container(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          categories[index],
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: WarnaSecondary,
                                          size: 24,
                                        ),
                                        onPressed: () {
                                          _categoryController.text =
                                              categories[index];
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: WarnaUtama,
                                              title: Text(
                                                'Edit Kategori',
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
                                                    _updateCategory(
                                                        index,
                                                        _categoryController
                                                            .text);
                                                  },
                                                  child: Text(
                                                    'Simpan',
                                                    style: TextStyle(
                                                      color: WarnaSecondary,
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
                                          Icons.delete_outline,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        onPressed: () => showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: WarnaUtama,
                                            title: Text(
                                              'Delete Kategori',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete this Kategori?',
                                              style: TextStyle(
                                                  color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                      color: WarnaSecondary),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _deleteCategory(index),
                                                child: Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                      color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: () {
                                  _categoryController.clear();
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: WarnaUtama,
                                      title: Text(
                                        'Tambah Kategori',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: TextField(
                                        controller: _categoryController,
                                        autofocus: true,
                                        style: TextStyle(color: Colors.white),
                                        cursorColor: WarnaSecondary,
                                        decoration: InputDecoration(
                                          hintText: 'Nama Kategori',
                                          hintStyle:
                                              TextStyle(color: Colors.white54),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                                color: WarnaSecondary),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
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
                                            Navigator.pop(context);
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Tambah kategori',
                                  style: TextStyle(
                                    color: WarnaUtama,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
  }
}
