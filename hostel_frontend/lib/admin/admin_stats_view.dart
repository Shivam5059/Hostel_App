import 'package:flutter/material.dart';
import '../../api_calls.dart';
import '../../theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'csv_helper.dart';

class AdminStatsView extends StatefulWidget {
  const AdminStatsView({super.key});

  @override
  State<AdminStatsView> createState() => _AdminStatsViewState();
}

class _AdminStatsViewState extends State<AdminStatsView> {
  late Future<Map<String, dynamic>?> _statsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _statsFuture = ApiManager.fetchAdminStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('System Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Summary',
            onPressed: () async {
              final stats = await ApiManager.fetchAdminStats();
              if (stats != null) {
                final totals = stats['totals'];
                String csv = "Metric,Value\n";
                csv += "Total Students,${totals['students']}\n";
                csv += "Active Staff,${totals['staff']}\n";
                csv += "Total Hostels,${totals['hostels']}\n";
                csv += "Capacity,${totals['capacity']}\n";
                csv += "Occupied,${totals['occupied']}\n";
                csv += "Available,${totals['available']}\n";
                csv += "Pending Complaints,${totals['pending_complaints']}\n";
                
                if (mounted) CsvExportHelper.showExportDialog(context, 'Summary', csv);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text("Error fetching analytics"));
            }

            final stats = snapshot.data!;
            final totals = stats['totals'];
            final hostels = stats['hostels'] as List<dynamic>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Insights', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor)),
                  Text('Real-time overview of your hostel ecosystem', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
                  const SizedBox(height: 32),

                  // Top Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.3,
                        children: [
                          _buildStatCard('Total Students', totals['students'].toString(), Icons.group_outlined, AppTheme.primaryColor),
                          _buildStatCard('Active Staff', totals['staff'].toString(), Icons.badge_outlined, Colors.blue),
                          _buildStatCard('Hostels', totals['hostels'].toString(), Icons.domain_outlined, Colors.orange),
                          _buildStatCard('Pending Complaints', totals['pending_complaints'].toString(), Icons.report_problem_outlined, AppTheme.accentColor),
                        ],
                      );
                    }
                  ),

                  const SizedBox(height: 40),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isNarrow = constraints.maxWidth < 700;
                      
                      if (isNarrow) {
                        return Column(
                          children: [
                            _buildOccupancySection(totals),
                            const SizedBox(height: 32),
                            _buildHostelBreakdown(hostels),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildOccupancySection(totals),
                          ),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 3,
                            child: _buildHostelBreakdown(hostels),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildOccupancySection(Map<String, dynamic> totals) {
    final double occupied = (totals['occupied'] as num).toDouble();
    final double capacity = (totals['capacity'] as num).toDouble();
    final double percentage = capacity > 0 ? (occupied / capacity) : 0;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text('Overall Occupancy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 20,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(percentage > 0.9 ? AppTheme.accentColor : AppTheme.primaryColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                children: [
                  Text('${(percentage * 100).toInt()}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text('Occupied', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildLegendItem('Occupied', totals['occupied'].toString(), AppTheme.primaryColor),
          const SizedBox(height: 12),
          _buildLegendItem('Available', totals['available'].toString(), Colors.green),
          const SizedBox(height: 12),
          _buildLegendItem('Total Capacity', totals['capacity'].toString(), Colors.grey.shade400),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label, 
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildHostelBreakdown(List<dynamic> hostels) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hostel Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 24),
          ...hostels.map((h) {
            final double cap = (h['capacity'] as num?)?.toDouble() ?? 0;
            final double students = (h['student_count'] as num?)?.toDouble() ?? 0;
            final double progress = cap > 0 ? (students / cap) : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          h['hostel_name'], 
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$students / ${cap.toInt()}', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(progress > 0.9 ? AppTheme.accentColor : AppTheme.secondaryColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}
