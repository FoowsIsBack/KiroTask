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
  bool isPinned;           // NEW: pinned/starred
  DateTime createdAt;      // NEW: creation date

  Task({
    required this.title,
    this.note = '',
    this.isDone = false,
    this.isPinned = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'title': title,
        'note': note,
        'isDone': isDone,
        'isPinned': isPinned,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: (json['title'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
        isDone: json['isDone'] == true,
        isPinned: json['isPinned'] == true,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ─── Constants ────────────────────────────────────────────────────────────────
const int kMaxTitleLength = 100;
const String kAppVersion = '1.0.0';

// ─── App Root ─────────────────────────────────────────────────────────────────
class ToDoApp extends StatefulWidget {
  const ToDoApp({super.key});

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
      title: 'KiroTask',
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
  const SplashScreen({super.key});

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
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
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
                      'assets/icon/KiroTask.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('KiroTask',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                const Text('Stay organized, stay on track.',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 14)),
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

  const ToDoHome(
      {super.key, required this.toggleTheme, required this.themeMode});

  @override
  State<ToDoHome> createState() => _ToDoHomeState();
}

class _ToDoHomeState extends State<ToDoHome> {
  final Map<DateTime, List<Task>> _tasksByDate = {};
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  bool _showNoteField = false;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _congratsShown = {};
  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();

  void _dismissKeyboard() {
    _titleFocus.unfocus();
    _noteFocus.unfocus();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Sort order: pinned first, then undone, then done
  List<Task> get _selectedTasks {
    final all = _tasksByDate[_normalizeDate(_selectedDay)] ?? [];
    final pinnedUndone =
        all.where((t) => t.isPinned && !t.isDone).toList();
    final unpinnedUndone =
        all.where((t) => !t.isPinned && !t.isDone).toList();
    final pinnedDone =
        all.where((t) => t.isPinned && t.isDone).toList();
    final unpinnedDone =
        all.where((t) => !t.isPinned && t.isDone).toList();
    return [
      ...pinnedUndone,
      ...unpinnedUndone,
      ...pinnedDone,
      ...unpinnedDone,
    ];
  }

  List<Task> get _rawTasks =>
      _tasksByDate[_normalizeDate(_selectedDay)] ?? [];

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Format creation date nicely
  String _formatCreatedAt(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(taskDay).inDays;

    if (diff == 0) return 'Today, ${DateFormat('h:mm a').format(dt)}';
    if (diff == 1) return 'Yesterday, ${DateFormat('h:mm a').format(dt)}';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  // ── Monthly summary helpers ────────────────────────────────────────────────
  int get _monthTotalTasks {
    int count = 0;
    _tasksByDate.forEach((date, tasks) {
      if (date.year == _focusedDay.year &&
          date.month == _focusedDay.month) count += tasks.length;
    });
    return count;
  }

  int get _monthDoneTasks {
    int count = 0;
    _tasksByDate.forEach((date, tasks) {
      if (date.year == _focusedDay.year &&
          date.month == _focusedDay.month)
        count += tasks.where((t) => t.isDone).length;
    });
    return count;
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
        return Task.fromJson(map);
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

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
    _titleFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  // ── Pull to Refresh ────────────────────────────────────────────────────────
  Future<void> _onRefresh() async {
    _dismissKeyboard();
    await _loadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tasks refreshed!'),
        duration: Duration(seconds: 1),
      ));
    }
  }

  // ── About Dialog ──────────────────────────────────────────────────────────
  void _showAboutDialog() {
    _dismissKeyboard();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/icon/KiroTask.png',
                  width: 72, height: 72, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            const Text('KiroTask',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Version $kAppVersion',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _infoRow(Icons.person_outline, 'Developer', 'Dave Bangcoyo'),
            const SizedBox(height: 8),
            _infoRow(Icons.calendar_today_outlined, 'Built with',
                'Flutter & Dart'),
            const SizedBox(height: 8),
            _infoRow(Icons.storage_outlined, 'Storage',
                'SharedPreferences (local)'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _infoRow(Icons.swipe_right_alt, 'Swipe Right', 'Delete task'),
            const SizedBox(height: 8),
            _infoRow(Icons.swipe_left_alt, 'Swipe Left', 'Edit task'),
            const SizedBox(height: 8),
            _infoRow(Icons.push_pin_outlined, 'Pin icon', 'Pin task to top'),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.indigo),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── Congratulations Dialog ─────────────────────────────────────────────────
  void _showCongratsIfNeeded() {
    final key = _normalizeDate(_selectedDay);
    final tasks = _tasksByDate[key] ?? [];
    if (tasks.isEmpty) return;
    final allDone = tasks.every((t) => t.isDone);
    if (allDone && !_congratsShown.contains(key)) {
      _congratsShown.add(key);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text('All Done!',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'You completed all tasks for ${DateFormat('MMMM d').format(_selectedDay)}. Great job!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey),
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
                        borderRadius: BorderRadius.circular(12)),
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
      _congratsShown.remove(key);
    }
  }

  // ── Long Press: Show Full Note + Creation Date ─────────────────────────────
  void _showNoteDialog(Task task) {
    _dismissKeyboard();
    final isLight = Theme.of(context).brightness == Brightness.light;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.notes, color: Colors.indigo, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(task.title,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Creation date ────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 13,
                    color: isLight ? Colors.black38 : Colors.white38),
                const SizedBox(width: 4),
                Text(
                  'Created: ${_formatCreatedAt(task.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isLight ? Colors.black38 : Colors.white38,
                  ),
                ),
              ],
            ),
            if (task.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              SingleChildScrollView(
                child: Text(task.note,
                    style: TextStyle(
                        fontSize: 14,
                        color: isLight
                            ? Colors.black87
                            : Colors.white70)),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text('No notes added.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isLight ? Colors.black38 : Colors.white38,
                    fontStyle: FontStyle.italic,
                  )),
            ],
          ],
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

  // ── Clear All Done ─────────────────────────────────────────────────────────
  void _clearDoneTasks() {
    _dismissKeyboard();
    final key = _normalizeDate(_selectedDay);
    final done =
        (_tasksByDate[key] ?? []).where((t) => t.isDone).toList();
    if (done.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed'),
        content: Text(
            'Remove ${done.length} completed task${done.length > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _tasksByDate[key]?.removeWhere((t) => t.isDone);
                _congratsShown.remove(key);
              });
              _saveTasks();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '${done.length} completed task${done.length > 1 ? 's' : ''} removed'),
                duration: const Duration(seconds: 2),
              ));
            },
            child: const Text('Clear',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
  void _addTask() {
    _dismissKeyboard();
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
    final note = _noteController.text.trim();
    final key = _normalizeDate(_selectedDay);
    final existing = _tasksByDate[key] ?? [];
    final isDuplicate = existing
        .any((t) => t.title.toLowerCase() == title.toLowerCase());

    if (isDuplicate) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Task'),
          content: Text(
              '"$title" already exists for this day. Add it anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _doAddTask(title, note);
              },
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );
      return;
    }
    _doAddTask(title, note);
  }

  void _doAddTask(String title, String note) {
    final key = _normalizeDate(_selectedDay);
    final newTask = Task(title: title, note: note);
    setState(() {
      _tasksByDate.putIfAbsent(key, () => []);
      _tasksByDate[key]!.add(newTask);
      _congratsShown.remove(key);
    });
    final sortedTasks = _selectedTasks;
    final insertIndex = sortedTasks.indexOf(newTask);
    _listKey.currentState
        ?.insertItem(insertIndex < 0 ? 0 : insertIndex);
    _saveTasks();
    _controller.clear();
    _noteController.clear();
    setState(() => _showNoteField = false);
  }

  void _confirmDelete(int index) {
    _dismissKeyboard();
    final task = _selectedTasks[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content:
            Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
    final taskToRemove = _selectedTasks[index];
    final rawIndex = _rawTasks.indexOf(taskToRemove);

    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildAnimatedCard(taskToRemove, animation),
    );
    setState(() {
      if (rawIndex != -1) _tasksByDate[key]!.removeAt(rawIndex);
      _congratsShown.remove(key);
    });
    _saveTasks();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted "${taskToRemove.title}"'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          setState(() {
            _tasksByDate.putIfAbsent(key, () => []);
            if (rawIndex != -1) {
              _tasksByDate[key]!.insert(rawIndex, taskToRemove);
            } else {
              _tasksByDate[key]!.add(taskToRemove);
            }
          });
          _listKey.currentState?.insertItem(index);
          _saveTasks();
        },
      ),
    ));
  }

  void _toggleDone(int index) {
    _dismissKeyboard();
    HapticFeedback.lightImpact();
    final key = _normalizeDate(_selectedDay);
    final taskToToggle = _selectedTasks[index];
    final rawIndex = _rawTasks.indexOf(taskToToggle);
    setState(() {
      if (rawIndex != -1) {
        _tasksByDate[key]![rawIndex].isDone =
            !_tasksByDate[key]![rawIndex].isDone;
      }
    });
    _saveTasks();
    _showCongratsIfNeeded();
  }

  /// Toggle pinned status
  void _togglePin(int index) {
    HapticFeedback.lightImpact();
    final key = _normalizeDate(_selectedDay);
    final taskToPin = _selectedTasks[index];
    final rawIndex = _rawTasks.indexOf(taskToPin);
    setState(() {
      if (rawIndex != -1) {
        _tasksByDate[key]![rawIndex].isPinned =
            !_tasksByDate[key]![rawIndex].isPinned;
      }
    });
    _saveTasks();
  }

  void _editTask(int index) {
    _dismissKeyboard();
    final key = _normalizeDate(_selectedDay);
    final task = _selectedTasks[index];
    final rawIndex = _rawTasks.indexOf(task);
    final editController = TextEditingController(text: task.title);
    final noteEditController =
        TextEditingController(text: task.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: editController,
              maxLength: kMaxTitleLength,
              decoration: const InputDecoration(
                labelText: 'Task',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteEditController,
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
              if (editController.text.trim().isNotEmpty &&
                  rawIndex != -1) {
                setState(() {
                  _tasksByDate[key]![rawIndex].title =
                      _capitalizeFirst(editController.text.trim());
                  _tasksByDate[key]![rawIndex].note =
                      noteEditController.text.trim();
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
    _dismissKeyboard();
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

  // ── Animated Card Builder ─────────────────────────────────────────────────
  Widget _buildAnimatedCard(Task task, Animation<double> animation) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final Color cardColor = task.isDone
        ? (isLight ? Colors.green.shade100 : Colors.green.shade800)
        : (isLight ? Colors.white : Colors.grey.shade900);

    return SizeTransition(
      sizeFactor:
          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: FadeTransition(
        opacity: animation,
        child: Card(
          margin:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          color: cardColor,
          child: ListTile(
            leading: Checkbox(
              value: task.isDone,
              activeColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              onChanged: null,
            ),
            title: Text(task.title,
                style: TextStyle(
                  fontSize: 16,
                  color: task.isDone
                      ? (isLight ? Colors.black54 : Colors.white70)
                      : (isLight ? Colors.black : Colors.white),
                  decoration: task.isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                )),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tasks = _selectedTasks;
    final doneCount = tasks.where((t) => t.isDone).length;
    final totalCount = tasks.length;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;
    final hasDone = doneCount > 0;
    final mTotal = _monthTotalTasks;
    final mDone = _monthDoneTasks;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: IconButton(
            icon: Image.asset('assets/icon/KiroTask.png',
                width: 24, height: 24),
            onPressed: _showAboutDialog,
            tooltip: 'About',
          ),
          title: Row(
            children: [
              const Text('KiroTask'),
              if (totalCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: progress == 1.0
                        ? Colors.green
                        : Colors.indigo.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$doneCount/$totalCount',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          elevation: 0,
          actions: [
            if (hasDone)
              IconButton(
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: 'Clear completed tasks',
                onPressed: _clearDoneTasks,
              ),
            IconButton(
              icon: Icon(widget.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode),
              onPressed: widget.toggleTheme,
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Calendar ──────────────────────────────────────────────────
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                _dismissKeyboard();
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _dismissKeyboard();
                setState(() => _focusedDay = focusedDay);
              },
              headerStyle: const HeaderStyle(
                  formatButtonVisible: false, titleCentered: true),
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                    color: Colors.orange, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
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
                          color: Colors.indigo),
                    ),
                  );
                },
                todayBuilder: (context, day, focusedDay) => Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                  child: Text('${day.day}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                selectedBuilder: (context, day, focusedDay) =>
                    Container(
                  margin: const EdgeInsets.all(6),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                  child: Text('${day.day}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                defaultBuilder: (context, day, focusedDay) {
                  final normalized = _normalizeDate(day);
                  final dayTasks = _tasksByDate[normalized] ?? [];
                  final hasTasks = dayTasks.isNotEmpty;
                  final allDone =
                      hasTasks && dayTasks.every((t) => t.isDone);
                  final isWeekend =
                      day.weekday == DateTime.saturday ||
                          day.weekday == DateTime.sunday;
                  final bgColor = allDone
                      ? Colors.green.shade300
                      : hasTasks
                          ? Colors.blue
                          : Colors.transparent;
                  final textColor = hasTasks
                      ? Colors.white
                      : isWeekend
                          ? Colors.red
                          : (isLight ? Colors.black : Colors.white);
                  return Container(
                    margin: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: bgColor, shape: BoxShape.circle),
                    child: Text('${day.day}',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: hasTasks
                                ? FontWeight.bold
                                : FontWeight.normal)),
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

            // ── Monthly Summary Banner ─────────────────────────────────────
            if (mTotal > 0)
              Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.indigo.shade50
                      : Colors.indigo.shade900,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month,
                        size: 16,
                        color: isLight
                            ? Colors.indigo
                            : Colors.indigo.shade200),
                    const SizedBox(width: 8),
                    Text(DateFormat('MMMM').format(_focusedDay),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLight
                                ? Colors.indigo
                                : Colors.indigo.shade200)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: mDone == mTotal
                            ? Colors.green
                            : Colors.indigo.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$mDone/$mTotal done',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mTotal == 0 ? 0 : mDone / mTotal,
                          minHeight: 6,
                          backgroundColor: isLight
                              ? Colors.indigo.shade100
                              : Colors.indigo.shade700,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            mDone == mTotal
                                ? Colors.green
                                : Colors.indigo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Input Row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _titleFocus,
                          onSubmitted: (_) => _addTask(),
                          textCapitalization:
                              TextCapitalization.sentences,
                          maxLength: kMaxTitleLength,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                kMaxTitleLength),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Add a new task...',
                            filled: true,
                            fillColor: isLight
                                ? Colors.white
                                : Colors.grey[800],
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            counterText: '',
                            suffixIcon: IconButton(
                              icon: Icon(Icons.note_add_outlined,
                                  color: _showNoteField
                                      ? Colors.indigo
                                      : Colors.grey,
                                  size: 20),
                              tooltip: 'Add note',
                              onPressed: () => setState(() =>
                                  _showNoteField = !_showNoteField),
                            ),
                          ),
                          style: TextStyle(
                              color: isLight
                                  ? Colors.black
                                  : Colors.white),
                          buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) {
                            if (currentLength > 80) {
                              return Text('$currentLength/$maxLength',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: currentLength >=
                                              kMaxTitleLength
                                          ? Colors.red
                                          : Colors.grey));
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                        ),
                        onPressed: _addTask,
                        child: const Text('Add',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    firstChild: const SizedBox(height: 8),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: _noteController,
                        focusNode: _noteFocus,
                        maxLines: 2,
                        textCapitalization:
                            TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Add a note (optional)...',
                          filled: true,
                          fillColor: isLight
                              ? Colors.white
                              : Colors.grey[800],
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(
                            color: isLight
                                ? Colors.black
                                : Colors.white,
                            fontSize: 13),
                      ),
                    ),
                    crossFadeState: _showNoteField
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                  ),
                ],
              ),
            ),

            // ── Progress Bar ───────────────────────────────────────────────
            if (totalCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$doneCount/$totalCount done',
                            style: TextStyle(
                                fontSize: 13,
                                color: isLight
                                    ? Colors.black54
                                    : Colors.white54)),
                        Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: progress == 1.0
                                    ? Colors.green
                                    : Colors.indigo)),
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
                            progress == 1.0
                                ? Colors.green
                                : Colors.indigo),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Task List ─────────────────────────────────────────────────
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 72,
                              color: isLight
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700),
                          const SizedBox(height: 16),
                          Text('No tasks for this day',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isLight
                                      ? Colors.black54
                                      : Colors.white54)),
                          const SizedBox(height: 6),
                          Text('Tap the field above to add one!',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isLight
                                      ? Colors.black38
                                      : Colors.white38)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: Colors.indigo,
                      child: AnimatedList(
                        key: _listKey,
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        initialItemCount: tasks.length,
                        itemBuilder:
                            (context, index, animation) {
                          if (index >= tasks.length)
                            return const SizedBox.shrink();
                          final task = tasks[index];
                          final Color cardColor = task.isDone
                              ? (isLight
                                  ? Colors.green.shade100
                                  : Colors.green.shade800)
                              : (isLight
                                  ? Colors.white
                                  : Colors.grey.shade900);

                          return SizeTransition(
                            sizeFactor: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut),
                            child: FadeTransition(
                              opacity: animation,
                              child: Dismissible(
                                key: ValueKey(
                                    '${_normalizeDate(_selectedDay)}_${task.title}_${task.isDone}_${task.isPinned}'),
                                direction:
                                    DismissDirection.horizontal,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20),
                                  margin:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete,
                                          color: Colors.white,
                                          size: 24),
                                      SizedBox(width: 6),
                                      Text('Delete',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 20),
                                  margin:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      Text('Edit',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 13)),
                                      SizedBox(width: 6),
                                      Icon(Icons.edit,
                                          color: Colors.white,
                                          size: 24),
                                    ],
                                  ),
                                ),
                                confirmDismiss:
                                    (direction) async {
                                  if (direction ==
                                      DismissDirection
                                          .startToEnd) {
                                    bool confirm = false;
                                    await showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text(
                                            'Delete Task'),
                                        content: Text(
                                            'Are you sure you want to delete "${task.title}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              confirm = false;
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text(
                                                'Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton
                                                .styleFrom(
                                                    backgroundColor:
                                                        Colors.red),
                                            onPressed: () {
                                              confirm = true;
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                    color: Colors
                                                        .white)),
                                          ),
                                        ],
                                      ),
                                    );
                                    return confirm;
                                  } else {
                                    _editTask(index);
                                    return false;
                                  }
                                },
                                onDismissed: (direction) {
                                  if (direction ==
                                      DismissDirection.startToEnd)
                                    _removeTask(index);
                                },
                                child: GestureDetector(
                                  onLongPress: () =>
                                      _showNoteDialog(task),
                                  child: Card(
                                    margin: const EdgeInsets
                                        .symmetric(
                                        horizontal: 12,
                                        vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12)),
                                    elevation: 3,
                                    color: cardColor,
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: task.isDone,
                                        activeColor: Colors.indigo,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    4)),
                                        onChanged: (_) =>
                                            _toggleDone(index),
                                      ),
                                      title: Row(
                                        children: [
                                          // ── Pin indicator ────────────
                                          if (task.isPinned)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                  right: 4),
                                              child: Icon(
                                                Icons.push_pin,
                                                size: 14,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: task.isDone
                                                    ? (isLight
                                                        ? Colors
                                                            .black54
                                                        : Colors
                                                            .white70)
                                                    : (isLight
                                                        ? Colors.black
                                                        : Colors
                                                            .white),
                                                decoration: task
                                                        .isDone
                                                    ? TextDecoration
                                                        .lineThrough
                                                    : TextDecoration
                                                        .none,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // ── Subtitle: note + creation date
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          if (task.note.isNotEmpty)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    task.note,
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: task.isDone
                                                          ? (isLight
                                                              ? Colors
                                                                  .black45
                                                              : Colors
                                                                  .white54)
                                                          : (isLight
                                                              ? Colors
                                                                  .black45
                                                              : Colors
                                                                  .white38),
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                    Icons
                                                        .open_in_full,
                                                    size: 11,
                                                    color: isLight
                                                        ? Colors
                                                            .black26
                                                        : Colors
                                                            .white24),
                                              ],
                                            ),
                                          // ── Creation date ────────────
                                          Text(
                                            _formatCreatedAt(
                                                task.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isLight
                                                  ? Colors.black38
                                                  : Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          // ── Pin button ───────────────
                                          IconButton(
                                            icon: Icon(
                                              task.isPinned
                                                  ? Icons.push_pin
                                                  : Icons
                                                      .push_pin_outlined,
                                              color: task.isPinned
                                                  ? Colors.orange
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                            tooltip: task.isPinned
                                                ? 'Unpin'
                                                : 'Pin to top',
                                            onPressed: () =>
                                                _togglePin(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _editTask(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _confirmDelete(
                                                    index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}