import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List<String> categories = [];
  String? selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('users')
            .select('categories')
            .eq('id', user.id)
            .single();

        setState(() {
          categories = List<String>.from(data['categories'] ?? []);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: WarnaUtama,
        elevation: 0,
        flexibleSpace: Container(
          alignment: Alignment.bottomLeft,
          padding: EdgeInsets.only(bottom: 10, left: 6),
          color: WarnaUtama2,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('All', selectedCategory == null),
                      if (categories.isNotEmpty) ...[
                        SizedBox(width: 8),
                        ...categories
                            .map((category) => Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: _buildCategoryChip(
                                      category, selectedCategory == category),
                                ))
                            .toList(),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NavBar(
                        initialIndex: 2,
                        expandCategories: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Container(
        color: WarnaUtama,
        child: SafeArea(
          child: Center(
            child: Text(
              'Halaman Tugas',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedCategory = label == 'All' ? null : label;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? WarnaSecondary : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? WarnaUtama : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
