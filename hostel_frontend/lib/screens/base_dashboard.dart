import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../user_data.dart';
import 'auth/login_screen.dart';
import 'features/dashboard_home_view.dart';
import '../../theme.dart';

class BaseDashboard extends StatefulWidget {
  const BaseDashboard({super.key});

  @override
  State<BaseDashboard> createState() => BaseDashboardState();
}

class BaseDashboardState extends State<BaseDashboard> {
  late Widget _currentPage;
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<RoleFunction> get _functions => UserSession.availableFunctions;

  @override
  void initState() {
    super.initState();
    _currentPage = const DashboardHomeView();
  }

  void _onMenuSelected(int index) {
    if (index < 0 || index > _functions.length) return;
    setState(() {
      _selectedIndex = index;
      _currentPage = index == 0
          ? const DashboardHomeView()
          : _functions[index - 1].page;
    });
  }

  void changePage(int index) {
    _onMenuSelected(index);
  }

  void _logout() {
    UserSession.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme
          .primaryColor, // Deep indigo base for the premium side-over feel
      drawer: isSmallScreen
          ? Drawer(
              backgroundColor: AppTheme.primaryColor,
              child: _buildSidebarContent(context, isSmallScreen: true),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (!isSmallScreen)
              SizedBox(
                width: 280,
                child: _buildSidebarContent(context, isSmallScreen: false),
              ),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(
                  top: isSmallScreen ? 0 : 12.0,
                  bottom: isSmallScreen ? 0 : 12.0,
                  right: isSmallScreen ? 0 : 12.0,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: isSmallScreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(-5, 0),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: isSmallScreen
                      ? BorderRadius.zero
                      : BorderRadius.circular(32),
                  child: Column(
                    children: [
                      // Our breathtaking custom header blending into the app
                      _buildCustomHeader(isSmallScreen),

                      // The main content area swapped without pushing
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.05),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                          child: KeyedSubtree(
                            key: ValueKey<int>(_selectedIndex),
                            child: _currentPage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(bool isSmallScreen) {
    String formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isSmallScreen) ...[
                IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: AppTheme.textPrimaryColor,
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedIndex == 0
                        ? 'Overview'
                        : _functions[_selectedIndex - 1].title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentColor.withValues(alpha: 0.1),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppTheme.accentColor,
                      ),
                      onPressed: _logout,
                      tooltip: 'Logout',
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context, {
    required bool isSmallScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: isSmallScreen ? 48.0 : 32.0,
            left: 24,
            right: 24,
            bottom: 32,
          ),
          child: Row(
            children: [
              Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(curve: Curves.easeOutBack),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Hostel Hub",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
            ],
          ),
        ),

        // Navigation Options
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _functions.length + 1,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedIndex;
              final icon = index == 0
                  ? Icons.dashboard_rounded
                  : _functions[index - 1].icon;
              final title = index == 0
                  ? 'Overview'
                  : _functions[index - 1].title;
              return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (isSmallScreen &&
                              Scaffold.of(context).isDrawerOpen) {
                            Navigator.pop(context);
                          }
                          _onMenuSelected(index);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  )
                                : Border.all(
                                    color: Colors.transparent,
                                    width: 1,
                                  ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.6),
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.6),
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ).animate().scale(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (200 + (index * 50)).ms)
                  .slideX(begin: -0.05);
            },
          ),
        ),

        // Beautiful User Summary Profile Card at bottom (Fills empty space beautifully)
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      (UserSession.name?.isNotEmpty == true
                              ? UserSession.name![0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          UserSession.name ?? 'Guest User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            UserSession.role ?? 'UNKNOWN',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (UserSession.role == 'STUDENT' &&
                  UserSession.rollNo != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Roll No: ${UserSession.rollNo}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
      ],
    );
  }
}
