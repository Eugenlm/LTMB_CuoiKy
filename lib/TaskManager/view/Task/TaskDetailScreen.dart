import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taskmanager/TaskManager/model/Task.dart';
import 'package:taskmanager/TaskManager/db/UserDatabaseHelper.dart';
import 'package:taskmanager/TaskManager/model/User.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task task;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  String? assignedToUsername;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    task = widget.task;
    _loadAssignedUser();
  }

  Future<void> _loadAssignedUser() async {
    if (task.assignedTo == null) return;

    setState(() => _isLoading = true);
    try {
      final user = await UserDatabaseHelper.instance.getUserById(task.assignedTo!);
      setState(() {
        assignedToUsername = user?.username ?? 'Không xác định';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải thông tin người dùng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateStatus(String newStatus) {
    setState(() {
      task = task.copyWith(status: newStatus, updatedAt: DateTime.now());
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

  Widget _buildAttachments() {
    if (task.attachments == null || task.attachments!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: const Text(
          'Không có tệp đính kèm.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: task.attachments!.map((attachment) {
        final isImage = attachment.toLowerCase().endsWith('.jpg') ||
            attachment.toLowerCase().endsWith('.jpeg') ||
            attachment.toLowerCase().endsWith('.png');

        if (isImage) {
          return GestureDetector(
            onTap: () => _showImageDialog(attachment),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 200, // Khung cố định chiều rộng
                      height: 200, // Khung cố định chiều cao
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFF6C63FF), width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(attachment),
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover, // Giữ tỷ lệ và nằm gọn trong khung
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 200,
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Text(
                                  'Không tải được ảnh',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hình ảnh mô tả',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: InkWell(
                onTap: () {
                  // Future: mở file bằng url_launcher
                },
                child: Row(
                  children: [
                    const Icon(Icons.attach_file, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            attachment.split('/').last,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                          Text(
                            'Hỉnh ảnh đính kèm',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.download, color: Colors.grey[500]),
                  ],
                ),
              ),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildInfoCard(String title, String content, {Widget? trailing}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C63FF),
        title: const Text('Chi tiết Công việc'),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard('Tiêu đề', task.title),
              _buildInfoCard(
                'Mô tả',
                task.description.isNotEmpty ? task.description : 'Không có mô tả',
              ),
              _buildInfoCard(
                'Trạng thái',
                task.status,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              _buildInfoCard('Ưu tiên', '${task.priority}'),
              _buildInfoCard(
                'Ngày tới hạn',
                task.dueDate != null
                    ? DateFormat('dd/MM/yyyy').format(task.dueDate!)
                    : 'Chưa đặt ngày tới hạn',
              ),
              _buildInfoCard('Ngày tạo', _dateFormat.format(task.createdAt)),
              _buildInfoCard('Ngày cập nhật', _dateFormat.format(task.updatedAt)),
              _buildInfoCard(
                'Công việc giao cho',
                assignedToUsername ?? 'Chưa gán',
              ),
              const SizedBox(height: 8),
              const Text(
                'Hình ảnh đính kèm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              _buildAttachments(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To do':
        return const Color(0xFF6C63FF);
      case 'In progress':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}