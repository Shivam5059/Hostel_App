import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import '../../user_data.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'csv_helper.dart';

class NoticeManagementView extends StatefulWidget {
  const NoticeManagementView({super.key});

  @override
  State<NoticeManagementView> createState() => _NoticeManagementViewState();
}

class _NoticeManagementViewState extends State<NoticeManagementView> {
  late Future<List<dynamic>> _noticesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _noticesFuture = ApiManager.fetchNotices();
    });
  }

  Future<void> _showNoticeDialog() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post New Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Holiday Announcement'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content', hintText: 'Details of the notice...'),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (result == true && titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
      final res = await ApiManager.createNoticeAdmin({
        'title': titleCtrl.text,
        'content': contentCtrl.text,
        'author_id': UserSession.userId,
      });

      if (res.$1) {
        _refresh();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.$2 ?? 'Failed to post'), backgroundColor: AppTheme.accentColor));
      }
    }
  }

  Future<void> _deleteNotice(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to remove this announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ApiManager.deleteNoticeAdmin(id);
      if (res.$1) {
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notice Board Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export to CSV',
            onPressed: () async {
              final notices = await ApiManager.fetchNotices();
              if (notices.isNotEmpty) {
                final csv = CsvExportHelper.convertToCsv(
                  notices, 
                  ['Date', 'Title', 'Content', 'Author'], 
                  ['created_at', 'title', 'content', 'author_name']
                );
                if (mounted) CsvExportHelper.showExportDialog(context, 'Notices', csv);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<dynamic>>(
          future: _noticesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Error fetching notices"));
            }

            final notices = snapshot.data!;
            if (notices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.announcement_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text("No notices posted yet", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final n = notices[index];
                final date = DateTime.parse(n['created_at']);
                final formattedDate = DateFormat('MMM d, yyyy • hh:mm a').format(date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ExpansionTile(
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    title: Text(n['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.secondaryColor,
                      child: Icon(Icons.campaign_outlined, color: Colors.white),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(n['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.5)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('By: ${n['author_name'] ?? "System"}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
                                TextButton.icon(
                                  onPressed: () => _deleteNotice(n['notice_id']),
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.accentColor),
                                  label: const Text('Remove', style: TextStyle(color: AppTheme.accentColor)),
                                )
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNoticeDialog,
        label: const Text('Post Notice'),
        icon: const Icon(Icons.add_comment_outlined),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
