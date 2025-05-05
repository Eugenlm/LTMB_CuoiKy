import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:taskmanager/TaskManager/model/Task.dart';
import 'package:taskmanager/TaskManager/model/User.dart';
import 'package:taskmanager/TaskManager/db/UserDatabaseHelper.dart';

class EditTaskScreen extends StatefulWidget {
  final Task task;
  final String currentUserId;

  const EditTaskScreen({
    Key? key,
    required this.task,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _EditTaskScreenState createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _status;
  late int _priority;
  late DateTime? _dueDate;
  late String? _assignedTo;
  late List<String> _attachments;
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final List<String> _statusOptions = ['To do', 'In progress', 'Done', 'Cancelled'];
  final List<int> _priorityOptions = [1, 2, 3];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _status = widget.task.status;
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;
    _assignedTo = widget.task.assignedTo;
    _attachments = widget.task.attachments ?? [];
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      User? currentUser = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = currentUser?.isAdmin ?? false;

      if (_isAdmin) {
        _users = await UserDatabaseHelper.instance.getAllUsersExcept(widget.currentUserId);
      } else {
        _users = [];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải danh sách người dùng: $e'),
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

  Future<void> _pickFiles() async {
    if (!_isAdmin) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'], // Chỉ cho phép hình ảnh
      );

      if (result != null) {
        setState(() {
          _attachments.addAll(result.paths.where((path) => path != null).cast<String>());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn file: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    if (!_isAdmin) return;
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
    if (!_isAdmin) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
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

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final updatedTask = widget.task.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        status: _status,
        priority: _priority,
        dueDate: _dueDate,
        updatedAt: DateTime.now(),
        assignedTo: _isAdmin ? _assignedTo : widget.task.assignedTo,
        attachments: _attachments.isNotEmpty ? _attachments : null,
        completed: _status == 'Done',
      );
      Navigator.pop(context, updatedTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa công việc',
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
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông tin công việc
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông tin công việc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Tiêu đề
                    TextFormField(
                      controller: _titleController,
                      enabled: _isAdmin,
                      decoration: InputDecoration(
                        labelText: 'Tiêu đề *',
                        hintText: 'Nhập tiêu đề công việc',
                        prefixIcon: Icon(Icons.title, color: Color(0xFF6C63FF)),
                        filled: true,
                        fillColor: Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFEEEEEE)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập tiêu đề';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // Mô tả
                    TextFormField(
                      controller: _descriptionController,
                      enabled: _isAdmin,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Mô tả',
                        hintText: 'Nhập mô tả chi tiết...',
                        prefixIcon: Icon(Icons.description, color: Color(0xFF6C63FF)),
                        filled: true,
                        fillColor: Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFEEEEEE)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Cài đặt công việc
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cài đặt công việc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Trạng thái và Độ ưu tiên
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trạng thái',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFFEEEEEE)),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: DropdownButton<String>(
                                  value: _status,
                                  isExpanded: true,
                                  underline: SizedBox(),
                                  items: _statusOptions.map((status) {
                                    return DropdownMenuItem<String>(
                                      value: status,
                                      child: Text(status),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _status = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Độ ưu tiên',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Color(0xFFEEEEEE)),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: IgnorePointer(
                                  ignoring: !_isAdmin,
                                  child: DropdownButton<int>(
                                    value: _priority,
                                    isExpanded: true,
                                    underline: SizedBox(),
                                    items: _priorityOptions.map((priority) {
                                      return DropdownMenuItem<int>(
                                        value: priority,
                                        child: Text('Mức $priority'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _priority = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Ngày đến hạn
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngày đến hạn',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        InkWell(
                          onTap: _isAdmin ? () => _selectDueDate(context) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFEEEEEE)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _dueDate == null ? 'Chọn ngày' : _dateFormat.format(_dueDate!),
                                  style: TextStyle(fontSize: 16),
                                ),
                                Icon(Icons.calendar_today, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Gán cho người dùng
                    if (_users.isNotEmpty && _isAdmin) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gán cho người dùng',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFEEEEEE)),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<String>(
                              value: _assignedTo,
                              isExpanded: true,
                              underline: SizedBox(),
                              hint: Text('Chọn người dùng'),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('Không gán'),
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
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _assignedTo = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Tệp đính kèm
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hỉnh ảnh đính kèm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _isAdmin ? _pickFiles : null,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFF6C63FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.attach_file, color: Color(0xFF6C63FF)),
                          SizedBox(width: 8),
                          Text(
                            'Thêm hình ảnh mô tả',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),

                    // Danh sách file đã chọn
                    if (_attachments.isNotEmpty) ...[
                      SizedBox(height: 12),
                      Wrap(
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
                                    if (_isAdmin)
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
                            return Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFFEEEEEE)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.insert_drive_file, color: Color(0xFF6C63FF)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      path.split('/').last,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (_isAdmin)
                                    IconButton(
                                      icon: Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _removeAttachment(index),
                                    ),
                                ],
                              ),
                            );
                          }
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Nút lưu thay đổi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'LƯU THAY ĐỔI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
}