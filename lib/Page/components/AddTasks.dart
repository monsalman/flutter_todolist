import 'package:flutter/material.dart';
import 'package:flutter_todolist/Service/NotificationService.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import 'package:intl/intl.dart';
import 'package:flutter_todolist/Page/KategoriPage.dart';

class AddTasks extends StatefulWidget {
  final DateTime? initialDate;
  final Function onTaskAdded;
  final Function(String?)? onCategorySelected;
  final Function(DateTime)? onDateSelected;

  const AddTasks({
    Key? key,
    this.initialDate,
    required this.onTaskAdded,
    this.onCategorySelected,
    this.onDateSelected,
  }) : super(key: key);

  @override
  State<AddTasks> createState() => _AddTasksState();
}

class _AddTasksState extends State<AddTasks> {
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  String? selectedCategory;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedPriority;
  final GlobalKey<State> _categoryKey = GlobalKey<State>();
  final GlobalKey _priorityKey = GlobalKey();
  List<String> categories = [];
  bool _dateManuallySelected = false;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
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
            content: Text('No Internet Connection'),
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

        // Create local DateTime for task storage
        DateTime taskDateTime;
        if (timeString != null) {
          final timeParts = timeString.split(':');
          taskDateTime = DateTime(
            taskDate.year,
            taskDate.month,
            taskDate.day,
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        } else {
          taskDateTime = DateTime(
            taskDate.year,
            taskDate.month,
            taskDate.day,
          );
        }

        // Store task in local time (no UTC conversion)
        final response = await Supabase.instance.client
            .from('tasks')
            .insert({
              'title': taskTitle,
              'category': category,
              'priority': selectedPriority,
              'user_id': user.id,
              'is_completed': false,
              'created_at': DateTime.now().toIso8601String(),
              'due_date': taskDateTime.toIso8601String(),
              'time': timeString,
              'date_completed': '',
            })
            .select()
            .single();

        // Only convert to UTC for notification scheduling
        if (timeString != null) {
          final notificationService = NotificationService();
          final notificationDateTime = taskDateTime.toUtc();

          await notificationService.scheduleTaskNotification(
            id: DateTime.now().millisecondsSinceEpoch.hashCode,
            title: taskTitle,
            scheduledDate: notificationDateTime,
            taskId: response['id'],
          );

          print('Scheduling notification for local time: $taskDateTime');
          print('Notification scheduled in UTC: $notificationDateTime');
        }

        widget.onTaskAdded();

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
      print('Error in _saveTask: $error');
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

  Future<void> _selectDate(BuildContext context) async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime selectedDate = this.selectedDate ?? DateTime.now();

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
                            DateFormat('E, MMM d').format(selectedDate),
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
                                        selectedDate.year,
                                        selectedDate.month - 1,
                                        selectedDate.day,
                                      );
                                    });
                                  },
                                ),
                                Text(
                                  DateFormat('MMMM yyyy').format(selectedDate),
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
                                        selectedDate.year,
                                        selectedDate.month + 1,
                                        selectedDate.day,
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
                                  _buildCalendarGrid(selectedDate, (date) {
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
      setState(() {
        selectedDate = result;
        _dateManuallySelected = true;
      });
      widget.onDateSelected?.call(result);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    TimeOfDay initialTime = selectedTime ?? TimeOfDay.now();
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
      setState(() {
        selectedTime = null;
      });
    } else if (result is TimeOfDay) {
      setState(() {
        selectedTime = result;
      });
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'No Date';
    try {
      final date = DateTime.parse(dateString)
          .toLocal(); // Konversi ke waktu lokal untuk display
      return "${date.day.toString().padLeft(2, '0')} ${DateFormat('MMM').format(date)} ${(date.year % 100).toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      borderSide: BorderSide(color: WarnaSecondary, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: WarnaSecondary, width: 1),
                    ),
                    filled: true,
                    fillColor: WarnaUtama,
                    prefixIcon: Icon(Icons.task_alt, color: WarnaSecondary),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a task';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        key: _categoryKey,
                        height: 36,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: WarnaUtama2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            final RenderBox? button =
                                _categoryKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (button != null) {
                              final position =
                                  button.localToGlobal(Offset.zero);
                              final size = button.size;

                              showMenu(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  position.dx,
                                  position.dy - (categories.length + 1) * 55.0,
                                  position.dx + size.width,
                                  position.dy + size.height,
                                ),
                                color: WarnaUtama2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 8,
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
                                  if (selectedValue != null) {
                                    if (selectedValue == 'add_category') {
                                      // Navigate to KategoriPage
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => KategoriPage(),
                                        ),
                                      ).then((_) {
                                        // Reload categories when returning from KategoriPage
                                        _loadCategories();
                                      });
                                    } else {
                                      selectedCategory = selectedValue;
                                      widget.onCategorySelected
                                          ?.call(selectedValue);
                                    }
                                  }
                                });
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
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 36,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: WarnaUtama2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 0),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: 20,
                                  maxWidth: 20,
                                ),
                                onPressed: () => _selectDate(context),
                                icon: Icon(
                                  Icons.calendar_today,
                                  color: WarnaSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (_dateManuallySelected && selectedDate != null)
                              Padding(
                                padding: EdgeInsets.only(left: 0, right: 4),
                                child: Text(
                                  _formatDate(DateFormat('yyyy-MM-dd')
                                      .format(selectedDate!)),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        height: 36,
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: WarnaUtama2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 0),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(
                                  minWidth: 24,
                                  maxWidth: 24,
                                ),
                                onPressed: () => _selectTime(context),
                                icon: Icon(
                                  Icons.access_time,
                                  color: WarnaSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (selectedTime != null)
                              Padding(
                                padding: EdgeInsets.only(left: 0, right: 4),
                                child: Text(
                                  selectedTime!.format(context),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        key: _priorityKey,
                        height: 36,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: WarnaUtama2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            final RenderBox? button =
                                _priorityKey.currentContext?.findRenderObject()
                                    as RenderBox?;
                            if (button != null) {
                              final position =
                                  button.localToGlobal(Offset.zero);
                              final size = button.size;

                              showMenu(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  position.dx,
                                  position.dy - 165,
                                  position.dx + size.width,
                                  position.dy + size.height,
                                ),
                                color: WarnaUtama2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 8,
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
                                          style:
                                              TextStyle(color: Colors.white70),
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
                                          style:
                                              TextStyle(color: Colors.white70),
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
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ).then((value) {
                                setState(() {
                                  if (value != null) {
                                    selectedPriority = value;
                                  }
                                });
                              });
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                margin: EdgeInsets.only(
                                    right: selectedPriority != null ? 0 : 8),
                                decoration: BoxDecoration(
                                  color: selectedPriority != null
                                      ? _getPriorityColor(selectedPriority)
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              if (selectedPriority == null)
                                Text(
                                  'Priority',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
                        final taskTitle = _taskController.text.trim();
                        final category =
                            selectedCategory == 'All' ? null : selectedCategory;

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
    );
  }
}
