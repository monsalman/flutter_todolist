import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TaskDetail.dart';
import 'dart:async';
import 'components/AddTasks.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with TickerProviderStateMixin {
  List<String> categories = [];
  String? selectedCategory;
  String selectedTimeFilter = 'Today';
  List<Map<String, dynamic>> tasks = [];
  bool isTodayExpanded = true;
  bool isUpcomingExpanded = false;
  bool isOverdueExpanded = true;
  bool isCompletedExpanded = true;
  Timer? _timer;
  final Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTasks();

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild untuk memperbarui tampilan
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

        final overdueTasks = <Map<String, dynamic>>[];
        final todayTasks = <Map<String, dynamic>>[];
        final upcomingTasks = <Map<String, dynamic>>[];
        final completedTasks = <Map<String, dynamic>>[];

        for (var task in List<Map<String, dynamic>>.from(data)) {
          if (task['is_completed'] == true) {
            completedTasks.add(task);
            continue;
          }

          if (task['due_date'] != null) {
            final taskDate = DateTime.parse(task['due_date']).toLocal();
            final taskDay =
                DateTime(taskDate.year, taskDate.month, taskDate.day);

            if (taskDay.isBefore(today)) {
              overdueTasks.add(task);
            } else if (taskDay.isAtSameMomentAs(today)) {
              todayTasks.add(task);
            } else if (taskDay.isAfter(today)) {
              upcomingTasks.add(task);
            }
          }
        }

        setState(() {
          tasks = [
            ...upcomingTasks,
            ...todayTasks,
            ...overdueTasks,
            ...completedTasks
          ];
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdueTasks = tasks.where((task) {
      if (task['is_completed'] == true) return false;
      if (task['due_date'] == null) return false;
      final taskDate = DateTime.parse(task['due_date']).toLocal();
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      return taskDay.isBefore(today);
    }).toList();

    final todayTasks = tasks.where((task) {
      if (task['is_completed'] == true) return false;
      if (task['due_date'] == null) return false;
      final taskDate = DateTime.parse(task['due_date']).toLocal();
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      return taskDay.isAtSameMomentAs(today);
    }).toList();

    final upcomingTasks = tasks.where((task) {
      if (task['is_completed'] == true) return false;
      if (task['due_date'] == null) return false;
      final taskDate = DateTime.parse(task['due_date']).toLocal();
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      return taskDay.isAfter(today);
    }).toList();

    final completedTasks = tasks.where((task) {
      return task['is_completed'] == true;
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
            Column(
              children: [
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
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: WarnaSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${upcomingTasks.length}',
                              style: TextStyle(
                                color: WarnaUtama,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        AnimatedRotation(
                          duration: _animationDuration,
                          turns: isUpcomingExpanded ? 0.5 : 0.0,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: Column(
                    children: upcomingTasks
                        .map((task) => _buildTaskCard(task))
                        .toList(),
                  ),
                  secondChild: Container(),
                  crossFadeState: isUpcomingExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: _animationDuration,
                ),
              ],
            ),

            // Today Section
            Column(
              children: [
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
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: WarnaSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${todayTasks.length}',
                              style: TextStyle(
                                color: WarnaUtama,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        AnimatedRotation(
                          duration: _animationDuration,
                          turns: isTodayExpanded ? 0.5 : 0.0,
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: Column(
                    children: todayTasks
                        .map((task) => _buildTaskCard(task, isToday: true))
                        .toList(),
                  ),
                  secondChild: Container(),
                  crossFadeState: isTodayExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: _animationDuration,
                ),
              ],
            ),

            // Overdue Section
            if (overdueTasks.isNotEmpty)
              Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        isOverdueExpanded = !isOverdueExpanded;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            'Overdue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: WarnaSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${overdueTasks.length}',
                                style: TextStyle(
                                  color: WarnaUtama,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          AnimatedRotation(
                            duration: _animationDuration,
                            turns: isOverdueExpanded ? 0.5 : 0.0,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: Column(
                      children: overdueTasks
                          .map((task) => _buildTaskCard(task, isOverdue: true))
                          .toList(),
                    ),
                    secondChild: Container(),
                    crossFadeState: isOverdueExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: _animationDuration,
                  ),
                ],
              ),

            // Completed Section
            if (completedTasks.isNotEmpty)
              Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        isCompletedExpanded = !isCompletedExpanded;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          AnimatedRotation(
                            duration: _animationDuration,
                            turns: isCompletedExpanded ? 0.5 : 0.0,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: Column(
                      children: completedTasks
                          .map((task) => _buildTaskCard(task))
                          .toList(),
                    ),
                    secondChild: Container(),
                    crossFadeState: isCompletedExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: _animationDuration,
                  ),
                ],
              ),
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
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: AddTasks(
                  initialDate: DateTime.now(),
                  onTaskAdded: () {
                    _loadTasks();
                  },
                  onCategorySelected: (String? category) {
                    setState(() {
                      selectedCategory = category;
                    });
                    _loadTasks();
                  },
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

  Widget _buildTaskCard(Map<String, dynamic> task,
      {bool isOverdue = false, bool isToday = false}) {
    final bool isCompleted = task['is_completed'] ?? false;

    // Cek apakah task sudah lewat waktu
    bool isTimeOverdue = false;
    if (!isCompleted && task['due_date'] != null) {
      // Hanya cek overdue jika task belum completed
      final now = DateTime.now();
      final taskDate = DateTime.parse(task['due_date']).toLocal();

      if (task['time'] != null) {
        final timeparts = task['time'].split(':');
        final taskDateTime = DateTime(
          taskDate.year,
          taskDate.month,
          taskDate.day,
          int.parse(timeparts[0]),
          int.parse(timeparts[1]),
        );
        isTimeOverdue = now.isAfter(taskDateTime);
      } else {
        final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
        final today = DateTime(now.year, now.month, now.day);
        isTimeOverdue = taskDay.isBefore(today);
      }
    }

    // Warna untuk teks dan checkbox berdasarkan status completed
    final Color textColor = isCompleted ? Colors.white38 : Colors.white;
    final Color dateTimeColor = isCompleted
        ? Colors.white38
        : (isTimeOverdue ? Colors.redAccent : Colors.white70);
    final Color checkboxColor = isCompleted ? Colors.white38 : WarnaSecondary;

    // Tambahkan fungsi untuk mendapatkan warna prioritas
    Color _getPriorityColor(String? priority) {
      switch (priority?.toLowerCase()) {
        case 'high':
          return Colors.red;
        case 'medium':
          return Colors.orange;
        case 'low':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

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
            activeColor: checkboxColor,
            checkColor: WarnaUtama,
            side: BorderSide(
              color: checkboxColor,
              width: 2,
            ),
            fillColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return checkboxColor;
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  task['title'] ?? '',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: checkboxColor,
                    decorationThickness: 1.5,
                  ),
                ),
                SizedBox(width: 4),
                if (task['priority'] != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task['priority']),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Wrap(
                  spacing: 5,
                  children: [
                    if (task['time'] != null)
                      Text(
                        '${task['time']}'.substring(0, 5),
                        style: TextStyle(
                          color: dateTimeColor,
                          fontSize: 12,
                        ),
                      ),
                    if (!isToday && task['due_date'] != null)
                      Text(
                        '${DateTime.parse(task['due_date']).toLocal().toString().substring(8, 10)}-${DateTime.parse(task['due_date']).toLocal().toString().substring(5, 7)}',
                        style: TextStyle(
                          color: dateTimeColor,
                          fontSize: 12,
                        ),
                      ),
                    if (isTimeOverdue && !isCompleted)
                      Text(
                        _getOverdueText(task),
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 8),
                // Icon indicators
                Row(
                  children: [
                    if (task['subtasks'] != null &&
                        (task['subtasks'] as List).isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.checklist,
                          color: isTimeOverdue && !isCompleted
                              ? Colors.redAccent
                              : dateTimeColor,
                          size: 14,
                        ),
                      ),
                    if (task['notes'] != null &&
                        task['notes'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.sticky_note_2,
                          color: isTimeOverdue && !isCompleted
                              ? Colors.redAccent
                              : dateTimeColor,
                          size: 14,
                        ),
                      ),
                    if (task['attachments'] != null &&
                        (task['attachments'] as List).isNotEmpty)
                      Icon(
                        Icons.attach_file,
                        color: isTimeOverdue && !isCompleted
                            ? Colors.redAccent
                            : dateTimeColor,
                        size: 14,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getOverdueText(Map<String, dynamic> task) {
    final now = DateTime.now();
    final taskDate = DateTime.parse(task['due_date']).toLocal();

    if (task['time'] != null) {
      final timeparts = task['time'].split(':');
      final taskDateTime = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        int.parse(timeparts[0]),
        int.parse(timeparts[1]),
      );
      final difference = now.difference(taskDateTime);
      if (difference.inDays > 0) {
        return "(${difference.inDays}d late)";
      } else if (difference.inHours > 0) {
        return "(${difference.inHours}h late)";
      } else if (difference.inMinutes > 0) {
        return "(${difference.inMinutes}m late)";
      }
    } else {
      // Jika hanya ada tanggal (tanpa waktu)
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final difference = today.difference(taskDay);
      if (difference.inDays > 0) {
        return "(${difference.inDays}d late)";
      }
    }
    return "";
  }
}
