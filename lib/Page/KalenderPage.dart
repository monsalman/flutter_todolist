import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'TaskDetail.dart';

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

class _KalenderPageState extends State<KalenderPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool isCompletedExpanded = true;
  final _formKey = GlobalKey<FormState>();
  final _taskController = TextEditingController();
  String? selectedCategory;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String? selectedPriority;
  bool _isCategoryMenuOpen = false;
  bool _isPriorityMenuOpen = false;
  final GlobalKey<State> _categoryKey = GlobalKey<State>();
  final GlobalKey _priorityKey = GlobalKey();
  List<String> categories = [];

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
        // title: Text('Kalender', style: TextStyle(color: Colors.white)),
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
                          // Uncompleted Tasks
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: _getEventsForDay(_selectedDay!)
                                .where(
                                    (task) => !(task['is_completed'] ?? false))
                                .length,
                            itemBuilder: (context, index) {
                              final uncompletedTasks =
                                  _getEventsForDay(_selectedDay!)
                                      .where((task) =>
                                          !(task['is_completed'] ?? false))
                                      .toList();
                              return _buildTaskCard(uncompletedTasks[index]);
                            },
                          ),
                          // Completed Tasks Section
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
                                padding: EdgeInsets.only(bottom: 10, left: 10),
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
                                    Icon(
                                      isCompletedExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isCompletedExpanded)
                              ListView.builder(
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
          // Reset nilai-nilai yang diperlukan
          _taskController.clear();
          selectedCategory = null;
          selectedDate = _selectedDay;
          selectedTime = null;
          selectedPriority = null;

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
                                          setModalState(() {
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
                                                position.dy + size.height,
                                              ),
                                              color: WarnaUtama2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              elevation: 8,
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
                                                if (selectedValue != null &&
                                                    selectedValue !=
                                                        'add_category') {
                                                  selectedCategory =
                                                      selectedValue;
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
                                            SizedBox(width: 2),
                                            AnimatedRotation(
                                              turns:
                                                  _isCategoryMenuOpen ? 0.5 : 0,
                                              duration:
                                                  Duration(milliseconds: 200),
                                              child: Icon(
                                                _isCategoryMenuOpen
                                                    ? Icons.keyboard_arrow_down
                                                    : Icons.keyboard_arrow_up,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Time button
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Calendar button
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
                                                final DateTime? pickedDate =
                                                    await showDatePicker(
                                                  context: context,
                                                  initialDate: selectedDate ??
                                                      DateTime.now(),
                                                  firstDate: DateTime.now(),
                                                  lastDate:
                                                      DateTime(2025, 12, 31),
                                                  builder: (context, child) {
                                                    return Theme(
                                                      data: Theme.of(context)
                                                          .copyWith(
                                                        colorScheme:
                                                            ColorScheme.dark(
                                                          primary:
                                                              WarnaSecondary,
                                                          onPrimary:
                                                              Colors.black,
                                                          surface: WarnaUtama,
                                                          onSurface:
                                                              Colors.white,
                                                        ),
                                                        dialogBackgroundColor:
                                                            WarnaUtama,
                                                      ),
                                                      child: child!,
                                                    );
                                                  },
                                                );
                                                if (pickedDate != null) {
                                                  setModalState(() {
                                                    selectedDate = pickedDate;
                                                  });
                                                }
                                              },
                                              icon: Icon(
                                                Icons.calendar_today,
                                                color: WarnaSecondary,
                                                size: 24,
                                              ),
                                            ),
                                          ),
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
                                                    await showDialog<dynamic>(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return Dialog(
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      insetPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 20),
                                                      child: StatefulBuilder(
                                                        builder: (context,
                                                            setState) {
                                                          return Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              color: WarnaUtama,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16),
                                                            ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          16),
                                                                  child: Text(
                                                                    'Select time',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          18,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          16),
                                                                  child: Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          Navigator.pop(
                                                                              context,
                                                                              'no_time');
                                                                        },
                                                                        child:
                                                                            Text(
                                                                          'No Time',
                                                                          style:
                                                                              TextStyle(
                                                                            color:
                                                                                WarnaSecondary,
                                                                            fontSize:
                                                                                16,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Row(
                                                                        children: [
                                                                          TextButton(
                                                                            onPressed: () =>
                                                                                Navigator.pop(context, 'cancel'),
                                                                            child:
                                                                                Text(
                                                                              'Cancel',
                                                                              style: TextStyle(
                                                                                color: WarnaSecondary,
                                                                                fontSize: 16,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                              width: 16),
                                                                          ElevatedButton(
                                                                            style:
                                                                                ElevatedButton.styleFrom(
                                                                              backgroundColor: WarnaSecondary,
                                                                              foregroundColor: Colors.black,
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(8),
                                                                              ),
                                                                            ),
                                                                            onPressed:
                                                                                () async {
                                                                              final timeResult = await showTimePicker(
                                                                                context: context,
                                                                                initialTime: TimeOfDay.now(),
                                                                              );
                                                                              Navigator.pop(context, timeResult);
                                                                            },
                                                                            child:
                                                                                Text(
                                                                              'Select Time',
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
                                          // Menampilkan tanggal yang dipilih
                                          if (selectedDate != null &&
                                              selectedDate != _selectedDay)
                                            Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Text(
                                                '${selectedDate!.day}/${selectedDate!.month}',
                                                style: TextStyle(
                                                  color: WarnaSecondary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          // Menampilkan waktu yang dipilih
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
                                    // Priority dropdown
                                    SizedBox(width: 8),
                                    Container(
                                      key: _priorityKey,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: WarnaUtama2,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            _isPriorityMenuOpen = true;
                                          });

                                          final RenderBox? button = _priorityKey
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
                                                position.dy - 165,
                                                position.dx + size.width,
                                                position.dy + size.height,
                                              ),
                                              color: WarnaUtama2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'High',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white70),
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
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.orange,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Medium',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white70),
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
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Low',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white70),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ).then((value) {
                                              setModalState(() {
                                                _isPriorityMenuOpen = false;
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
                                                  right:
                                                      selectedPriority != null
                                                          ? 0
                                                          : 8),
                                              decoration: BoxDecoration(
                                                color: selectedPriority != null
                                                    ? _getPriorityColor(
                                                        selectedPriority)
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
                                            SizedBox(width: 2),
                                            AnimatedRotation(
                                              turns:
                                                  _isPriorityMenuOpen ? 0.5 : 0,
                                              duration:
                                                  Duration(milliseconds: 200),
                                              child: Icon(
                                                _isPriorityMenuOpen
                                                    ? Icons.keyboard_arrow_down
                                                    : Icons.keyboard_arrow_up,
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

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isCompleted = task['is_completed'] ?? false;
    final bool isTimeOverdue = _isTaskOverdue(task);
    final Color textColor = isCompleted ? Colors.white38 : Colors.white;
    final Color dateTimeColor = isCompleted
        ? Colors.white38
        : (isTimeOverdue ? Colors.redAccent : Colors.white70);
    final Color checkboxColor = isCompleted ? Colors.white38 : WarnaSecondary;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      color: WarnaUtama2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetail(
                task: task,
                onTaskUpdated: () {
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
                  if (task['time'] != null)
                    Text(
                      '${task['time']}'.substring(0, 5),
                      style: TextStyle(
                        color: dateTimeColor,
                        fontSize: 12,
                      ),
                    ),
                  if (task['time'] != null) SizedBox(width: 8),
                  // Indikator prioritas dan icon
                  if (task['priority'] != null)
                    Container(
                      width: 8,
                      height: 8,
                      margin: EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task['priority']),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (task['subtasks'] != null &&
                      (task['subtasks'] as List).isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.checklist,
                          color: Colors.white70, size: 14),
                    ),
                  if (task['notes'] != null &&
                      task['notes'].toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.sticky_note_2,
                          color: Colors.white70, size: 14),
                    ),
                  if (task['attachments'] != null &&
                      (task['attachments'] as List).isNotEmpty)
                    Icon(Icons.attach_file, color: Colors.white70, size: 14),
                ],
              ),
            ],
          ),
        ),
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

  Future<void> _updateTaskStatus(String taskId, bool isCompleted) async {
    try {
      await Supabase.instance.client.from('tasks').update({
        'is_completed': isCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      }).match({'id': taskId});

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

  Future<void> _saveTask(String taskTitle, String? category) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final taskDate = selectedDate ?? DateTime.now();

        final timeString = selectedTime != null
            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
            : null;

        await Supabase.instance.client.from('tasks').insert({
          'title': taskTitle,
          'category': category,
          'priority': selectedPriority,
          'user_id': user.id,
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'due_date': taskDate.toIso8601String(),
          'time': timeString,
        });

        await _loadEvents();

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
}
