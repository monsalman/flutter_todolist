import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskDetail extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTaskUpdated;

  const TaskDetail({
    Key? key,
    required this.task,
    required this.onTaskUpdated,
  }) : super(key: key);

  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  late TextEditingController _titleController;
  List<Map<String, dynamic>> subtasks = [];
  bool _showInputField = false;
  List<String> categories = [];
  final GlobalKey _categoryKey = GlobalKey();
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task['title']);
    if (widget.task['subtasks'] != null) {
      subtasks = (widget.task['subtasks'] as List).map((item) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        } else {
          return {'title': item.toString(), 'isCompleted': false};
        }
      }).toList();
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
          });
        }
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

  Future<void> _updateCategory(String? newCategory) async {
    if (newCategory == widget.task['category']) {
      return;
    }

    try {
      await Supabase.instance.client.from('tasks').update({
        'category': newCategory,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      setState(() {
        widget.task['category'] = newCategory;
      });
      widget.onTaskUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating category: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addSubtask(String subtask) async {
    try {
      setState(() {
        subtasks.add({'title': subtask, 'isCompleted': false});
        _showInputField = false;
      });

      await Supabase.instance.client.from('tasks').update({
        'subtasks': subtasks,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      widget.onTaskUpdated();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving subtask: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSubtask(int index) async {
    try {
      setState(() {
        subtasks.removeAt(index);
      });

      await Supabase.instance.client.from('tasks').update({
        'subtasks': subtasks,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      widget.onTaskUpdated();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting subtask: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleSubtask(int index) async {
    try {
      setState(() {
        subtasks[index]['isCompleted'] = !subtasks[index]['isCompleted'];
      });

      await Supabase.instance.client.from('tasks').update({
        'subtasks': subtasks,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      widget.onTaskUpdated();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating subtask: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleInputField() {
    setState(() {
      _showInputField = !_showInputField;
    });
  }

  // Tambahkan method untuk mengurutkan subtasks
  List<Map<String, dynamic>> _getSortedSubtasks() {
    return [...subtasks]..sort((a, b) {
        if (a['isCompleted'] && !b['isCompleted']) return 1;
        if (!a['isCompleted'] && b['isCompleted']) return -1;
        return 0;
      });
  }

  @override
  Widget build(BuildContext context) {
    // Dapatkan subtasks yang sudah diurutkan
    final sortedSubtasks = _getSortedSubtasks();

    return Scaffold(
      backgroundColor: WarnaUtama,
      appBar: AppBar(
        backgroundColor: WarnaUtama2,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.task['title'] ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 15),
              if (subtasks.isNotEmpty)
                Text(
                  'Subtasks:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              for (var i = 0; i < sortedSubtasks.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.only(
                    left: 5,
                  ),
                  minLeadingWidth: 0,
                  horizontalTitleGap: 0,
                  title: Text(
                    sortedSubtasks[i]['title'],
                    style: TextStyle(
                      color: Colors.white,
                      decoration: sortedSubtasks[i]['isCompleted']
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: WarnaSecondary,
                      decorationThickness: 1.5,
                    ),
                  ),
                  leading: Transform.scale(
                    scale: 1.2,
                    child: Checkbox(
                      value: sortedSubtasks[i]['isCompleted'],
                      onChanged: (bool? value) {
                        if (value != null) {
                          // Cari index asli di list subtasks
                          final originalIndex = subtasks.indexWhere((task) =>
                              task['title'] == sortedSubtasks[i]['title']);
                          _toggleSubtask(originalIndex);
                        }
                      },
                      activeColor: WarnaSecondary,
                      checkColor: WarnaUtama,
                      side: BorderSide(
                        color: WarnaSecondary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      fillColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.selected)) {
                            return WarnaSecondary;
                          }
                          return Colors.transparent;
                        },
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.white70),
                    onPressed: () {
                      // Cari index asli di list subtasks
                      final originalIndex = subtasks.indexWhere((task) =>
                          task['title'] == sortedSubtasks[i]['title']);
                      _deleteSubtask(originalIndex);
                    },
                  ),
                ),
              _showInputField
                  ? Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: TextField(
                          autofocus: true,
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _addSubtask(value);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Input the sub-task',
                            hintStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              height: 1,
                            ),
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white70),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: WarnaSecondary, width: 1.5),
                            ),
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: WarnaSecondary,
                        ),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.only(left: 5, top: 0),
                      child: TextButton.icon(
                        onPressed: _toggleInputField,
                        icon: Icon(
                          Icons.add,
                          color: WarnaSecondary,
                          size: 25,
                        ),
                        label: Text(
                          'Add Subtask',
                          style: TextStyle(
                            color: WarnaSecondary,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
              SizedBox(height: 20),

              // Card 1: Date and Time Settings
              Container(
                decoration: BoxDecoration(
                  color: WarnaUtama2,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // Due Date Row
                    ListTile(
                      leading: Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                      ),
                      title: Text(
                        'Due Date',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['due_date'] ?? '2025/03/13',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Implement date picker
                      },
                    ),

                    Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),

                    // Time Row
                    ListTile(
                      leading: Icon(
                        Icons.access_time,
                        color: Colors.white,
                      ),
                      title: Text(
                        'Time',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['time'] ?? 'No',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Implement time picker
                      },
                    ),

                    Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),

                    // Reminder Row
                    ListTile(
                      leading: Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                      title: Text(
                        'Reminder at',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['reminder'] ?? 'No',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Implement reminder setting
                      },
                    ),

                    Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),

                    // Repeat Row
                    ListTile(
                      leading: Icon(
                        Icons.repeat,
                        color: Colors.white,
                      ),
                      title: Text(
                        'Repeat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['repeat'] ?? 'No',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Implement repeat setting
                      },
                    ),
                  ],
                ),
              ),

              // Card 2: Notes and Attachments
              Container(
                decoration: BoxDecoration(
                  color: WarnaUtama2,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // Notes Row
                    ListTile(
                      leading: Icon(
                        Icons.note,
                        color: Colors.white,
                      ),
                      title: Text(
                        'Notes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['notes'] != null &&
                                    widget.task['notes'].isNotEmpty
                                ? 'View'
                                : 'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Implement notes editor
                      },
                    ),

                    Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),

                    // Attachment Row
                    ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_file,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      title: Text(
                        'Attachment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['attachment'] != null ? 'View' : 'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      onTap: () {
                        // TODO: Implement attachment handling
                      },
                    ),
                  ],
                ),
              ),

              Text(
                'Category:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMenuOpen = true;
                  });

                  final RenderBox? button = _categoryKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  if (button != null) {
                    final position = button.localToGlobal(Offset.zero);
                    final size = button.size;

                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        position.dx,
                        position.dy + 40,
                        position.dx + size.width,
                        position.dy,
                      ),
                      color: WarnaUtama2,
                      items: [
                        ...categories.map(
                          (category) => PopupMenuItem(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'add_category',
                          child: Row(
                            children: [
                              Icon(
                                Icons.add,
                                color: WarnaSecondary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add Category',
                                style: TextStyle(
                                  color: WarnaSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).then((selectedValue) {
                      setState(() {
                        _isMenuOpen = false;
                      });

                      if (selectedValue == 'add_category') {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NavBar(
                              initialIndex: 2,
                              expandCategories: true,
                            ),
                          ),
                        );
                      } else if (selectedValue != null) {
                        _updateCategory(selectedValue);
                      }
                    });
                  }
                },
                child: Container(
                  key: _categoryKey,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: WarnaUtama2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.task['category'] ?? 'No Category',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 5),
                      AnimatedRotation(
                        turns: _isMenuOpen ? 0.5 : 0,
                        duration: Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
