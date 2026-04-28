import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import '../../user_data.dart';

class LateStudentsView extends StatefulWidget {
  const LateStudentsView({super.key});

  @override
  State<LateStudentsView> createState() => _LateStudentsViewState();
}

class _LateStudentsViewState extends State<LateStudentsView> {
  DateTime _selectedDate = DateTime.now();
  late Future<List<dynamic>> _lateStudentsFuture;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    setState(() {
      String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      _lateStudentsFuture = ApiManager.fetchLateStudents(dateStr);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<List<dynamic>>(
        future: _lateStudentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppTheme.accentColor),
                  const SizedBox(height: 16),
                  const Text('Failed to load late students',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _fetchData, child: const Text('Retry'))
                ],
              ),
            );
          }

          final students = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () async => _fetchData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              itemCount: students.isEmpty ? 2 : students.length + 1,
              itemBuilder: (context, index) {
                // Header with Date Picker
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, Color(0xFF6366F1)]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Late Returns on',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Material(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() {
                                    _selectedDate = date;
                                  });
                                  _fetchData();
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Icon(Icons.calendar_month_outlined,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: -0.1),
                  );
                }

                if (students.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60.0),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 80, color: Colors.green.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No late students!',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Everyone returned before curfew.',
                            style: TextStyle(color: AppTheme.textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn();
                }

                final s = students[index - 1];
                final exitTimeStr = s['exit_time'] ?? '';
                String formattedExitTime = exitTimeStr;
                try {
                  if (exitTimeStr.isNotEmpty) {
                    final dt = DateTime.parse(exitTimeStr);
                    formattedExitTime = DateFormat('hh:mm a').format(dt);
                  }
                } catch (_) {}

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_off_outlined,
                              color: Colors.redAccent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.meeting_room_outlined,
                                      size: 14,
                                      color: AppTheme.textSecondaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Room ${s['room_number'] ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  if (UserSession.role == 'RECTOR' &&
                                      s['hostel_name'] != null) ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.apartment_outlined,
                                        size: 14,
                                        color: AppTheme.textSecondaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      s['hostel_name'],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.logout,
                                      size: 12, color: Colors.orange),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedExitTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (s['phone'] != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone,
                                      size: 14,
                                      color: AppTheme.textSecondaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    s['phone'],
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondaryColor),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: (30 * index).ms).slideX(begin: 0.05);
              },
            ),
          );
        },
      ),
    );
  }
}
