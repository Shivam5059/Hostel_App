import 'package:flutter/material.dart';
import '../../user_data.dart';
import '../base_dashboard.dart';
import '../../theme.dart';
import '../../api_calls.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardHomeView extends StatefulWidget {
  const DashboardHomeView({super.key});

  @override
  State<DashboardHomeView> createState() => _DashboardHomeViewState();
}

class _DashboardHomeViewState extends State<DashboardHomeView> {
  Map<String, dynamic>? _attendanceSummary;
  bool _isLoadingAttendance = false;

  @override
  void initState() {
    super.initState();
    if (UserSession.role == 'STUDENT') {
      _fetchAttendance();
    }
  }

  Future<void> _fetchAttendance() async {
    if (!mounted) return;
    setState(() => _isLoadingAttendance = true);
    final data = await ApiManager.getStudentAttendance();
    if (mounted && data != null) {
      setState(() {
        _attendanceSummary = data['attendance_summary'];
        _isLoadingAttendance = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingAttendance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final functions = UserSession.availableFunctions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The Breathtaking User Profile Card
          InkWell(
            onTap: () {
              final profileIndex = functions.indexWhere((f) => f.title.toLowerCase() == 'profile');
              if (profileIndex != -1) {
                context.findAncestorStateOfType<BaseDashboardState>()?.changePage(profileIndex + 1);
              }
            },
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF6366F1), Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      UserSession.name?.isNotEmpty == true ? UserSession.name![0].toUpperCase() : '?', 
                      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(
                          UserSession.name ?? 'Guest', 
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2), 
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Text(
                                UserSession.role ?? 'UNKNOWN', 
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)
                              ),
                            ),
                          ],
                        )
                      ]
                    )
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70),
                ]
              )
            )
          ).animate().fadeIn().slideY(begin: 0.1),

          if (UserSession.role == 'STUDENT') ...[
            const SizedBox(height: 48),
            _buildAttendanceSection(),
          ],

          const SizedBox(height: 48),
          
          Text(
            'Quick Navigation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 22),
          ).animate().fadeIn(delay: 200.ms),
          Text(
            'Access all your features easily',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),

          // The Tiles Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.0,
            ),
            itemCount: functions.length,
            itemBuilder: (context, index) {
              final func = functions[index];
              return InkWell(
                onTap: () {
                   context.findAncestorStateOfType<BaseDashboardState>()?.changePage(index + 1);
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                       BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                    border: Border.all(color: Colors.grey.shade100, width: 1.5)
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                         padding: const EdgeInsets.all(18),
                         decoration: BoxDecoration(
                           color: AppTheme.primaryColor.withValues(alpha: 0.08),
                           shape: BoxShape.circle,
                         ),
                         child: Icon(func.icon, size: 36, color: AppTheme.primaryColor),
                       ),
                      const SizedBox(height: 20),
                      Text(
                        func.title, 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)
                      ),
                    ]
                  )
                )
              ).animate().fadeIn(delay: (400 + (index * 50)).ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
            }
          )
        ]
      )
    );
  }

  Widget _buildAttendanceSection() {
    if (_isLoadingAttendance) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())).animate().fadeIn();
    }

    if (_attendanceSummary == null) return const SizedBox.shrink();

    final percentage = _attendanceSummary!['attendance_percentage'] ?? 0;
    final total = _attendanceSummary!['total_classes'] ?? 0;
    final present = _attendanceSummary!['present_count'] ?? 0;
    final absent = _attendanceSummary!['absent_count'] ?? 0;
    final color = percentage >= 75 ? Colors.greenAccent : Colors.orangeAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 20.0),
          child: Text(
            'Attendance Consistency',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, 
              color: AppTheme.textPrimaryColor.withValues(alpha: 0.9)
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // Extravagant "Ultra-Elevated" Circular Progress Hub
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    // Layer 1: The Massive Color Glow (Low Opacity, Huge Blur)
                    BoxShadow(
                      color: color.withValues(alpha: 0.3), 
                      blurRadius: 40, 
                      offset: const Offset(0, 20),
                      spreadRadius: 8,
                    ),
                    // Layer 2: The Core Object Shadow (Higher Opacity, Medium Blur)
                    BoxShadow(
                      color: color.withValues(alpha: 0.2), 
                      blurRadius: 20, 
                      offset: const Offset(0, 10),
                      spreadRadius: 2,
                    ),
                    // Layer 3: Realistic Contact Depth (Darker, Sharper)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    // Layer 4: Anti-Gravity Highlight (Top-Left Light Shadow)
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 5,
                      offset: Offset(-4, -4),
                    )
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88, // Refined size
                      height: 88,
                      child: CircularProgressIndicator(
                        value: percentage / 100,
                        strokeWidth: 9, // Slightly thicker for more presence
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimaryColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
              
              const SizedBox(width: 32),
              
              // Clean Statistics Strip
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCleanStat('Total', total.toString(), AppTheme.primaryColor),
                    _buildCleanStat('Present', present.toString(), Colors.green),
                    _buildCleanStat('Absent', absent.toString(), Colors.redAccent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildCleanStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryColor),
        ),
        const SizedBox(height: 2),
        Container(
          height: 3,
          width: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 9, color: AppTheme.textSecondaryColor, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ],
    );
  }
}
