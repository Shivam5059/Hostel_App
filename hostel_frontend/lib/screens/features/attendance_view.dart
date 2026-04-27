import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../user_data.dart';
import '../../theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../admin/csv_helper.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  late Future<dynamic> _attendanceFuture;
  late Future<List<dynamic>> _studentsFuture;

  // Selected date for warden
  DateTime _selectedDate = DateTime.now();
  // Map of studentId -> bool (present state)
  final Map<int, bool> _attendanceStateMap = {};
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      if (UserSession.role == 'STUDENT' || UserSession.role == 'PARENT') {
        _attendanceFuture = ApiManager.getStudentAttendance();
      } else if (UserSession.role == 'WARDEN') {
        _studentsFuture = ApiManager.fetchAssignedStudents();
      }
    });
    return;
  }

  Future<void> _submitWardenAttendance(List<dynamic> students) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    List<Map<String, dynamic>> records = students.map((s) {
      int sId = s['student_id'];
      bool isPresent = _attendanceStateMap[sId] ?? true; // Default present
      return {
        'student_id': sId,
        'status': isPresent ? 'PRESENT' : 'ABSENT'
      };
    }).toList();

    bool success = await ApiManager.submitAttendance(dateStr, records);
    
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Attendance successfully recorded!' : 'Failed to record attendance.'),
        backgroundColor: success ? Colors.green : AppTheme.accentColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = UserSession.role ?? '';
    
    if (role == 'STUDENT' || role == 'PARENT') {
      return RefreshIndicator(
        onRefresh: _fetchData,
        child: _buildStudentPerspective()
      );
    } else if (role == 'WARDEN') {
      return _buildWardenPerspective();
    }
    
    return const Center(child: Text("Attendance not supported for this role."));
  }

  Widget _buildStudentPerspective() {
    return FutureBuilder<dynamic>(
      future: _attendanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.accentColor),
                const SizedBox(height: 16),
                const Text('Failed to load attendance data', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(onPressed: _fetchData, child: const Text('Retry'))
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null || snapshot.data is! Map) {
          return const Center(child: Text('No attendance data found.'));
        }

        final data = snapshot.data as Map<String, dynamic>;
        final summary = data['attendance_summary'] ?? {};
        final records = data['attendance_records'] as List<dynamic>? ?? [];

        return ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF6366F1)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('Overall Attendance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('${summary['attendance_percentage'] ?? 0}%', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBadge('Total', summary['total_classes'].toString(), Colors.blue),
                      _buildStatBadge('Present', summary['present_count'].toString(), Colors.green),
                      _buildStatBadge('Absent', summary['absent_count'].toString(), Colors.redAccent),
                    ],
                  )
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: 32),
            const Text('Recent Records', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No attendance records yet.', style: TextStyle(color: AppTheme.textSecondaryColor)),
              ))
            else
              ...records.map((r) {
                 bool present = r['status'] == 'PRESENT';
                 return Card(
                   color: Colors.white,
                   elevation: 0,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                   margin: const EdgeInsets.only(bottom: 12),
                   child: ListTile(
                     leading: Icon(present ? Icons.check_circle : Icons.cancel, color: present ? Colors.green : Colors.red),
                     title: Text(r['attendance_date'] ?? ''),
                     subtitle: Text('Marked by Warden ID: ${r['warden_id']}'),
                   )
                 );
              }),
          ],
        );
      },
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      )
    );
  }

  Widget _buildWardenPerspective() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TabBar(
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: [Tab(text: 'Mark Attendance'), Tab(text: 'History')],
        ),
        body: TabBarView(
          children: [
            _buildMarkAttendanceTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'export_history',
        onPressed: () async {
          final detailedRecords = await ApiManager.fetchDetailedAttendanceHistory();
          if (detailedRecords.isNotEmpty) {
            final csv = CsvExportHelper.convertToCsv(
              detailedRecords,
              ['Date', 'Student Name', 'Roll No', 'Status'],
              ['attendance_date', 'student_name', 'roll_no', 'status'],
            );
            if (mounted) CsvExportHelper.showExportDialog(context, 'Attendance_History', csv);
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No history to export.')));
          }
        },
        icon: const Icon(Icons.file_download_outlined, color: Colors.white),
        label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiManager.fetchWardenAttendanceHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Failed to load history'));
          
          final history = snapshot.data ?? [];
          if (history.isEmpty) return const Center(child: Text('No attendance history found.'));
          
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final h = history[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h['attendance_date'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMiniStat('Total', h['total_students'].toString(), Colors.blue),
                          _buildMiniStat('Present', h['present_count'].toString(), Colors.green),
                          _buildMiniStat('Absent', h['absent_count'].toString(), Colors.red),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMarkAttendanceTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'submit_attendance',
        onPressed: _isSubmitting ? null : () async {
           final students = await _studentsFuture;
           _submitWardenAttendance(students);
        },
        icon: _isSubmitting 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.done_all, color: Colors.white),
        label: Text(_isSubmitting ? 'Submitting...' : 'Submit Attendance', style: const TextStyle(color: Colors.white)),
        backgroundColor: _isSubmitting ? Colors.grey : AppTheme.primaryColor,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _studentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.accentColor),
                  const SizedBox(height: 16),
                  const Text('Failed to load students', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _fetchData, child: const Text('Retry'))
                ],
              ),
            );
          }

          final students = snapshot.data ?? [];
          
          return RefreshIndicator(
            onRefresh: _fetchData,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: students.isEmpty ? 1 : students.length + 1,
              itemBuilder: (context, index) {
                // Top Header with Date Picker
                if (index == 0) {
                   return Padding(
                     padding: const EdgeInsets.only(bottom: 24),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text('Mark Attendance for:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                         TextButton.icon(
                           icon: const Icon(Icons.calendar_month),
                           label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                           onPressed: _isSubmitting ? null : () async {
                              final date = await showDatePicker(
                                context: context, 
                                initialDate: _selectedDate, 
                                firstDate: DateTime(2020), 
                                lastDate: DateTime.now()
                              );
                              if (date != null) setState(() => _selectedDate = date);
                           },
                         )
                       ],
                     )
                   );
                }
                
                if (students.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: Text('No students assigned to mark.', style: TextStyle(color: AppTheme.textSecondaryColor)),
                  ));
                }

                final s = students[index - 1];
                final sId = s['student_id'];
                final isPresent = _attendanceStateMap[sId] ?? true; 

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    enabled: !_isSubmitting,
                    title: Text(s['name'] ?? ''),
                    subtitle: Text('Roll: ${s['roll_no']}'),
                    trailing: Switch(
                      value: isPresent,
                      activeThumbColor: Colors.green,
                      inactiveThumbColor: Colors.redAccent,
                      onChanged: _isSubmitting ? null : (val) {
                        setState(() {
                          _attendanceStateMap[sId] = val;
                        });
                      },
                    ),
                  ),
                ).animate().fadeIn(delay: (30 * index).ms).slideX(begin: 0.05);
              },
            ),
          );
        },
      )
    );
  }
}
