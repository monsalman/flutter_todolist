import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../Service/NotificationService.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

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
  final ImagePicker _picker = ImagePicker();
  List<String> _attachmentPaths = [];
  List<String> _attachmentUrls = [];
  bool _isUploading = false;
  final NotificationService _notificationService = NotificationService();

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

    // Inisialisasi attachments
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

  // Metode _selectDate yang diperbarui untuk menyimpan tanggal tanpa jam
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
                    // Header with "Select date" text
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

                    // Selected date display with edit button
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
                            onPressed: () {
                              // Allow manual date entry
                            },
                          ),
                        ],
                      ),
                    ),

                    // Custom Calendar
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
                          // Month and Year header with navigation
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

                          // Day of week headers
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

                          // Calendar grid
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

                          // Action buttons
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
        final dateString =
            "${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}";

        await Supabase.instance.client.from('tasks').update({
          'due_date': dateString,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['due_date'] = dateString;
        });

        // Schedule notification if both date and time are set
        if (widget.task['due_date'] != null && widget.task['time'] != null) {
          final date = DateTime.parse(dateString);
          final time = widget.task['time'].split(':');
          final scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(time[0]),
            int.parse(time[1]),
          );

          if (scheduledDate.isAfter(DateTime.now())) {
            try {
              final notificationId = _getNotificationId(widget.task['id']);

              await _notificationService.scheduleTaskNotification(
                id: notificationId,
                title: widget.task['title'],
                scheduledDate: scheduledDate,
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Failed to schedule notification: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } else {
            print('Scheduled date is in the past: $scheduledDate');
          }
        }

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

  // Helper method to build calendar grid
  List<Widget> _buildCalendarGrid(
      DateTime currentMonth, Function(DateTime) onSelectDate) {
    // Get the first day of the month
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);

    // Get the day of week for the first day (0 = Sunday, 6 = Saturday)
    final firstWeekday = firstDayOfMonth.weekday % 7;

    // Get the number of days in the month
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    // Get the number of days in the previous month
    final daysInPrevMonth =
        DateTime(currentMonth.year, currentMonth.month, 0).day;

    // Calculate the number of rows needed (always 6 for consistency)
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

  // Helper method to build a day cell
  Widget _buildDayCell({
    required int day,
    required bool isCurrentMonth,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Ganti metode _selectTime untuk menyimpan waktu dalam format yang benar
  Future<void> _selectTime(BuildContext context) async {
    String? currentTimeString = widget.task['time'];
    TimeOfDay? selectedTime;

    if (currentTimeString != null) {
      try {
        if (currentTimeString.contains('T') ||
            currentTimeString.contains(' ')) {
          final dateTime = DateTime.parse(currentTimeString);
          selectedTime =
              TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
        } else {
          final parts = currentTimeString.split(':');
          selectedTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: parts.length > 1 ? int.parse(parts[1]) : 0);
        }
      } catch (e) {
        selectedTime = TimeOfDay.now();
      }
    } else {
      selectedTime = TimeOfDay.now();
    }

    int selectedHour = selectedTime.hour;
    int selectedMinute = selectedTime.minute;

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

                    SizedBox(height: 16),

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
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
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

    // Handle hasil dialog
    if (result == 'no_time') {
      try {
        await Supabase.instance.client.from('tasks').update({
          'time': null,
          'updated_at': DateTime.now().toIso8601String(),
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
        final timeString =
            '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}:00';

        await Supabase.instance.client.from('tasks').update({
          'time': timeString,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['time'] = timeString;
        });

        // Schedule notification if both date and time are set
        if (widget.task['due_date'] != null && widget.task['time'] != null) {
          final date = DateTime.parse(widget.task['due_date']);
          final time = timeString.split(':');
          final scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(time[0]),
            int.parse(time[1]),
          );

          if (scheduledDate.isAfter(DateTime.now())) {
            try {
              final notificationId = _getNotificationId(widget.task['id']);

              await _notificationService.scheduleTaskNotification(
                id: notificationId,
                title: widget.task['title'],
                scheduledDate: scheduledDate,
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Failed to schedule notification: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }

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

  // Widget untuk membuat spinner waktu
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
      child: Stack(
        children: [
          // Spinner values
          ListWheelScrollView.useDelegate(
            itemExtent: 50,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              onChanged(index + minValue);
            },
            controller:
                FixedExtentScrollController(initialItem: value - minValue),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: maxValue - minValue + 1,
              builder: (context, index) {
                final itemValue = index + minValue;
                return Center(
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

          // Highlight overlay for selected value
          Center(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: WarnaSecondary.withOpacity(0.5), width: 2),
                  bottom: BorderSide(
                      color: WarnaSecondary.withOpacity(0.5), width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to format date for display - format DD MMM YY
  String _formatDate(String? dateString) {
    if (dateString == null) return 'No Date';
    try {
      final date = DateTime.parse(dateString);
      // Format tanggal sebagai "DD MMM YY" (contoh: "14 Mar 25")
      return "${date.day.toString().padLeft(2, '0')} ${DateFormat('MMM').format(date)} ${(date.year % 100).toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  // Helper method to format time for display - only show HH:MM
  String _formatTime(String? timeString) {
    if (timeString == null) return 'No';

    try {
      // Cek apakah format waktu berisi tanggal (format lama)
      if (timeString.contains('T') || timeString.contains(' ')) {
        final time = DateTime.parse(timeString);
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        return "$hour:$minute";
      } else {
        // Format HH:MM:SS - hanya tampilkan HH:MM
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          return "${parts[0]}:${parts[1]}";
        }
        return timeString;
      }
    } catch (e) {
      // Jika parsing gagal, tampilkan string asli
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
                // Header
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

                // Notes TextField
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

                // Action buttons
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

  // Method untuk load semua attachment URLs
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

  // Update method handle attachment
  Future<void> _handleAttachment() async {
    // Tampilkan dialog di tengah layar untuk memilih sumber
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width:
                MediaQuery.of(context).size.width * 0.8, // 80% dari lebar layar
            decoration: BoxDecoration(
              color: WarnaUtama2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
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
                // Gallery option
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

                // Camera option
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

                // Cancel button
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

      // Generate nama file baru
      final String fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final file = File(image.path);

      // Upload file baru
      await Supabase.instance.client.storage
          .from('attachments')
          .upload(fileName, file);

      // Get signed URL
      final String signedUrl = await Supabase.instance.client.storage
          .from('attachments')
          .createSignedUrl(fileName, 3600);

      // Update database dengan menambahkan attachment baru ke array
      _attachmentPaths.add(fileName);
      await Supabase.instance.client.from('tasks').update({
        'attachments': _attachmentPaths,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      // Update state
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

  // Update method remove attachment
  Future<void> _removeAttachment(int index) async {
    // Tampilkan dialog konfirmasi
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
                  color: Colors.amber,
                  size: 48,
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

    // Jika user membatalkan, keluar dari method
    if (confirmDelete != true) return;

    try {
      final String filePath = _attachmentPaths[index];

      // Hapus file dari storage
      await Supabase.instance.client.storage
          .from('attachments')
          .remove([filePath]);

      // Update database
      _attachmentPaths.removeAt(index);
      await Supabase.instance.client.from('tasks').update({
        'attachments': _attachmentPaths,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.task['id']);

      // Update state
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

  // Update UI untuk menampilkan multiple attachments
  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Attachments dengan Add button
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
                    valueColor: AlwaysStoppedAnimation<Color>(WarnaSecondary),
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

        // Grid Preview Images
        if (_attachmentUrls.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8, // gap between adjacent items horizontally
                  runSpacing: 8, // gap between lines
                  children: List.generate(_attachmentUrls.length, (index) {
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
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _attachmentUrls[index],
                              fit: BoxFit.cover,
                              headers: {
                                'Authorization':
                                    'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        WarnaSecondary,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                            color: Colors.white70,
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

                          // Tap to View Full Image
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: EdgeInsets.zero,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            // Image with InteractiveViewer for zoom and pan
                                            InteractiveViewer(
                                              minScale: 0.5,
                                              maxScale: 4.0,
                                              child: Image.network(
                                                _attachmentUrls[index],
                                                fit: BoxFit.contain,
                                                headers: {
                                                  'Authorization':
                                                      'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
                                                },
                                              ),
                                            ),
                                            // Close button
                                            Positioned(
                                              top: 40,
                                              right: 20,
                                              child: Material(
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: IconButton(
                                                  icon: Icon(Icons.close,
                                                      color: Colors.white),
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                splashColor: Colors.white.withOpacity(0.1),
                                highlightColor: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),

                          // Delete Button - Pindahkan ke layer paling atas
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _removeAttachment(index),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
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
    );
  }

  // Update fungsi _getNotificationId
  int _getNotificationId(String uuid) {
    // Mengambil 5 karakter terakhir dari UUID
    final lastFiveChars = uuid.substring(uuid.length - 5);
    // Mengkonversi karakter hexadecimal ke integer
    final intValue = int.parse(lastFiveChars, radix: 16);
    // Menggunakan modulo untuk memastikan nilai selalu di bawah 100000
    return intValue % 100000;
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
          onPressed: () => Navigator.pop(context),
        ),
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
                          turns: _isMenuOpen ? 0.5 : 0,
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
              Text(
                widget.task['title'] ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
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
                        Icons.note,
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
                    _buildAttachmentsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
