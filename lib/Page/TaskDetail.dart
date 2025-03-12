import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
      body: Padding(
        padding: EdgeInsets.only(top: 40, left: 16, right: 16),
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
                    final originalIndex = subtasks.indexWhere(
                        (task) => task['title'] == sortedSubtasks[i]['title']);
                    _deleteSubtask(originalIndex);
                  },
                ),
              ),
            _showInputField
                ? TextField(
                    autofocus: true,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addSubtask(value);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Input the sub-task',
                      hintStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: WarnaSecondary, width: 1.5),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    cursorColor: WarnaSecondary,
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
            Text(
              'Category:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: WarnaUtama2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.task['category'] ?? 'No Category',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
