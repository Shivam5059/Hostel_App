import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/base_dashboard.dart';
import 'user_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserSession.initFromStorage();
  runApp(const HostelApp());
}

class HostelApp extends StatelessWidget {
  const HostelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hostel Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: UserSession.userId != null 
          ? const BaseDashboard() 
          : const LoginScreen(),
    );
  }
}
