import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const ToDoApp());
}

// ─── Task Model ───────────────────────────────────────────────────────────────
class Task {
  String title;
  bool isDone;

  Task({required this.title, this.isDone = false});
}

// ─── App Root ─────────────────────────────────────────────────────────────────
class ToDoApp extends StatefulWidget {
  const ToDoApp({Key? key}) : super(key: key);

  @override
  State<ToDoApp> createState() => _ToDoAppState();
}

class _ToDoAppState extends State<ToDoApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To Do List',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[100],
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.grey[900],
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: ToDoHome(toggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class ToDoHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const ToDoHome({Key? key, required this.toggleTheme, required this.themeMode})
      : super(key: key);

  @override
  State<ToDoHome> createState() => _ToDoHomeState();
}

class _ToDoHomeState extends State<ToDoHome> {
  // Now stores Task objects instead of plain Strings
  final Map<DateTime, List<Task>> _tasksByDate = {};
  final TextEditingController _controller = TextEditingController();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Task> get _selectedTasks =>
      _tasksByDate[_normalizeDate(_selectedDay)] ?? [];

  // ── CRUD ───────────────────────────────────────────────────────────────────

  void _addTask() {
    if (_controller.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Empty Task'),
          content: const Text('Please enter a task before adding.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      final key = _normalizeDate(_selectedDay);
      _tasksByDate.putIfAbsent(key, () => []);
      _tasksByDate[key]!.add(Task(title: _controller.text.trim()));
    });
    _controller.clear();
  }

  /// Removes task at [index], then shows a Snackbar with an Undo action.
  void _removeTask(int index) {
    final key = _normalizeDate(_selectedDay);
    final removedTask = _tasksByDate[key]![index];

    setState(() {
      _tasksByDate[key]!.removeAt(index);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${removedTask.title}"'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _tasksByDate.putIfAbsent(key, () => []);
              _tasksByDate[key]!.insert(index, removedTask);
            });
          },
        ),
      ),
    );
  }

  void _toggleDone(int index) {
    setState(() {
      _selectedTasks[index].isDone = !_selectedTasks[index].isDone;
    });
  }

  void _editTask(int index) {
    final key = _normalizeDate(_selectedDay);
    final editController =
        TextEditingController(text: _tasksByDate[key]![index].title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                setState(() {
                  _tasksByDate[key]![index].title =
                      editController.text.trim();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Date Picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDay = picked;
        _focusedDay = picked;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset('assets/icon/icon.png', width: 24, height: 24),
          onPressed: () {},
        ),
        title: const Text('To Do List'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Calendar ──────────────────────────────────────────────────────
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, date) {
                return GestureDetector(
                  onTap: _pickDate,
                  child: Text(
                    DateFormat('MMMM d, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                final normalized = _normalizeDate(day);
                final tasks = _tasksByDate[normalized] ?? [];
                final hasTasks = tasks.isNotEmpty;
                // True only when ALL tasks are done
                final allDone =
                    hasTasks && tasks.every((t) => t.isDone);

                Color bgColor;
                if (allDone) {
                  bgColor = Colors.green.shade300;
                } else if (hasTasks) {
                  bgColor = Colors.blue;
                } else {
                  bgColor = Colors.transparent;
                }

                Color textColor;
                if (day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday) {
                  textColor = Colors.red;
                } else if (hasTasks && !allDone) {
                  textColor = Colors.white;
                } else {
                  textColor = isLight ? Colors.black : Colors.white;
                }

                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          hasTasks ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
            eventLoader: (day) {
              final normalized = _normalizeDate(day);
              return _tasksByDate[normalized]?.map((t) => t.title).toList() ?? [];
            },
          ),

          // ── Input Row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _addTask(),
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      filled: true,
                      fillColor: isLight ? Colors.white : Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(
                      color: isLight ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                  ),
                  onPressed: _addTask,
                  child: const Text(
                    'Add',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ── Task Counter ──────────────────────────────────────────────────
          if (_selectedTasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Row(
                children: [
                  Text(
                    '${_selectedTasks.where((t) => t.isDone).length}/${_selectedTasks.length} done',
                    style: TextStyle(
                      fontSize: 13,
                      color: isLight ? Colors.black54 : Colors.white54,
                    ),
                  ),
                ],
              ),
            ),

          // ── Task List ─────────────────────────────────────────────────────
          Expanded(
            child: _selectedTasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks for this day',
                      style: TextStyle(
                        color: isLight ? Colors.black54 : Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _selectedTasks.length,
                    itemBuilder: (context, index) {
                      final task = _selectedTasks[index];

                      return Dismissible(
                        key: ValueKey('${_normalizeDate(_selectedDay)}_$index\_${task.title}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete,
                              color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (_) async => true,
                        onDismissed: (_) => _removeTask(index),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          color: task.isDone
                              ? Colors.green.shade100
                              : (isLight ? Colors.white : Colors.grey[900]),
                          child: ListTile(
                            // ── Checkbox ────────────────────────────────────
                            leading: Checkbox(
                              value: task.isDone,
                              activeColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (_) => _toggleDone(index),
                            ),
                            // ── Task Title ──────────────────────────────────
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                color: task.isDone
                                    ? (isLight
                                        ? Colors.black38
                                        : Colors.white38)
                                    : (isLight ? Colors.black : Colors.white),
                                decoration: task.isDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            // ── Actions ─────────────────────────────────────
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () => _editTask(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _removeTask(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}