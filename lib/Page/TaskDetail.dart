import 'package:flutter/material.dart';
import '../main.dart';

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
  List<String> subtasks = [];
  bool _showInputField = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task['title']);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _addSubtask(String subtask) {
    setState(() {
      subtasks.add(subtask);
      _showInputField = false;
    });
  }

  void _toggleInputField() {
    setState(() {
      _showInputField = !_showInputField;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            SizedBox(height: 12),
            if (subtasks.isNotEmpty)
              Text(
                'Subtasks:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            for (var subtask in subtasks)
              ListTile(
                title: Text(
                  subtask,
                  style: TextStyle(color: Colors.white),
                ),
                leading:
                    Icon(Icons.radio_button_unchecked, color: Colors.white70),
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
                : TextButton(
                    onPressed: _toggleInputField,
                    child: Text(
                      'Add Subtask',
                      style: TextStyle(color: WarnaSecondary),
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
