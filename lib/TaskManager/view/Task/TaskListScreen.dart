import 'package:flutter/material.dart';
import 'package:taskmanager/TaskManager/view/Task/AddTaskScreen.dart';
import 'package:taskmanager/TaskManager/view/Task/EditTaskScreen.dart';
import 'package:taskmanager/TaskManager/model/Task.dart';
import 'package:taskmanager/TaskManager/view/Task/TaskDetailScreen.dart';
import 'package:taskmanager/TaskManager/view/Authentication/LoginScreen.dart';
import 'package:taskmanager/TaskManager/db/TaskDatabaseHelper.dart';
import 'package:taskmanager/TaskManager/db/UserDatabaseHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskListScreen extends StatefulWidget {
  final String currentUserId;

  const TaskListScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  List<Task> filteredTasks = [];
  bool isGrid = false;
  String selectedStatus = 'Tất cả';
  String searchKeyword = '';
  bool _isLoading = false;
  bool _dbInitialized = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      setState(() => _isLoading = true);
      await TaskDatabaseHelper.instance.database;
      setState(() => _dbInitialized = true);

      final user = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = user?.isAdmin ?? false;

      await _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khởi tạo database: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    if (!_dbInitialized) return;

    try {
      setState(() => _isLoading = true);

      if (_isAdmin) {
        tasks = await TaskDatabaseHelper.instance.getAllTasks();
      } else {
        tasks = await TaskDatabaseHelper.instance.getTasksByUser(widget.currentUserId);
      }

      _applyFilters();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải công việc: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      filteredTasks = tasks.where((task) {
        final matchesStatus = selectedStatus == 'Tất cả' || task.status == selectedStatus;
        final matchesSearch = searchKeyword.isEmpty ||
            task.title.toLowerCase().contains(searchKeyword.toLowerCase()) ||
            task.description.toLowerCase().contains(searchKeyword.toLowerCase());
        return matchesStatus && matchesSearch;
      }).toList();

      filteredTasks.sort((a, b) => b.priority.compareTo(a.priority));
    });
  }

  bool _isTaskNearDueDate(Task task) {
    if (task.dueDate == null || task.status == 'Done' || task.status == 'Cancelled') {
      return false;
    }
    final now = DateTime.now();
    final difference = task.dueDate!.difference(now);
    return difference.inHours <= 24 && difference.inHours >= 0;
  }

  Future<void> _deleteTask(String taskId) async {
    final task = tasks.firstWhere((task) => task.id == taskId);

    if (!_isAdmin && task.createdBy != widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là công việc do Admin thêm cho bạn nên không có quyền xoá!')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await TaskDatabaseHelper.instance.deleteTask(taskId);
        await _loadTasks();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa task: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Color(0xFF6C63FF),
        elevation: 1,
        title: Row(
          children: [
            const Flexible(
              child: Text(
                'Tất cả công việc',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (_isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadTasks),
          IconButton(
            icon: Icon(isGrid ? Icons.view_list : Icons.grid_view, color: Colors.white),
            onPressed: () => setState(() => isGrid = !isGrid),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: isGrid ? _buildTaskGridView() : _buildTaskListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskScreen(currentUserId: widget.currentUserId)),
          );
          if (result == true) await _loadTasks();
        },
        label: const Text(
          'Thêm công việc',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Color(0xFF6C63FF),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm công việc',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  searchKeyword = value;
                  _applyFilters();
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                ),
                isExpanded: true,
                items: ['Tất cả', 'To do', 'In progress', 'Done', 'Cancelled']
                    .map((status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
                    .toList(),
                onChanged: (value) {
                  selectedStatus = value!;
                  _applyFilters();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListView() {
    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isNearDue = _isTaskNearDueDate(task);
        return Card(
          color: _getPriorityColor(task.priority),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: ListTile(
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isNearDue)
                  Row(
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 4), // khoảng cách giữa icon và chữ
                      Text(
                        'Gần đến hạn',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            subtitle: Text('Trạng thái: ${task.status} • Ưu tiên: ${_priorityText(task.priority)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    final updatedTask = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTaskScreen(task: task, currentUserId: widget.currentUserId),
                      ),
                    );
                    if (updatedTask != null) {
                      await TaskDatabaseHelper.instance.updateTask(updatedTask);
                      await _loadTasks();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTask(task.id),
                ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
              );
              await _loadTasks();
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 4 / 3,
      ),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isNearDue = _isTaskNearDueDate(task);
        return GestureDetector(
          onTap: () async {
            final updatedTask = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditTaskScreen(task: task, currentUserId: widget.currentUserId),
              ),
            );
            if (updatedTask != null) {
              await TaskDatabaseHelper.instance.updateTask(updatedTask);
              await _loadTasks();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade300, blurRadius: 6, offset: const Offset(2, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNearDue)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Trạng thái: ${task.status}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text('Ưu tiên: ${_priorityText(task.priority)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.green.shade100;
      case 2:
        return Colors.orange.shade100;
      case 3:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  String _priorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Thấp';
      case 2:
        return 'Trung bình';
      case 3:
        return 'Cao';
      default:
        return 'Không xác định';
    }
  }
}