import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import '../../user_data.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'student_details_view.dart';

class StudentsView extends StatefulWidget {
  const StudentsView({super.key});

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  late Future<List<dynamic>> _myStudentsFuture;
  late Future<List<dynamic>> _unassignedStudentsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _myStudentsFuture = ApiManager.fetchAssignedStudents();
      if (UserSession.role == 'COUNSELOR') {
        _unassignedStudentsFuture = ApiManager.fetchUnassignedStudents();
      } else if (UserSession.role == 'WARDEN') {
        _unassignedStudentsFuture = ApiManager.fetchUnassignedRoomStudents();
      }
    });
  }

  // --- Counselor Logic ---
  Future<void> _claimStudent(int studentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim Student'),
        content: Text('Are you sure you want to assign yourself as the counselor for $studentName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Claim'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiManager.assignStudentToCounselor(studentId);
      if (ok) {
        _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student claimed successfully'), backgroundColor: Colors.green));
        }
      }
    }
  }

  // --- Warden Logic ---
  void _showRoomPicker(int studentId, String studentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RoomAssignmentSheet(
        studentId: studentId,
        studentName: studentName,
        onSuccess: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = UserSession.role;
    // roles that don't have an 'Unassigned' tab
    if (role != 'COUNSELOR' && role != 'WARDEN') {
      return _buildStudentList(_myStudentsFuture, isUnassigned: false);
    }

    final String unassignedLabel = role == 'COUNSELOR' ? 'Unassigned' : 'No Room';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            color: Colors.white,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.primaryColor,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondaryColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                const Tab(text: 'My Students'),
                Tab(text: unassignedLabel),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStudentList(_myStudentsFuture, isUnassigned: false),
                _buildStudentList(_unassignedStudentsFuture, isUnassigned: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(Future<List<dynamic>> future, {required bool isUnassigned}) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error fetching students", style: TextStyle(color: AppTheme.accentColor)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(isUnassigned);
          }

          final students = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                     BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))
                  ],
                ),
                child: ListTile(
                  onTap: isUnassigned ? null : () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => StudentDetailsView(studentId: student['student_id']),
                    )).then((_) => _refresh());
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                       (student['name'] ?? '?')[0].toUpperCase(),
                       style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Text(student['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text('Roll No: ${student['roll_no'] ?? 'N/A'}\nHostel: ${student['hostel_name'] ?? 'No room assigned'}'),
                  trailing: isUnassigned 
                    ? _buildUnassignedAction(student)
                    : const Icon(Icons.chevron_right, color: Colors.grey),
                  isThreeLine: true,
                ),
              ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.05);
            },
          );
        },
      ),
    );
  }

  Widget _buildUnassignedAction(dynamic student) {
    final role = UserSession.role;
    final String label = role == 'COUNSELOR' ? 'Claim' : 'Assign Room';

    return ElevatedButton(
      onPressed: () {
        if (role == 'COUNSELOR') {
          _claimStudent(student['student_id'], student['name'] ?? 'Student');
        } else if (role == 'WARDEN') {
          _showRoomPicker(student['student_id'], student['name'] ?? 'Student');
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildEmptyState(bool isUnassigned) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isUnassigned ? Icons.how_to_reg_outlined : Icons.group_off_outlined, 
            size: 72, 
            color: Colors.grey.shade200
          ),
          const SizedBox(height: 16),
          Text(
            isUnassigned ? (UserSession.role == 'WARDEN' ? 'All Students have Rooms' : 'No New Students to Claim') : 'No Students Assigned',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
          ),
          if (isUnassigned) Text(
            'New registrations will appear here.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade300),
          ),
        ],
      ).animate().fadeIn(),
    );
  }
}

// ─── ROOM ASSIGNMENT SHEET ───────────────────────────
class _RoomAssignmentSheet extends StatefulWidget {
  final int studentId;
  final String studentName;
  final VoidCallback onSuccess;

  const _RoomAssignmentSheet({
    required this.studentId,
    required this.studentName,
    required this.onSuccess,
  });

  @override
  State<_RoomAssignmentSheet> createState() => _RoomAssignmentSheetState();
}

class _RoomAssignmentSheetState extends State<_RoomAssignmentSheet> {
  late Future<List<dynamic>> _roomsFuture;
  int? _selectedRoomId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _roomsFuture = ApiManager.fetchWardenAvailableRooms();
  }

  Future<void> _submit() async {
    if (_selectedRoomId == null) return;
    setState(() => _submitting = true);

    final ok = await ApiManager.assignRoomToStudent(widget.studentId, _selectedRoomId!);
    
    setState(() => _submitting = false);
    if (mounted) {
      if (ok) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room assigned successfully'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to assign room')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 24),
          Text(
            'Assign Room to ${widget.studentName}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor),
          ),
          const SizedBox(height: 8),
          const Text('Select a room with available vacancy in your hostel.', style: TextStyle(color: AppTheme.textSecondaryColor)),
          const SizedBox(height: 24),
          
          Flexible(
            child: FutureBuilder<List<dynamic>>(
              future: _roomsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                }
                final rooms = snapshot.data ?? [];
                if (rooms.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No available rooms in your hostel.')),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final r = rooms[i];
                    final isFull = r['occupied'] >= r['capacity'];
                    final isSelected = _selectedRoomId == r['room_id'];
                    
                    return GestureDetector(
                      onTap: isFull ? null : () => setState(() => _selectedRoomId = r['room_id']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.08) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.meeting_room_outlined, color: isSelected ? AppTheme.primaryColor : Colors.grey),
                            const SizedBox(width: 16),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Room ${r['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('${r['occupied']} / ${r['capacity']} Occupied', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            )),
                            if (isSelected) const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_selectedRoomId == null || _submitting) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _submitting 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Confirm Assignment', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
