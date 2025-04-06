import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../main.dart';
import '../Service/NotificationService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'TaskDetail.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> with TickerProviderStateMixin {
  List<String> categories = [];
  String? selectedCategory;
  String selectedTimeFilter = 'Today';
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  List<Map<String, dynamic>> tasks = [];
  bool isTodayExpanded = true;
  bool isUpcomingExpanded = false;
  bool isOverdueExpanded = true;
  bool isCompletedExpanded = true;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  Timer? _timer;
  final Duration _animationDuration = Duration(milliseconds: 300);
  final GlobalKey<State> _categoryKey = GlobalKey<State>();
  bool _isCategoryMenuOpen = false;

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

  Future<void> _saveTask(String taskTitle, String? category) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final taskDate = selectedDate ?? DateTime.now();

        final timeString = selectedTime != null
            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
            : null;

        // Buat task tanpa ID (Supabase akan generate UUID secara otomatis)
        final response = await Supabase.instance.client.from('tasks').insert({
          'title': taskTitle,
          'category': category,
          'user_id': user.id,
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'due_date': taskDate.toIso8601String(),
          'time': timeString,
        }).select();

        final taskId = response[0]['id'];

        // Schedule notification jika ada due date dan time
        if (timeString != null) {
          final scheduledDate = DateTime(
            taskDate.year,
            taskDate.month,
            taskDate.day,
            selectedTime!.hour,
            selectedTime!.minute,
          );

          if (scheduledDate.isAfter(DateTime.now())) {
            try {
              // Buat instance NotificationService
              final notificationService = NotificationService();

              // Generate notification ID
              final notificationId = _getNotificationId(taskId);

              // Cancel notifikasi yang sudah ada dengan ID yang sama (jika ada)
              await notificationService.cancelNotification(notificationId);

              // Schedule notifikasi baru
              await notificationService.scheduleTaskNotification(
                id: notificationId,
                title: taskTitle,
                scheduledDate: scheduledDate,
              );

              print(
                  'Notification scheduled for $scheduledDate with ID: $notificationId');
            } catch (e) {
              print('Error scheduling notification: $e');
            }
          } else {
            print('Scheduled date is in the past: $scheduledDate');
          }
        }

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

  // Perbaikan method _getNotificationId
  int _getNotificationId(String taskId) {
    try {
      // Ambil 6 karakter terakhir dari UUID dan konversi ke hexadecimal
      final lastChars = taskId.substring(taskId.length - 6);
      final intValue = int.parse(lastChars, radix: 16);
      // Pastikan nilai tidak melebihi batas maksimum notification ID
      return intValue % 100000;
    } catch (e) {
      // Fallback jika parsing gagal
      return DateTime.now().millisecondsSinceEpoch % 100000;
    }
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    DateTime? selectedDate = this.selectedDate ?? DateTime.now();
    final result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: WarnaUtama,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 20, left: 20, right: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select date',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('E, MMM d').format(selectedDate!),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon:
                                Icon(Icons.edit, color: Colors.white, size: 24),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: WarnaUtama,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFFEAE4F2).withOpacity(0.2),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left,
                                      color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      selectedDate = DateTime(
                                        selectedDate!.year,
                                        selectedDate!.month - 1,
                                        selectedDate!.day,
                                      );
                                    });
                                  },
                                ),
                                Text(
                                  DateFormat('MMMM yyyy').format(selectedDate!),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.chevron_right,
                                      color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      selectedDate = DateTime(
                                        selectedDate!.year,
                                        selectedDate!.month + 1,
                                        selectedDate!.day,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 16, left: 16, right: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                for (final day in [
                                  'SUN',
                                  'MON',
                                  'TUE',
                                  'WED',
                                  'THU',
                                  'FRI',
                                  'SAT'
                                ])
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children:
                                  _buildCalendarGrid(selectedDate!, (date) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: WarnaSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, selectedDate),
                                  child: Text(
                                    'OK',
                                    style: TextStyle(
                                      color: WarnaSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    return result;
  }

  List<Widget> _buildCalendarGrid(
      DateTime currentMonth, Function(DateTime) onSelectDate) {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final daysInPrevMonth =
        DateTime(currentMonth.year, currentMonth.month, 0).day;
    const numRows = 6;

    List<Widget> rows = [];

    int day = 1 - firstWeekday;

    // Build each row
    for (int row = 0; row < numRows; row++) {
      List<Widget> rowChildren = [];

      // Build each day cell in the row
      for (int col = 0; col < 7; col++) {
        if (day <= 0) {
          // Previous month
          final prevMonthDay = daysInPrevMonth + day;
          rowChildren.add(
            _buildDayCell(
              day: prevMonthDay,
              isCurrentMonth: false,
              isSelected: false,
              onTap: () {},
              currentMonth: DateTime(currentMonth.year, currentMonth.month - 1),
            ),
          );
        } else if (day > daysInMonth) {
          // Next month
          final nextMonthDay = day - daysInMonth;
          rowChildren.add(
            _buildDayCell(
              day: nextMonthDay,
              isCurrentMonth: false,
              isSelected: false,
              onTap: () {},
              currentMonth: DateTime(currentMonth.year, currentMonth.month + 1),
            ),
          );
        } else {
          // Current month
          final date = DateTime(currentMonth.year, currentMonth.month, day);
          final isSelected = date.year == currentMonth.year &&
              date.month == currentMonth.month &&
              date.day == currentMonth.day;

          rowChildren.add(
            _buildDayCell(
              day: day,
              isCurrentMonth: true,
              isSelected: isSelected,
              onTap: () => onSelectDate(date),
              currentMonth: currentMonth,
            ),
          );
        }
        day++;
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: rowChildren,
        ),
      );
    }

    return rows;
  }

  Widget _buildDayCell({
    required int day,
    required bool isCurrentMonth,
    required bool isSelected,
    required VoidCallback onTap,
    required DateTime currentMonth,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDate = DateTime(currentMonth.year, currentMonth.month, day);
    final isToday = today.isAtSameMomentAs(currentDate) && isCurrentMonth;

    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: isCurrentMonth ? onTap : null,
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? WarnaSecondary : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(color: WarnaSecondary, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isCurrentMonth
                      ? isSelected
                          ? Colors.black
                          : Colors.white
                      : Colors.white.withOpacity(0.3),
                  fontSize: 16,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<dynamic> _selectTime(BuildContext context) async {
    int selectedHour = selectedTime?.hour ?? TimeOfDay.now().hour;
    int selectedMinute = selectedTime?.minute ?? TimeOfDay.now().minute;
    final result = await showDialog<dynamic>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: WarnaUtama,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Select time',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Time spinner
                    Container(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Hour spinner
                          _buildTimeSpinner(
                            value: selectedHour,
                            minValue: 0,
                            maxValue: 23,
                            onChanged: (value) {
                              setState(() {
                                selectedHour = value;
                              });
                            },
                            format: (value) => value.toString().padLeft(2, '0'),
                          ),

                          // Separator
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              ':',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Minute spinner
                          _buildTimeSpinner(
                            value: selectedMinute,
                            minValue: 0,
                            maxValue: 59,
                            onChanged: (value) {
                              setState(() {
                                selectedMinute = value;
                              });
                            },
                            format: (value) => value.toString().padLeft(2, '0'),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, 'no_time');
                            },
                            child: Text(
                              'No Time',
                              style: TextStyle(
                                color: WarnaSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, 'cancel'),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: WarnaSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WarnaSecondary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(
                                    context,
                                    TimeOfDay(
                                        hour: selectedHour,
                                        minute: selectedMinute)),
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    return result;
  }

  // Tambahkan helper method untuk time spinner
  Widget _buildTimeSpinner({
    required int value,
    required int minValue,
    required int maxValue,
    required Function(int) onChanged,
    required String Function(int) format,
  }) {
    return Container(
      width: 70,
      height: 160,
      decoration: BoxDecoration(
        color: WarnaUtama,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              WarnaUtama,
              Colors.transparent,
              Colors.transparent,
              WarnaUtama,
            ],
            stops: [0.0, 0.15, 0.85, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstOut,
        child: Stack(
          children: [
            // Divider lines with increased thickness
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      height: 2, color: WarnaSecondary), // Increased thickness
                  SizedBox(height: 48),
                  Container(
                      height: 2, color: WarnaSecondary), // Increased thickness
                ],
              ),
            ),
            // Scrollable list
            ListWheelScrollView(
              controller:
                  FixedExtentScrollController(initialItem: value - minValue),
              physics: FixedExtentScrollPhysics(),
              itemExtent: 50,
              perspective: 0.005,
              diameterRatio: 1.2,
              squeeze: 1.0,
              onSelectedItemChanged: (index) => onChanged(index + minValue),
              children: List<Widget>.generate(
                maxValue - minValue + 1,
                (index) {
                  final itemValue = index + minValue;
                  return Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Text(
                      format(itemValue),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: itemValue == value
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
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
                                      borderSide:
                                          BorderSide(color: WarnaSecondary),
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
                                    prefixIcon: Icon(Icons.task_alt,
                                        color: WarnaSecondary),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a task';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    // Category section
                                    Container(
                                      key: _categoryKey,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: WarnaUtama2,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _isCategoryMenuOpen = true;
                                          });

                                          final RenderBox? button = _categoryKey
                                                  .currentContext
                                                  ?.findRenderObject()
                                              as RenderBox?;
                                          if (button != null) {
                                            final position = button
                                                .localToGlobal(Offset.zero);
                                            final size = button.size;

                                            showMenu(
                                              context: context,
                                              position: RelativeRect.fromLTRB(
                                                position.dx,
                                                position.dy -
                                                    (categories.length + 1) *
                                                        55.0,
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
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white70),
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
                                              setModalState(() {
                                                _isCategoryMenuOpen = false;
                                              });

                                              if (selectedValue ==
                                                  'add_category') {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        NavBar(
                                                      initialIndex: 2,
                                                      expandCategories: true,
                                                    ),
                                                  ),
                                                );
                                              } else if (selectedValue !=
                                                  null) {
                                                setModalState(() {
                                                  selectedCategory =
                                                      selectedValue;
                                                });
                                              }
                                            });
                                          }
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              selectedCategory ?? 'No Category',
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(width: 2),
                                            AnimatedRotation(
                                              turns:
                                                  _isCategoryMenuOpen ? 0.5 : 0,
                                              duration:
                                                  Duration(milliseconds: 200),
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
                                    // Date and Time section in a tight row
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Date button
                                          SizedBox(
                                            width: 32,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                minWidth: 32,
                                                maxWidth: 32,
                                                minHeight: 32,
                                                maxHeight: 32,
                                              ),
                                              onPressed: () async {
                                                final result =
                                                    await _selectDate(context);
                                                if (result != null) {
                                                  setModalState(() {
                                                    selectedDate = result;
                                                  });
                                                }
                                              },
                                              icon: Icon(
                                                Icons.calendar_today,
                                                color: WarnaSecondary,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                          if (selectedDate != null)
                                            Padding(
                                              padding: EdgeInsets.only(left: 5),
                                              child: Text(
                                                DateFormat('dd MMM')
                                                    .format(selectedDate!),
                                                style: TextStyle(
                                                  color: WarnaSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          SizedBox(width: 5),
                                          // Time button
                                          SizedBox(
                                            width: 32,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(
                                                minWidth: 32,
                                                maxWidth: 32,
                                                minHeight: 32,
                                                maxHeight: 32,
                                              ),
                                              onPressed: () async {
                                                final result =
                                                    await _selectTime(context);
                                                if (result != null &&
                                                    result != 'cancel') {
                                                  setModalState(() {
                                                    if (result == 'no_time') {
                                                      selectedTime = null;
                                                    } else if (result
                                                        is TimeOfDay) {
                                                      selectedTime = result;
                                                    }
                                                  });
                                                }
                                              },
                                              icon: Icon(
                                                Icons.access_time,
                                                color: WarnaSecondary,
                                                size: 28,
                                              ),
                                            ),
                                          ),
                                          if (selectedTime != null)
                                            Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Text(
                                                selectedTime!.format(context),
                                                style: TextStyle(
                                                  color: WarnaSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
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
                                        final category =
                                            selectedCategory == 'All'
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
          return Colors.transparent;
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
                    if (task['priority'] != null)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getPriorityColor(task['priority']),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (task['subtasks'] != null &&
                        (task['subtasks'] as List).isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.checklist,
                          color: dateTimeColor,
                          size: 14,
                        ),
                      ),
                    if (task['notes'] != null &&
                        task['notes'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.sticky_note_2,
                          color: dateTimeColor,
                          size: 14,
                        ),
                      ),
                    if (task['attachments'] != null &&
                        (task['attachments'] as List).isNotEmpty)
                      Icon(
                        Icons.attach_file,
                        color: dateTimeColor,
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
