import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TaskDetail.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List<String> categories = [];
  String? selectedCategory;
  String selectedTimeFilter = 'Today';
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  List<Map<String, dynamic>> tasks = [];
  bool isTodayExpanded = true;
  bool isUpcomingExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
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
            content: Text('No Internet Connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadTasks() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        var query = Supabase.instance.client
            .from('tasks')
            .select()
            .eq('user_id', user.id);

        if (selectedCategory != null) {
          query = query.eq('category', selectedCategory!);
        }

        final data = await query.order('due_date', ascending: true);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final todayTasks = <Map<String, dynamic>>[];
        final upcomingTasks = <Map<String, dynamic>>[];

        for (var task in List<Map<String, dynamic>>.from(data)) {
          if (task['due_date'] != null) {
            final taskDate = DateTime.parse(task['due_date']).toLocal();
            final taskDay =
                DateTime(taskDate.year, taskDate.month, taskDate.day);

            if (taskDay.isAtSameMomentAs(today)) {
              todayTasks.add(task);
            } else if (taskDay.isAfter(today)) {
              upcomingTasks.add(task);
            }
          }
        }

        setState(() {
          tasks = [...todayTasks, ...upcomingTasks];
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No Internet Connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTaskStatus(String taskId, bool isCompleted) async {
    try {
      await Supabase.instance.client.from('tasks').update({
        'is_completed': isCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      }).match({'id': taskId});

      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCompleted ? 'Task completed!' : 'Task uncompleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (error) {
      print('Error updating task: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveTask(String taskTitle, String? category) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.from('tasks').insert({
          'title': taskTitle,
          'category': category,
          'user_id': user.id,
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        await _loadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding task: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Pisahkan tasks menjadi today dan upcoming
    final todayTasks = tasks.where((task) {
      if (task['due_date'] == null) return false;
      final taskDate = DateTime.parse(task['due_date']).toLocal();
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      return taskDay.isAtSameMomentAs(today);
    }).toList();

    final upcomingTasks = tasks.where((task) {
      if (task['due_date'] == null) return false;
      final taskDate = DateTime.parse(task['due_date']).toLocal();
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      return taskDay.isAfter(today);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        child: ListView(
          padding: EdgeInsets.only(top: 15, left: 10, right: 10),
          children: [
            // Upcoming Section
            InkWell(
              onTap: () {
                setState(() {
                  isUpcomingExpanded = !isUpcomingExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      'Upcoming',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      isUpcomingExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            if (isUpcomingExpanded)
              ...upcomingTasks.map((task) => _buildTaskCard(task)),
            // Today Section
            InkWell(
              onTap: () {
                setState(() {
                  isTodayExpanded = !isTodayExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      isTodayExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            if (isTodayExpanded)
              ...todayTasks.map((task) => _buildTaskCard(task)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (BuildContext context) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.3,
                  decoration: BoxDecoration(
                    color: WarnaUtama,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: EdgeInsets.only(left: 16, right: 16, top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _taskController,
                              cursorColor: WarnaSecondary,
                              autofocus: true,
                              style: TextStyle(
                                color: WarnaSecondary,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Add New Task',
                                labelStyle: TextStyle(
                                  color: WarnaSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: WarnaSecondary),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                      color: WarnaSecondary, width: 0.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                      color: WarnaSecondary, width: 1),
                                ),
                                filled: true,
                                fillColor: WarnaUtama,
                                prefixIcon:
                                    Icon(Icons.task_alt, color: WarnaSecondary),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a task';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: WarnaSecondary.withOpacity(0.3),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    final taskTitle =
                                        _taskController.text.trim();
                                    final category = selectedCategory == 'All'
                                        ? null
                                        : selectedCategory;

                                    await _saveTask(taskTitle, category);
                                    _taskController.clear();
                                    Navigator.pop(context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WarnaSecondary,
                                  minimumSize: Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Add Task',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: WarnaUtama,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        backgroundColor: WarnaSecondary,
        child: Icon(Icons.add, color: WarnaUtama),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedCategory = label == 'All' ? null : label;
        });
        _loadTasks();
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

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isCompleted = task['is_completed'] ?? false;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: WarnaUtama2,
      child: ListTile(
        contentPadding: EdgeInsets.only(left: 4, right: 10),
        horizontalTitleGap: 0,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetail(
                task: task,
                onTaskUpdated: () {
                  _loadTasks();
                },
              ),
            ),
          );
        },
        leading: Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: isCompleted,
            onChanged: (bool? value) {
              if (value != null) {
                final taskId = task['id'];
                if (taskId != null) {
                  _updateTaskStatus(taskId, value);
                }
              }
            },
            activeColor: WarnaSecondary,
            checkColor: WarnaUtama,
            side: BorderSide(
              color: WarnaSecondary,
              width: 2,
            ),
            fillColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return WarnaSecondary;
                }
                return Colors.transparent;
              },
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task['title'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: WarnaSecondary,
                decorationThickness: 1.5,
              ),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  task['time'] != null ? '${task['time']}'.substring(0, 5) : '',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  task['due_date'] != null
                      ? '${DateTime.parse(task['due_date']).toLocal().toString().substring(8, 10)}-${DateTime.parse(task['due_date']).toLocal().toString().substring(5, 7)}'
                      : '',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
