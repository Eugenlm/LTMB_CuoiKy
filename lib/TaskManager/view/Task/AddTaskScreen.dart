import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:taskmanager/TaskManager/model/Task.dart';
import 'package:taskmanager/TaskManager/model/User.dart';
import 'package:taskmanager/TaskManager/db/TaskDatabaseHelper.dart';
import 'package:taskmanager/TaskManager/db/UserDatabaseHelper.dart';

class AddTaskScreen extends StatefulWidget {
  final String currentUserId;

  const AddTaskScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'To do';
  int _priority = 1;
  DateTime? _dueDate;
  String? _assignedTo;
  List<String> _attachments = [];
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  final List<String> _statusOptions = ['To do', 'In progress', 'Done', 'Cancelled'];
  final List<int> _priorityOptions = [1, 2, 3];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      User? currentUser = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = currentUser?.isAdmin ?? false;

      if (_isAdmin) {
        _users = await UserDatabaseHelper.instance.getAllUsers();
        _users.removeWhere((user) => user.id == widget.currentUserId);
      } else {
        _users = [];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải user: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'], // Chỉ cho phép hình ảnh
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.paths.where((path) => path != null).cast<String>());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              // Hình ảnh phóng to
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                ),
              ),
              // Nút đóng
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF6C63FF),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF6C63FF),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _handleAddTask() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);
        final newTask = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          status: _status,
          priority: _priority,
          dueDate: _dueDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          assignedTo: _isAdmin ? _assignedTo : widget.currentUserId,
          createdBy: widget.currentUserId,
          category: null,
          attachments: _attachments.isNotEmpty ? _attachments : null,
          completed: _status == 'Done',
        );
        await TaskDatabaseHelper.instance.createTask(newTask);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thêm công việc thành công!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm công việc: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Thêm công việc mới',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF6C63FF),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THÔNG TIN CÔNG VIỆC
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: _containerDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin công việc',
                      style: _sectionTitleStyle(),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('Tiêu đề *', 'Nhập tiêu đề công việc', Icons.title),
                      style: TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tiêu đề';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _inputDecoration('Mô tả', 'Nhập mô tả chi tiết (nếu có)', Icons.description),
                      maxLines: 3,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // CÀI ĐẶT CÔNG VIỆC
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: _containerDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cài đặt công việc', style: _sectionTitleStyle()),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Flexible(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _inputDecoration('Trạng thái', '', Icons.info),
                            items: _statusOptions.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _status = value);
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Flexible(
                          child: DropdownButtonFormField<int>(
                            value: _priority,
                            decoration: _inputDecoration('Độ ưu tiên', '', Icons.priority_high),
                            items: _priorityOptions.map((priority) {
                              return DropdownMenuItem<int>(
                                value: priority,
                                child: Text('Ưu tiên $priority'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _priority = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDueDate(context),
                      child: InputDecorator(
                        decoration: _inputDecoration('Ngày đến hạn', '', Icons.calendar_today),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _dueDate == null ? 'Chọn ngày' : DateFormat('dd/MM/yyyy').format(_dueDate!),
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    if (_users.isNotEmpty && _isAdmin)
                      DropdownButtonFormField<String>(
                        value: _assignedTo,
                        decoration: _inputDecoration('Gán cho người dùng', '', Icons.person_add),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Không gán cho ai'),
                          ),
                          ..._users.map((user) {
                            return DropdownMenuItem<String>(
                              value: user.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Color(0xFF6C63FF).withOpacity(0.1),
                                    child: Text(
                                      user.username[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(user.username),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) => setState(() => _assignedTo = value),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // TỆP ĐÍNH KÈM
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: _containerDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hình ảnh đính kèm', style: _sectionTitleStyle()),
                    SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _pickFiles,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Color(0xFF6C63FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attach_file, color: Color(0xFF6C63FF)),
                          SizedBox(width: 8),
                          Text('Thêm hình ảnh mô tả', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 16)),
                        ],
                      ),
                    ),
                    if (_attachments.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachments.asMap().entries.map((entry) {
                            final index = entry.key;
                            final path = entry.value;
                            final isImage = path.toLowerCase().endsWith('.jpg') ||
                                path.toLowerCase().endsWith('.jpeg') ||
                                path.toLowerCase().endsWith('.png');

                            if (isImage) {
                              // Hiển thị thumbnail cho hình ảnh
                              return GestureDetector(
                                onTap: () => _showImageDialog(path), // Mở dialog khi nhấn
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Color(0xFF6C63FF), width: 1),
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 40,
                                          ),
                                        ),
                                      ),
                                      // Nút xóa
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () => _removeAttachment(index),
                                          child: Container(
                                            padding: EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.close, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              // Hiển thị chip cho các file không phải hình ảnh
                              return Chip(
                                label: Text(path.split('/').last, style: TextStyle(fontSize: 14)),
                                deleteIcon: Icon(Icons.close, size: 18),
                                onDeleted: () => _removeAttachment(index),
                                backgroundColor: Color(0xFF6C63FF).withOpacity(0.1),
                                labelPadding: EdgeInsets.symmetric(horizontal: 8),
                              );
                            }
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // NÚT THÊM
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleAddTask,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: Text(
                    'THÊM CÔNG VIỆC',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Color(0xFF6C63FF)),
      filled: true,
      fillColor: Color(0xFFFAFAFA),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.5)),
      contentPadding: EdgeInsets.symmetric(vertical: 0),
    );
  }

  BoxDecoration _containerDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          spreadRadius: 5,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  TextStyle _sectionTitleStyle() {
    return TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333));
  }
}