import 'package:flutter/material.dart';
import 'package:flutter_todolist/Page/KategoriPage.dart';
import '../Service/NotificationService.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}

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
  bool _isCategoryMenuOpen = false;
  bool _isPriorityMenuOpen = false;
  final ImagePicker _picker = ImagePicker();
  List<String> _attachmentPaths = [];
  List<String> _attachmentUrls = [];
  bool _isUploading = false;
  final NotificationService _notificationService = NotificationService();
  final GlobalKey _priorityKey = GlobalKey();
  int _defaultReminderMinutes = 15;
  final List<int> _reminderOptions = [5, 10, 15, 30, 60, 120, 1440];

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

    if (widget.task['attachments'] != null) {
      _attachmentPaths = List<String>.from(widget.task['attachments']);
      _attachmentUrls = [];
      _loadAttachmentUrls();
    }
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
            content: Text('No Internet Connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reloadTaskData() async {
    try {
      final data = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('id', widget.task['id'])
          .single();

      if (mounted) {
        setState(() {
          widget.task['category'] = data['category'];
          widget.task['title'] = data['title'];
          widget.task['priority'] = data['priority'];
          widget.task['due_date'] = data['due_date'];
          widget.task['time'] = data['time'];
          widget.task['notes'] = data['notes'];

          if (data['subtasks'] != null) {
            subtasks = (data['subtasks'] as List).map((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              } else {
                return {'title': item.toString(), 'isCompleted': false};
              }
            }).toList();
          }
        });
      }
    } catch (error) {
      if (mounted) {
        print('Error reloading task data: $error');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
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

  List<Map<String, dynamic>> _getSortedSubtasks() {
    return [...subtasks]..sort((a, b) {
        if (a['isCompleted'] && !b['isCompleted']) return 1;
        if (!a['isCompleted'] && b['isCompleted']) return -1;
        return 0;
      });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = widget.task['due_date'] != null
        ? DateTime.parse(widget.task['due_date'])
        : DateTime.now();

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
                            icon: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 24,
                            ),
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
                                          color: day == 'FRI'
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.8),
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

    if (result != null) {
      try {
        TimeOfDay? existingTime;
        if (widget.task['time'] != null) {
          final timeParts = widget.task['time'].split(':');
          existingTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }

        final localDateTime = DateTime(
          result.year,
          result.month,
          result.day,
          existingTime?.hour ?? 0,
          existingTime?.minute ?? 0,
        );

        final dateString =
            "${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}";

        print('Local date selected: $localDateTime');
        print('Date to save: $dateString');

        await Supabase.instance.client.from('tasks').update({
          'due_date': dateString,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['due_date'] = dateString;
        });

        await _scheduleNotification();

        widget.onTaskUpdated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Due date updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating due date: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

    for (int row = 0; row < numRows; row++) {
      List<Widget> rowChildren = [];

      for (int col = 0; col < 7; col++) {
        if (day <= 0) {
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
    final isPastDate = currentDate.isBefore(today);

    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          onTap: (isCurrentMonth && (!isPastDate || isSelected)) ? onTap : null,
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
                      ? (isPastDate && !isSelected)
                          ? Colors.white.withOpacity(0.3)
                          : isSelected
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

  Future<void> _selectTime(BuildContext context) async {
    String? currentTimeString = widget.task['time'];
    TimeOfDay? initialTime;

    if (currentTimeString != null) {
      try {
        if (currentTimeString.contains('T') ||
            currentTimeString.contains(' ')) {
          final dateTime = DateTime.parse(currentTimeString);
          initialTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
        } else {
          final parts = currentTimeString.split(':');
          initialTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: parts.length > 1 ? int.parse(parts[1]) : 0);
        }
      } catch (e) {
        initialTime = TimeOfDay.now();
      }
    } else {
      initialTime = TimeOfDay.now();
    }

    int selectedHour = initialTime.hour;
    int selectedMinute = initialTime.minute;

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
                    Container(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                    SizedBox(height: 16),
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
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                onPressed: () => Navigator.pop(
                                  context,
                                  TimeOfDay(
                                      hour: selectedHour,
                                      minute: selectedMinute),
                                ),
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

    if (result == 'no_time') {
      try {
        await Supabase.instance.client.from('tasks').update({
          'time': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['time'] = null;
        });

        widget.onTaskUpdated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Time removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing time: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (result is TimeOfDay) {
      try {
        final localTimeString =
            '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}:00';

        await Supabase.instance.client.from('tasks').update({
          'time': localTimeString,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['time'] = localTimeString;
        });

        await _scheduleNotification();

        widget.onTaskUpdated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Time updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating time: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

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
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 2, color: WarnaSecondary),
                  SizedBox(height: 48),
                  Container(height: 2, color: WarnaSecondary),
                ],
              ),
            ),
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
                (index) => Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: Text(
                    format(index + minValue),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: index + minValue == value
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'No Date';
    try {
      final date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')} ${DateFormat('MMM').format(date)} ${(date.year % 100).toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return 'No';

    try {
      if (timeString.contains('T') || timeString.contains(' ')) {
        final time = DateTime.parse(timeString);
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        return "$hour:$minute";
      } else {
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          return "${parts[0]}:${parts[1]}";
        }
        return timeString;
      }
    } catch (e) {
      return timeString;
    }
  }

  Future<void> _editNotes(BuildContext context) async {
    final TextEditingController notesController =
        TextEditingController(text: widget.task['notes']);

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: WarnaUtama,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: notesController,
                    maxLines: 5,
                    autofocus: true,
                    cursorColor: WarnaSecondary,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add your notes here...',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: WarnaSecondary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
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
                      SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WarnaSecondary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(context, notesController.text),
                        child: Text(
                          'Save',
                          style: TextStyle(
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
        );
      },
    );

    if (result != null) {
      try {
        await Supabase.instance.client.from('tasks').update({
          'notes': result,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['notes'] = result;
        });

        widget.onTaskUpdated();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notes updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating notes: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadAttachmentUrls() async {
    for (String path in _attachmentPaths) {
      final url = await Supabase.instance.client.storage
          .from('attachments')
          .createSignedUrl(path, 3600);
      setState(() {
        _attachmentUrls.add(url);
      });
    }
  }

  Future<void> _handleAttachment() async {
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
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final User? user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final String fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final file = File(image.path);

      await Supabase.instance.client.storage
          .from('attachments')
          .upload(fileName, file);

      final String signedUrl = await Supabase.instance.client.storage
          .from('attachments')
          .createSignedUrl(fileName, 3600);

      _attachmentPaths.add(fileName);
      await Supabase.instance.client.from('tasks').update({
        'attachments': _attachmentPaths,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      setState(() {
        _attachmentUrls.add(signedUrl);
        _isUploading = false;
      });

      widget.onTaskUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding attachment: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAttachment(int index) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: WarnaUtama,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: WarnaSecondary,
                  size: 55,
                ),
                SizedBox(height: 16),
                Text(
                  'Delete Attachment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this attachment?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WarnaSecondary,
                        foregroundColor: WarnaUtama2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Delete',
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
        );
      },
    );

    if (confirmDelete != true) return;

    try {
      final String filePath = _attachmentPaths[index];

      await Supabase.instance.client.storage
          .from('attachments')
          .remove([filePath]);

      _attachmentPaths.removeAt(index);
      await Supabase.instance.client.from('tasks').update({
        'attachments': _attachmentPaths,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      setState(() {
        _attachmentUrls.removeAt(index);
      });

      widget.onTaskUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      print('Error removing attachment: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing attachment: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _getNotificationId(String uuid) {
    final lastFiveChars = uuid.substring(uuid.length - 5);
    final intValue = int.parse(lastFiveChars, radix: 16);
    return intValue % 100000;
  }

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

  Future<void> _updatePriority(String priority) async {
    try {
      await Supabase.instance.client.from('tasks').update({
        'priority': priority,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      setState(() {
        widget.task['priority'] = priority;
      });
      widget.onTaskUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Priority updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating priority: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleNotification() async {
    if (widget.task['due_date'] == null || widget.task['time'] == null) {
      try {
        await _notificationService
            .cancelNotificationByTaskId(widget.task['id']);
        print(
            'Cancelled existing notifications for task: ${widget.task['id']}');
      } catch (e) {
        print('Error cancelling notifications: $e');
      }
      return;
    }

    try {
      await _notificationService.cancelNotificationByTaskId(widget.task['id']);
      print('Cancelled existing notifications for task: ${widget.task['id']}');

      final time = widget.task['time'].split(':');
      final date = DateTime.parse(widget.task['due_date']);

      final scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(time[0]),
        int.parse(time[1]),
      );

      int reminderMinutes = _defaultReminderMinutes;
      if (widget.task['reminder_before'] != null) {
        try {
          reminderMinutes = int.parse(widget.task['reminder_before']);
        } catch (e) {
          print('Error parsing reminder minutes: $e');
        }
      }

      final reminderDateTime =
          scheduledDateTime.subtract(Duration(minutes: reminderMinutes));
      final now = DateTime.now();

      if (reminderDateTime.isAfter(now)) {
        final notificationId = _getNotificationId(widget.task['id']);
        await _notificationService.scheduleTaskNotification(
          id: notificationId,
          title: widget.task['title'],
          scheduledDate: reminderDateTime.toUtc(),
          taskId: widget.task['id'],
        );

        print('Scheduled new notification for: ${widget.task['title']}');
        print('Task time: $scheduledDateTime');
        print('Current time: $now');
        print(
            'Reminder time: $reminderDateTime (${reminderMinutes} minutes before)');
      } else {
        print(
            'Reminder time is in the past, not scheduling: $reminderDateTime');
        print('Current time: $now');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Cannot set reminder for the past. Task is too soon!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSubtasks = _getSortedSubtasks();

    return Scaffold(
      backgroundColor: WarnaUtama,
      appBar: AppBar(
        backgroundColor: WarnaUtama2,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.onTaskUpdated();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _confirmDeleteTask,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isCategoryMenuOpen = true;
                    });

                    final RenderBox? button = _categoryKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    if (button != null) {
                      final position = button.localToGlobal(Offset.zero);
                      final size = button.size;

                      showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          MediaQuery.of(context).size.width / 2 -
                              size.width / 1.8,
                          position.dy + 40,
                          MediaQuery.of(context).size.width / 2 +
                              size.width / 2,
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
                          _isCategoryMenuOpen = false;
                        });

                        if (selectedValue == 'add_category') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KategoriPage(),
                            ),
                          ).then((_) async {
                            await _loadCategories();

                            await _reloadTaskData();

                            widget.onTaskUpdated();
                          });
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
                      color: WarnaSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.task['category'] ?? 'No Category',
                          style: TextStyle(
                              color: WarnaUtama2,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 5),
                        AnimatedRotation(
                          turns: _isCategoryMenuOpen ? 0.5 : 0,
                          duration: Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: WarnaUtama2,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 5),
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text(
                    widget.task['title'] ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPriorityMenuOpen = true;
                      });

                      final RenderBox? button = _priorityKey.currentContext
                          ?.findRenderObject() as RenderBox?;
                      if (button != null) {
                        final position = button.localToGlobal(Offset.zero);
                        final size = button.size;

                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            position.dx,
                            position.dy + size.height + 5,
                            position.dx + size.width,
                            position.dy,
                          ),
                          color: WarnaUtama2,
                          items: [
                            PopupMenuItem(
                              value: 'high',
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'High',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'medium',
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Medium',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'low',
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Low',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ).then((value) {
                          setState(() {
                            _isPriorityMenuOpen = false;
                          });
                          if (value != null) {
                            _updatePriority(value);
                          }
                        });
                      }
                    },
                    child: Container(
                      key: _priorityKey,
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: WarnaSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getPriorityColor(widget.task['priority']),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          if (widget.task['priority'] == null)
                            Text(
                              'Priority',
                              style: TextStyle(
                                color: WarnaUtama2,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          SizedBox(width: 5),
                          AnimatedRotation(
                            turns: _isPriorityMenuOpen ? 0.5 : 0,
                            duration: Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: WarnaUtama2,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
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
              Container(
                decoration: BoxDecoration(
                  color: WarnaUtama2,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
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
                            _formatDate(widget.task['due_date']),
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
                      onTap: () => _selectDate(context),
                    ),
                    Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),
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
                            _formatTime(widget.task['time']),
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
                      onTap: () => _selectTime(context),
                    ),
                    if (widget.task['time'] != null) ...[
                      Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),
                      ListTile(
                        leading: Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                        ),
                        title: Text(
                          'Reminder At',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.task['reminder_before'] != null
                                  ? _formatReminderTime(
                                      widget.task['reminder_before'])
                                  : '-',
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
                        onTap: () => _selectReminderTime(context),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: WarnaUtama2,
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.sticky_note_2,
                        color: Colors.white,
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.task['notes'] != null &&
                              widget.task['notes'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                widget.task['notes'],
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.task['notes'] != null &&
                                    widget.task['notes'].isNotEmpty
                                ? 'Edit'
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
                      onTap: () => _editNotes(context),
                    ),
                    Divider(height: 1, color: WarnaUtama.withOpacity(0.3)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.attach_file,
                            color: Colors.white,
                          ),
                          title: Text(
                            'Attachments (${_attachmentUrls.length})',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isUploading)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        WarnaSecondary),
                                  ),
                                )
                              else
                                Text(
                                  'Add',
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
                          onTap: _handleAttachment,
                        ),
                        if (_attachmentUrls.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double itemWidth =
                                    (constraints.maxWidth - 16) / 3;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(
                                      _attachmentUrls.length, (index) {
                                    return Container(
                                      width: itemWidth,
                                      height: itemWidth,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              _attachmentUrls[index],
                                              fit: BoxFit.cover,
                                              headers: {
                                                'Authorization':
                                                    'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
                                              },
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null)
                                                  return child;
                                                return Container(
                                                  color: Colors.grey[800],
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        WarnaSecondary,
                                                      ),
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[800],
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons.error_outline,
                                                          color: Colors.white70,
                                                          size: 20,
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          'Error',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                onTap: () {
                                                  showDialog(
                                                    context: context,
                                                    builder:
                                                        (BuildContext context) {
                                                      return Dialog(
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        insetPadding:
                                                            EdgeInsets.zero,
                                                        child: Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            InteractiveViewer(
                                                              minScale: 0.5,
                                                              maxScale: 4.0,
                                                              child:
                                                                  Image.network(
                                                                _attachmentUrls[
                                                                    index],
                                                                fit: BoxFit
                                                                    .contain,
                                                                headers: {
                                                                  'Authorization':
                                                                      'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
                                                                },
                                                              ),
                                                            ),
                                                            Positioned(
                                                              top: 40,
                                                              right: 20,
                                                              child: Material(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                                child:
                                                                    IconButton(
                                                                  icon: Icon(
                                                                      Icons
                                                                          .close,
                                                                      color: Colors
                                                                          .white),
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                                splashColor: Colors.white
                                                    .withOpacity(0.1),
                                                highlightColor: Colors.white
                                                    .withOpacity(0.1),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () =>
                                                    _removeAttachment(index),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Container(
                                                  padding: EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTask() async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: WarnaUtama,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 55,
                ),
                SizedBox(height: 16),
                Text(
                  'Delete Task',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this task? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        'Delete',
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
        );
      },
    );

    if (confirmDelete == true) {
      try {
        if (_attachmentPaths.isNotEmpty) {
          await Supabase.instance.client.storage
              .from('attachments')
              .remove(_attachmentPaths);
        }

        if (widget.task['due_date'] != null && widget.task['time'] != null) {
          try {
            await _notificationService
                .cancelNotificationByTaskId(widget.task['id']);
          } catch (e) {
            print('Error cancelling notification: $e');
          }
        }

        await Supabase.instance.client
            .from('tasks')
            .delete()
            .eq('id', widget.task['id']);

        widget.onTaskUpdated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting task: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatReminderTime(String? reminderTime) {
    if (reminderTime == null || reminderTime.isEmpty) return '-';

    try {
      final minutes = int.parse(reminderTime);
      if (minutes <= 0) return 'At time of event';

      if (minutes >= 1440) {
        final days = minutes ~/ 1440;
        return '$days day${days > 1 ? 's' : ''} before';
      } else if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final remainingMinutes = minutes % 60;
        if (remainingMinutes == 0) {
          return '$hours hour${hours > 1 ? 's' : ''} before';
        } else {
          return '$hours h ${remainingMinutes} min before';
        }
      } else {
        return '$minutes minute${minutes > 1 ? 's' : ''} before';
      }
    } catch (e) {
      return '-';
    }
  }

  Future<void> _selectReminderTime(BuildContext context) async {
    List<int> availableOptions = [];

    if (widget.task['due_date'] != null && widget.task['time'] != null) {
      try {
        final time = widget.task['time'].split(':');
        final date = DateTime.parse(widget.task['due_date']);

        final taskDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(time[0]),
          int.parse(time[1]),
        );

        final now = DateTime.now();
        final minutesUntilTask = taskDateTime.difference(now).inMinutes;

        availableOptions = _reminderOptions
            .where((minutes) => minutes < minutesUntilTask)
            .toList();

        if (availableOptions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task is too soon! Cannot set a reminder.'),
              backgroundColor: Colors.red,
            ),
          );

          return;
        }
      } catch (e) {
        print('Error checking available reminder options: $e');
      }
    }

    final result = await showDialog<int>(
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
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Remind Me',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              for (final minutes in availableOptions.isEmpty
                                  ? _reminderOptions
                                  : availableOptions)
                                Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: WarnaUtama2,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, minutes),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _formatReminderTime(minutes.toString()),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, null),
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
              );
            },
          ),
        );
      },
    );

    if (result != null) {
      try {
        final time = widget.task['time'].split(':');
        final date = DateTime.parse(widget.task['due_date']);

        final taskDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(time[0]),
          int.parse(time[1]),
        );

        final reminderDateTime =
            taskDateTime.subtract(Duration(minutes: result));
        final now = DateTime.now();

        if (reminderDateTime.isBefore(now)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Cannot set reminder for the past. Please choose another time.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await Supabase.instance.client.from('tasks').update({
          'reminder_before': result.toString(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['reminder_before'] = result.toString();
        });

        await _scheduleNotification();

        widget.onTaskUpdated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating reminder: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
