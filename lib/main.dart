import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ToDoApp());
}

// ─── Task Model ───────────────────────────────────────────────────────────────
class Task {
  String title;
  String note;
  bool isDone;

  Task({required this.title, this.note = '', this.isDone = false});

  Map<String, dynamic> toJson() => {
        'title': title,
        'note': note,
        'isDone': isDone,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: (json['title'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
        isDone: json['isDone'] == true,
      );
}

// ─── App Root ─────────────────────────────────────────────────────────────────
class ToDoApp extends StatefulWidget {
  const ToDoApp({Key? key}) : super(key: key);

  @override
  State<ToDoApp> createState() => _ToDoAppState();
}

class _ToDoAppState extends State<ToDoApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _initialized = true;
    });
  }

  Future<void> _toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = newMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', newMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(
        home: SplashScreen(),
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      title: 'To Do List',
      debugShowCheckedModeBanner: false,
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

// ─── Splash Screen ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'To Do List',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stay organized, stay on track.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home Screen ──────────────────────────────────────────────────────────────
class ToDoHome extends StatefulWidget {
  final Future<void> Function() toggleTheme;
  final ThemeMode themeMode;

  const ToDoHome({Key? key, required this.toggleTheme, required this.themeMode})
      : super(key: key);

  @override
  State<ToDoHome> createState() => _ToDoHomeState();
}

class _ToDoHomeState extends State<ToDoHome> {
  final Map<DateTime, List<Task>> _tasksByDate = {};
  final TextEditingController _controller = TextEditingController();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // Tracks if congrats was already shown for the selected day
  final Set<DateTime> _congratsShown = {};

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Task> get _selectedTasks =>
      _tasksByDate[_normalizeDate(_selectedDay)] ?? [];

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  // ── Local Storage ──────────────────────────────────────────────────────────

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encoded = {};
    _tasksByDate.forEach((date, tasks) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      encoded[key] = tasks.map((t) => t.toJson()).toList();
    });
    await prefs.setString('tasks', jsonEncode(encoded));
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tasks');
    if (raw == null) return;

    final Map<String, dynamic> decoded = jsonDecode(raw);
    final Map<DateTime, List<Task>> loaded = {};
    decoded.forEach((dateStr, taskList) {
      final date = DateTime.parse(dateStr);
      loaded[date] = (taskList as List).map((t) {
        final map = Map<String, dynamic>.from(t as Map);
        return Task(
          title: (map['title'] ?? '').toString(),
          note: (map['note'] ?? '').toString(),
          isDone: map['isDone'] == true,
        );
      }).toList();
    });

    setState(() {
      _tasksByDate.clear();
      _tasksByDate.addAll(loaded);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // ── Congratulations Dialog ─────────────────────────────────────────────────
  void _showCongratsIfNeeded() {
    final key = _normalizeDate(_selectedDay);
    final tasks = _tasksByDate[key] ?? [];
    if (tasks.isEmpty) return;

    final allDone = tasks.every((t) => t.isDone);
    if (allDone && !_congratsShown.contains(key)) {
      _congratsShown.add(key);
      // Small delay so checkbox animation finishes first
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 56),
                ),
                const SizedBox(height: 12),
                const Text(
                  'All Done!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You completed all tasks for ${DateFormat('MMMM d').format(_selectedDay)}. Great job!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        );
      });
    } else if (!allDone) {
      // Reset so congrats can show again if user re-completes
      _congratsShown.remove(key);
    }
  }

  // ── Long Press: Show Full Note ─────────────────────────────────────────────
  void _showNoteDialog(Task task) {
    final isLight =
        Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.notes, color: Colors.indigo, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: task.note.isNotEmpty
            ? SingleChildScrollView(
                child: Text(
                  task.note,
                  style: TextStyle(
                    fontSize: 14,
                    color: isLight ? Colors.black87 : Colors.white70,
                  ),
                ),
              )
            : Text(
                'No notes added.',
                style: TextStyle(
                  fontSize: 14,
                  color: isLight ? Colors.black38 : Colors.white38,
                  fontStyle: FontStyle.italic,
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  void _addTask() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
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

    final title = _capitalizeFirst(raw);
    setState(() {
      final key = _normalizeDate(_selectedDay);
      _tasksByDate.putIfAbsent(key, () => []);
      _tasksByDate[key]!.add(Task(title: title));
      // Reset congrats when new task is added
      _congratsShown.remove(key);
    });
    _saveTasks();
    _controller.clear();
  }

  void _confirmDelete(int index) {
    final task = _selectedTasks[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _removeTask(index);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _removeTask(int index) {
    final key = _normalizeDate(_selectedDay);
    final removedTask = _tasksByDate[key]![index];

    setState(() {
      _tasksByDate[key]!.removeAt(index);
      _congratsShown.remove(key);
    });
    _saveTasks();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${removedTask.title}"'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _tasksByDate.putIfAbsent(key, () => []);
              _tasksByDate[key]!.insert(index, removedTask);
            });
            _saveTasks();
          },
        ),
      ),
    );
  }

  void _toggleDone(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTasks[index].isDone = !_selectedTasks[index].isDone;
    });
    _saveTasks();
    _showCongratsIfNeeded();
  }

  void _editTask(int index) {
    final key = _normalizeDate(_selectedDay);
    final task = _tasksByDate[key]![index];
    final editController = TextEditingController(text: task.title);
    final noteController = TextEditingController(text: task.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editController,
              decoration: const InputDecoration(
                labelText: 'Task',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
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
                  task.title = _capitalizeFirst(editController.text.trim());
                  task.note = noteController.text.trim();
                });
                _saveTasks();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

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
    final tasks = _selectedTasks;
    final doneCount = tasks.where((t) => t.isDone).length;
    final totalCount = tasks.length;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: Image.asset('assets/icon/icon.png', width: 24, height: 24),
          onPressed: () {},
        ),
        title: Row(
          children: [
            const Text('To Do List'),
            if (totalCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: progress == 1.0
                      ? Colors.green
                      : Colors.indigo.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$doneCount/$totalCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
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
              markersMaxCount: 1,
              outsideDaysVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
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
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                final normalized = _normalizeDate(day);
                final dayTasks = _tasksByDate[normalized] ?? [];
                final hasTasks = dayTasks.isNotEmpty;
                final allDone =
                    hasTasks && dayTasks.every((t) => t.isDone);
                final isWeekend = day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday;

                Color bgColor;
                if (allDone) {
                  bgColor = Colors.green.shade300;
                } else if (hasTasks) {
                  bgColor = Colors.blue;
                } else {
                  bgColor = Colors.transparent;
                }

                Color textColor;
                if (hasTasks) {
                  textColor = Colors.white;
                } else if (isWeekend) {
                  textColor = Colors.red;
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
              return _tasksByDate[normalized]
                      ?.map((t) => t.title)
                      .toList() ??
                  [];
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
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      filled: true,
                      fillColor:
                          isLight ? Colors.white : Colors.grey[800],
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

          // ── Progress Bar ──────────────────────────────────────────────────
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$doneCount/$totalCount done',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              isLight ? Colors.black54 : Colors.white54,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: progress == 1.0
                              ? Colors.green
                              : Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isLight
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress == 1.0 ? Colors.green : Colors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Task List ─────────────────────────────────────────────────────
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 72,
                          color: isLight
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks for this day',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isLight
                                ? Colors.black54
                                : Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the field above to add one!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isLight
                                ? Colors.black38
                                : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];

                      final Color cardColor = task.isDone
                          ? (isLight
                              ? Colors.green.shade100
                              : Colors.green.shade800)
                          : (isLight
                              ? Colors.white
                              : Colors.grey.shade900);

                      return Dismissible(
                        key: ValueKey(
                            '${_normalizeDate(_selectedDay)}_${index}_${task.title}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
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
                        // ── Long Press → show full note ──────────────────
                        child: GestureDetector(
                          onLongPress: () => _showNoteDialog(task),
                          child: Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            color: cardColor,
                            child: ListTile(
                              leading: Checkbox(
                                value: task.isDone,
                                activeColor: Colors.indigo,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (_) => _toggleDone(index),
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: task.isDone
                                      ? (isLight
                                          ? Colors.black54
                                          : Colors.white70)
                                      : (isLight
                                          ? Colors.black
                                          : Colors.white),
                                  decoration: task.isDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                              subtitle: task.note.isNotEmpty
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task.note,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: task.isDone
                                                  ? (isLight
                                                      ? Colors.black45
                                                      : Colors.white54)
                                                  : (isLight
                                                      ? Colors.black45
                                                      : Colors.white38),
                                            ),
                                          ),
                                        ),
                                        // Hint that long press shows full note
                                        Icon(
                                          Icons.open_in_full,
                                          size: 11,
                                          color: isLight
                                              ? Colors.black26
                                              : Colors.white24,
                                        ),
                                      ],
                                    )
                                  : null,
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
                                    onPressed: () => _confirmDelete(index),
                                  ),
                                ],
                              ),
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