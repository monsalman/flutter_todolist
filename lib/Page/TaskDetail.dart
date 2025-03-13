import 'package:flutter/material.dart';
import '../Navbar/NavBar.dart';
import '../main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
        // Format tanggal sebagai YYYY-MM-DD (tanpa jam)
        final dateString =
            "${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}";

        await Supabase.instance.client.from('tasks').update({
          'due_date': dateString,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.task['id']);

        setState(() {
          widget.task['due_date'] = dateString;
        });

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
