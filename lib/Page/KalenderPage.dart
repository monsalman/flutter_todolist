import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'TaskDetail.dart';
import 'components/AddTasks.dart';

class KalenderPage extends StatefulWidget {
  const KalenderPage({super.key});

  @override
  State<KalenderPage> createState() => _KalenderPageState();
}

class EventMarker {
  final Color color;
  final Widget marker;

  EventMarker({
    required this.color,
    required this.marker,
  });
}

class _KalenderPageState extends State<KalenderPage>
    with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool isCompletedExpanded = true;
  bool isUncompletedExpanded = true;
  String? selectedCategory;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedPriority;
  List<String> categories = [];
  final Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _loadEvents();
    _loadCategories();
  }

  Future<void> _loadEvents() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('tasks').select();

      setState(() {
        _events = {};
        for (final task in response) {
          final date = DateTime.parse(task['due_date']);
          final key = DateTime(date.year, date.month, date.day);

          if (_events[key] != null) {
            _events[key]!.add(task);
          } else {
            _events[key] = [task];
          }
        }
      });
    } catch (e) {
      print('Error loading events: $e');
    }
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

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  List<EventMarker> _getMarkersForDay(DateTime day, List<dynamic> events) {
    return events.map((event) {
      Color markerColor;
      if (event['priority'] != null) {
        switch (event['priority'].toString().toLowerCase()) {
          case 'high':
            markerColor = Colors.red;
            break;
          case 'medium':
            markerColor = Colors.orange;
            break;
          case 'low':
            markerColor = Colors.green;
            break;
          default:
            markerColor = Colors.grey;
        }
      } else {
        markerColor = Colors.grey;
      }

      return EventMarker(
        color: markerColor,
        marker: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: markerColor,
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: WarnaUtama2,
        iconTheme: IconThemeData(color: Colors.white),
        toolbarHeight: 10,
      ),
      body: Container(
        color: WarnaUtama,
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2025, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              eventLoader: _getEventsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;

                  return Positioned(
                    bottom: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _getMarkersForDay(date, events).map((marker) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          child: marker.marker,
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.white),
                selectedTextStyle: TextStyle(color: Colors.black),
                todayTextStyle: TextStyle(color: Colors.white),
                outsideTextStyle: TextStyle(color: Colors.grey),
                selectedDecoration: BoxDecoration(
                  color: WarnaSecondary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: WarnaSecondary,
                    width: 1.5,
                  ),
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: Colors.white),
                headerPadding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _selectedDay == null
                  ? Center(
                      child: Text(
                        'Pilih tanggal untuk melihat task',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_getEventsForDay(_selectedDay!)
                              .where((task) => !(task['is_completed'] ?? false))
                              .isNotEmpty) ...[
                            InkWell(
                              onTap: () {
                                setState(() {
                                  isUncompletedExpanded =
                                      !isUncompletedExpanded;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 10, left: 10),
                                child: Row(
                                  children: [
                                    Text(
                                      'Tasks',
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
                                          '${_getEventsForDay(_selectedDay!).where((task) => !(task['is_completed'] ?? false)).length}',
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
                                      turns: isUncompletedExpanded ? 0.5 : 0.0,
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
                              firstChild: ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _getEventsForDay(_selectedDay!)
                                    .where((task) =>
                                        !(task['is_completed'] ?? false))
                                    .length,
                                itemBuilder: (context, index) {
                                  final uncompletedTasks =
                                      _getEventsForDay(_selectedDay!)
                                          .where((task) =>
                                              !(task['is_completed'] ?? false))
                                          .toList();
                                  return _buildTaskCard(
                                      uncompletedTasks[index]);
                                },
                              ),
                              secondChild: Container(),
                              crossFadeState: isUncompletedExpanded
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              duration: _animationDuration,
                            ),
                          ],
                          if (_getEventsForDay(_selectedDay!)
                              .where((task) => task['is_completed'] ?? false)
                              .isNotEmpty) ...[
                            InkWell(
                              onTap: () {
                                setState(() {
                                  isCompletedExpanded = !isCompletedExpanded;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.only(
                                    top: 10, bottom: 10, left: 10),
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
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: WarnaSecondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${_getEventsForDay(_selectedDay!).where((task) => task['is_completed'] ?? false).length}',
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
                              firstChild: ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _getEventsForDay(_selectedDay!)
                                    .where(
                                        (task) => task['is_completed'] ?? false)
                                    .length,
                                itemBuilder: (context, index) {
                                  final completedTasks =
                                      _getEventsForDay(_selectedDay!)
                                          .where((task) =>
                                              task['is_completed'] ?? false)
                                          .toList();
                                  return _buildTaskCard(completedTasks[index]);
                                },
                              ),
                              secondChild: Container(),
                              crossFadeState: isCompletedExpanded
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              duration: _animationDuration,
                            ),
                          ],
                        ],
                      ),
                    ),
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
                  initialDate: _selectedDay ?? DateTime.now(),
                  onTaskAdded: () {
                    _loadCategories();
                    _loadEvents();
                  },
                  onDateSelected: (DateTime newDate) {
                    setState(() {
                      _selectedDay = newDate;
                      _focusedDay = newDate;
                    });
                  },
                ),
              );
            },
          ).then((_) {
            _loadCategories();
            _loadEvents();
          });
        },
        backgroundColor: WarnaSecondary,
        child: Icon(Icons.add, color: WarnaUtama),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isCompleted = task['is_completed'] ?? false;
    final bool isTimeOverdue = _isTaskOverdue(task);
    final bool hasUncompletedSubtasks = _hasUncompletedSubtasks(task);
    final Color textColor = isCompleted ? Colors.white38 : Colors.white;
    final Color dateTimeColor = isCompleted
        ? Colors.white38
        : (isTimeOverdue ? Colors.redAccent : Colors.white70);
    final Color checkboxColor = isCompleted ? Colors.white38 : WarnaSecondary;

    // Get early/late status for completed tasks
    String completionStatus = '';
    if (isCompleted &&
        task['due_date'] != null &&
        task['date_completed'] != null) {
      final dueDate = DateTime.parse(task['due_date']).toLocal();
      final completedDate = DateTime.parse(task['date_completed']).toLocal();

      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final completedDay =
          DateTime(completedDate.year, completedDate.month, completedDate.day);

      if (completedDay.isBefore(dueDay)) {
        completionStatus = 'early';
      } else if (completedDay.isAfter(dueDay)) {
        completionStatus = 'late';
      }
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: WarnaUtama2,
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetail(
                    task: task,
                    onTaskUpdated: () {
                      _loadCategories();
                      _loadEvents();
                    },
                  ),
                ),
              );
            },
            child: ListTile(
              contentPadding: EdgeInsets.only(left: 4, right: 10),
              horizontalTitleGap: 0,
              leading: Transform.scale(
                scale: 1.2,
                child: Tooltip(
                  message: hasUncompletedSubtasks && !isCompleted
                      ? 'Complete all subtasks first'
                      : isCompleted
                          ? 'Mark as uncompleted'
                          : 'Mark as completed',
                  child: MouseRegion(
                    cursor: hasUncompletedSubtasks && !isCompleted
                        ? SystemMouseCursors.forbidden
                        : SystemMouseCursors.click,
                    child: Checkbox(
                      value: isCompleted,
                      onChanged: (bool? value) {
                        if (value != null) {
                          _updateTaskStatus(task['id'], value);
                        }
                      },
                      activeColor: checkboxColor,
                      checkColor: WarnaUtama,
                      side: BorderSide(color: checkboxColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
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
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
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
                      if (task['time'] != null)
                        Text(
                          '${task['time']}'.substring(0, 5),
                          style: TextStyle(
                            color: dateTimeColor,
                            fontSize: 12,
                          ),
                        ),
                      if (task['time'] != null) SizedBox(width: 8),
                      if (isTimeOverdue && !isCompleted)
                        Text(
                          _getOverdueText(task),
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      if (isTimeOverdue && !isCompleted) SizedBox(width: 8),
                      if (task['subtasks'] != null &&
                          (task['subtasks'] as List).isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.checklist,
                              color: isTimeOverdue && !isCompleted
                                  ? Colors.redAccent
                                  : Colors.white70,
                              size: 14),
                        ),
                      if (task['notes'] != null &&
                          task['notes'].toString().isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.sticky_note_2,
                              color: isTimeOverdue && !isCompleted
                                  ? Colors.redAccent
                                  : Colors.white70,
                              size: 14),
                        ),
                      if (task['attachments'] != null &&
                          (task['attachments'] as List).isNotEmpty)
                        Icon(Icons.attach_file,
                            color: isTimeOverdue && !isCompleted
                                ? Colors.redAccent
                                : Colors.white70,
                            size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (completionStatus.isNotEmpty)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: completionStatus == 'early'
                      ? Colors.green.withOpacity(0.7)
                      : Colors.red.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  completionStatus,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
        return Colors.transparent;
    }
  }

  bool _isTaskOverdue(Map<String, dynamic> task) {
    if (!task['is_completed'] && task['due_date'] != null) {
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
        return now.isAfter(taskDateTime);
      }

      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      final today = DateTime(now.year, now.month, now.day);
      return taskDay.isBefore(today);
    }
    return false;
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
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final difference = today.difference(taskDay);
      if (difference.inDays > 0) {
        return "(${difference.inDays}d late)";
      }
    }
    return "";
  }

  bool _hasUncompletedSubtasks(Map<String, dynamic> task) {
    if (task['subtasks'] != null && (task['subtasks'] as List).isNotEmpty) {
      final subtasks = task['subtasks'] as List;
      return subtasks.any((subtask) => subtask['isCompleted'] == false);
    }
    return false;
  }

  Future<void> _updateTaskStatus(String taskId, bool isCompleted) async {
    try {
      final taskData = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('id', taskId)
          .single();

      if (isCompleted && _hasUncompletedSubtasks(taskData)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Cannot complete task: Complete all subtasks first'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final updateData = {
        'is_completed': isCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isCompleted) {
        // Set the completion date to now - used for early/late indicators
        updateData['date_completed'] = DateTime.now().toIso8601String();
      } else {
        // Clear the completion date when marking as incomplete
        updateData['date_completed'] = '';
      }

      await Supabase.instance.client
          .from('tasks')
          .update(updateData)
          .match({'id': taskId});

      await _loadEvents();
    } catch (e) {
      print('Error updating task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
