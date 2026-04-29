import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/features/students_view.dart';
import 'screens/features/leaves_view.dart';
import 'screens/features/attendance_view.dart';
import 'screens/features/complaints_view.dart';
import 'screens/features/room_transfer_view.dart';
import 'screens/features/profile_view.dart';
import 'screens/features/menu_view.dart';
import 'screens/features/menu_edit_view.dart';
import 'screens/features/new_admissions_view.dart';
import 'screens/features/face_registration_view.dart';
import 'admin/staff_management_view.dart';
import 'admin/hostel_management_view.dart';
import 'admin/notice_management_view.dart';
import 'admin/admin_stats_view.dart';
import 'screens/features/late_students_view.dart';

class RoleFunction {
  final String title;
  final IconData icon;
  final Widget page;

  RoleFunction({required this.title, required this.icon, required this.page});
}

class UserSession {
  // Global user properties stored in memory
  static int? userId;
  static int? studentId; // For STUDENT role exact db PK
  static String? rollNo; // For STUDENT roll no lookup
  static String? name;
  static String? email;
  static String? role; // e.g. "STUDENT", "PARENT", "WARDEN", "COUNSELOR", "RECTOR"
  static String? phone;
  static String? roomNumber;
  static String? hostelName;

  static Future<void> login({
    required int loginUserId,
    required String loginName,
    required String loginRole,
    int? loginStudentId,
    String? loginRollNo,
    String? loginEmail,
    String? loginPhone,
  }) async {
    userId = loginUserId;
    name = loginName;
    role = loginRole;
    studentId = loginStudentId;
    rollNo = loginRollNo;
    email = loginEmail;
    phone = loginPhone;
    await saveSession();
  }

  static Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();

    Future<void> sync(String key, dynamic value) async {
      if (value == null) {
        await prefs.remove(key);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    }

    await sync('user_id', userId);
    await sync('student_id', studentId);
    await sync('roll_no', rollNo);
    await sync('name', name);
    await sync('email', email);
    await sync('role', role);
    await sync('phone', phone);
    await sync('room_number', roomNumber);
    await sync('hostel_name', hostelName);
  }

  static Future<void> initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id');
    studentId = prefs.getInt('student_id');
    rollNo = prefs.getString('roll_no');
    name = prefs.getString('name');
    email = prefs.getString('email');
    role = prefs.getString('role');
    phone = prefs.getString('phone');
    roomNumber = prefs.getString('room_number');
    hostelName = prefs.getString('hostel_name');
  }

  static Future<void> updateFromMap(Map<String, dynamic> data) async {
    userId = data['user_id'] as int?;
    name = data['name'] as String?;
    email = data['email'] as String?;
    phone = data['phone'] as String?;
    role = data['role'] as String?;
    rollNo = data['roll_no'] as String?;
    studentId = data['student_id'] as int?;
    roomNumber = data['room_number']?.toString();
    hostelName = data['hostel_name'] as String?;
    await saveSession();
  }

  static Future<void> logout() async {
    userId = null;
    studentId = null;
    rollNo = null;
    name = null;
    email = null;
    phone = null;
    role = null;
    roomNumber = null;
    hostelName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Define static mappings for each role explicitly without 'Overview'
  static List<RoleFunction> get availableFunctions {
    switch (role) {
      case 'STUDENT':
        return [
          RoleFunction(
            title: 'Leaves',
            icon: Icons.event_busy_outlined,
            page: const LeavesView(),
          ),
          RoleFunction(
            title: 'Complaints',
            icon: Icons.report_problem_outlined,
            page: const ComplaintsView(),
          ),
          RoleFunction(
            title: 'Room Transfer',
            icon: Icons.swap_horiz_outlined,
            page: const RoomTransferView(),
          ),
          RoleFunction(
            title: 'Food Menu',
            icon: Icons.restaurant_menu_outlined,
            page: const MenuView(),
          ),
          RoleFunction(
            title: 'Face Registration',
            icon: Icons.face_retouching_natural,
            page: const FaceRegistrationView(),
          ),
          RoleFunction(
            title: 'Profile',
            icon: Icons.person_outline,
            page: const ProfileView(),
          ),
        ];
      case 'PARENT':
        return [
          RoleFunction(
            title: 'Students',
            icon: Icons.group_outlined,
            page: const StudentsView(),
          ),
          RoleFunction(
            title: 'Leaves',
            icon: Icons.event_busy_outlined,
            page: const LeavesView(),
          ),
          RoleFunction(
            title: 'Food Menu',
            icon: Icons.restaurant_menu_outlined,
            page: const MenuView(),
          ),
          RoleFunction(
            title: 'Profile',
            icon: Icons.person_outline,
            page: const ProfileView(),
          ),
        ];
      case 'WARDEN':
        return [
          RoleFunction(
            title: 'Students',
            icon: Icons.group_outlined,
            page: const StudentsView(),
          ),
          RoleFunction(
            title: 'Attendance',
            icon: Icons.assignment_turned_in_outlined,
            page: const AttendanceView(),
          ),
          RoleFunction(
            title: 'Leaves',
            icon: Icons.event_busy_outlined,
            page: const LeavesView(),
          ),
          RoleFunction(
            title: 'Room Transfer',
            icon: Icons.swap_horiz_outlined,
            page: const RoomTransferView(),
          ),
          RoleFunction(
            title: 'Late Students',
            icon: Icons.access_time_outlined,
            page: const LateStudentsView(),
          ),
          RoleFunction(
            title: 'Food Menu',
            icon: Icons.restaurant_menu_outlined,
            page: const MenuView(),
          ),
          RoleFunction(
            title: 'Profile',
            icon: Icons.person_outline,
            page: const ProfileView(),
          ),
        ];
      case 'COUNSELOR':
        return [
          RoleFunction(
            title: 'Students',
            icon: Icons.group_outlined,
            page: const StudentsView(),
          ),
          RoleFunction(
            title: 'Leaves',
            icon: Icons.event_busy_outlined,
            page: const LeavesView(),
          ),
          RoleFunction(
            title: 'Food Menu',
            icon: Icons.restaurant_menu_outlined,
            page: const MenuView(),
          ),
          RoleFunction(
            title: 'Profile',
            icon: Icons.person_outline,
            page: const ProfileView(),
          ),
        ];

      case 'RECTOR':
        return [
          RoleFunction(
            title: 'Students',
            icon: Icons.group_outlined,
            page: const StudentsView(),
          ),
          RoleFunction(
            title: 'New Students',
            icon: Icons.person_search_outlined,
            page: const NewStudentsView(),
          ),
          RoleFunction(
            title: 'New Admission',
            icon: Icons.how_to_reg_outlined,
            page: const NewAdmissionView(),
          ),
          RoleFunction(
            title: 'Leaves',
            icon: Icons.event_busy_outlined,
            page: const LeavesView(),
          ),
          RoleFunction(
            title: 'Complaints',
            icon: Icons.report_problem_outlined,
            page: const ComplaintsView(),
          ),
          RoleFunction(
            title: 'Late Students',
            icon: Icons.access_time_outlined,
            page: const LateStudentsView(),
          ),
          RoleFunction(
            title: 'Food Menu',
            icon: Icons.restaurant_menu_outlined,
            page: const MenuView(),
          ),
          RoleFunction(
            title: 'Edit Menu',
            icon: Icons.edit_calendar_outlined,
            page: const MenuEditView(),
          ),
          RoleFunction(
            title: 'Profile',
            icon: Icons.person_outline,
            page: const ProfileView(),
          ),
        ];

      case 'ADMIN':
        return [
          RoleFunction(
            title: 'Dashboard',
            icon: Icons.dashboard_outlined,
            page: const AdminStatsView(),
          ),
          RoleFunction(
            title: 'Staff Management',
            icon: Icons.admin_panel_settings_outlined,
            page: const StaffManagementView(),
          ),
          RoleFunction(
            title: 'Hostels',
            icon: Icons.domain_outlined,
            page: const HostelManagementView(),
          ),
          RoleFunction(
            title: 'Notice Board',
            icon: Icons.announcement_outlined,
            page: const NoticeManagementView(),
          ),
          RoleFunction(
            title: 'Students',
            icon: Icons.group_outlined,
            page: const StudentsView(),
          ),
          RoleFunction(
            title: 'Attendance',
            icon: Icons.assignment_turned_in_outlined,
            page: const AttendanceView(),
          ),
          RoleFunction(
            title: 'Leaves',
            icon: Icons.event_busy_outlined,
            page: const LeavesView(),
          ),
          RoleFunction(
            title: 'Complaints',
            icon: Icons.report_problem_outlined,
            page: const ComplaintsView(),
          ),
          RoleFunction(
            title: 'Profile',
            icon: Icons.person_outline,
            page: const ProfileView(),
          ),
        ];
      default:
        return [];
    }
  }
}
