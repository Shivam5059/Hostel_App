import 'package:flutter/material.dart';
import 'screens/features/students_view.dart';
import 'screens/features/leaves_view.dart';
import 'screens/features/attendance_view.dart';
import 'screens/features/complaints_view.dart';
import 'screens/features/room_transfer_view.dart';
import 'screens/features/profile_view.dart';
import 'screens/features/menu_view.dart';
import 'screens/features/menu_edit_view.dart';
import 'screens/features/new_admissions_view.dart';

class RoleFunction {
  final String title;
  final IconData icon;
  final Widget page;

  RoleFunction({
    required this.title,
    required this.icon,
    required this.page,
  });
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

  static void login({
    required int loginUserId,
    required String loginName,
    required String loginRole,
    int? loginStudentId,
    String? loginRollNo,
    String? loginEmail,
    String? loginPhone,
  }) {
    userId = loginUserId;
    name = loginName;
    role = loginRole;
    studentId = loginStudentId;
    rollNo = loginRollNo;
    email = loginEmail;
    phone = loginPhone;
  }

  static void updateFromMap(Map<String, dynamic> data) {
    userId = data['user_id'] as int?;
    name = data['name'] as String?;
    email = data['email'] as String?;
    phone = data['phone'] as String?;
    role = data['role'] as String?;
    rollNo = data['roll_no'] as String?;
    studentId = data['student_id'] as int?;
    roomNumber = data['room_number']?.toString();
    hostelName = data['hostel_name'] as String?;
  }

  static void logout() {
    userId = null;
    studentId = null;
    rollNo = null;
    name = null;
    email = null;
    phone = null;
    role = null;
    roomNumber = null;
    hostelName = null;
  }

  // Define static mappings for each role explicitly without 'Overview'
  static List<RoleFunction> get availableFunctions {
    switch (role) {
      case 'STUDENT':
        return [
          RoleFunction(title: 'Peers', icon: Icons.group_outlined, page: const StudentsView()),
          RoleFunction(title: 'Leaves', icon: Icons.event_busy_outlined, page: const LeavesView()),
          RoleFunction(title: 'Complaints', icon: Icons.report_problem_outlined, page: const ComplaintsView()),
          RoleFunction(title: 'Room Transfer', icon: Icons.swap_horiz_outlined, page: const RoomTransferView()),
          RoleFunction(title: 'Food Menu', icon: Icons.restaurant_menu_outlined, page: const MenuView()),
          RoleFunction(title: 'Profile', icon: Icons.person_outline, page: const ProfileView()),
        ];
      case 'PARENT':
        return [
          RoleFunction(title: 'Attendance', icon: Icons.assignment_turned_in_outlined, page: const AttendanceView()),
          RoleFunction(title: 'Leaves', icon: Icons.event_busy_outlined, page: const LeavesView()),
          RoleFunction(title: 'Food Menu', icon: Icons.restaurant_menu_outlined, page: const MenuView()),
          RoleFunction(title: 'Profile', icon: Icons.person_outline, page: const ProfileView()),
        ];
      case 'WARDEN':
        return [
          RoleFunction(title: 'Students', icon: Icons.group_outlined, page: const StudentsView()),
          RoleFunction(title: 'Attendance', icon: Icons.assignment_turned_in_outlined, page: const AttendanceView()),
          RoleFunction(title: 'Leaves', icon: Icons.event_busy_outlined, page: const LeavesView()),
          RoleFunction(title: 'Room Transfer', icon: Icons.swap_horiz_outlined, page: const RoomTransferView()),
          RoleFunction(title: 'Food Menu', icon: Icons.restaurant_menu_outlined, page: const MenuView()),
          RoleFunction(title: 'Profile', icon: Icons.person_outline, page: const ProfileView()),
        ];
      case 'COUNSELOR':
        return [
          RoleFunction(title: 'Students', icon: Icons.group_outlined, page: const StudentsView()),
          RoleFunction(title: 'Leaves', icon: Icons.event_busy_outlined, page: const LeavesView()),
          RoleFunction(title: 'Food Menu', icon: Icons.restaurant_menu_outlined, page: const MenuView()),
          RoleFunction(title: 'Profile', icon: Icons.person_outline, page: const ProfileView()),
        ];
      case 'RECTOR':
        return [
          RoleFunction(title: 'Students', icon: Icons.group_outlined, page: const StudentsView()),
          RoleFunction(title: 'New Students', icon: Icons.person_search_outlined, page: const NewStudentsView()),
          RoleFunction(title: 'New Admission', icon: Icons.how_to_reg_outlined, page: const NewAdmissionView()),
          RoleFunction(title: 'Attendance', icon: Icons.assignment_turned_in_outlined, page: const AttendanceView()),
          RoleFunction(title: 'Leaves', icon: Icons.event_busy_outlined, page: const LeavesView()),
          RoleFunction(title: 'Complaints', icon: Icons.report_problem_outlined, page: const ComplaintsView()),
          RoleFunction(title: 'Food Menu', icon: Icons.restaurant_menu_outlined, page: const MenuView()),
          RoleFunction(title: 'Edit Menu', icon: Icons.edit_calendar_outlined, page: const MenuEditView()),
          RoleFunction(title: 'Profile', icon: Icons.person_outline, page: const ProfileView()),
        ];
      default:
        return [];
    }
  }
}
