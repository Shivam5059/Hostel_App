import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'user_data.dart';

class ApiManager {
  static const String baseUrl = 'http://localhost:3000/api';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  // --- Auth Flow with Profile Fetching ---

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        int userId = data['user']['user_id'];
        String role = data['user']['role'];
        int? studentId;
        String? rollNo;

        // CRITICAL FIX: Use the specific user-to-student detail endpoint to prevent ID collisions
        if (role == 'STUDENT') {
          final detailRes = await http.get(
            Uri.parse('$baseUrl/student/user/$userId/details'),
          );
          if (detailRes.statusCode == 200) {
            final details = jsonDecode(detailRes.body);
            studentId = details['student_id'];
            rollNo = details['roll_no'];
            // Also store these in UserSession right away
            UserSession.roomNumber = details['room_number']?.toString();
            UserSession.hostelName = details['hostel_name'];
          }
        }

        await UserSession.login(
          loginUserId: userId,
          loginName: data['user']['name'],
          loginRole: role,
          loginStudentId: studentId,
          loginRollNo: rollNo,
          loginEmail: email,
          loginPhone: data['user']['phone'],
        );

        return {'success': true, 'data': data};
      } else {
        final desc = jsonDecode(response.body)['message'] ?? 'Login Failed';
        return {'success': false, 'message': desc};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // --- Forgot Password Flow ---

  static Future<(bool, String?)> sendForgotPasswordOtp(
    String email,
    String otp,
  ) async {
    return _postWithMessage('/auth/forgot-password/send', {
      'email': email,
      'otp': otp,
    });
  }

  static Future<(bool, String?)> resetPassword(
    String email,
    String newPassword,
  ) async {
    return _postWithMessage('/auth/forgot-password/reset', {
      'email': email,
      'new_password': newPassword,
    });
  }

  // --- Generic Helpers for code reduction ---

  static Future<List<dynamic>> _getList(String endpoint) async {
    if (UserSession.userId == null) return [];
    try {
      final res = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return [];
  }

  static Future<bool> _postStatus(
    String endpoint,
    Map<String, dynamic>? body,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> _deleteStatus(String endpoint) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // Returns (success, errorMessage) — null on success
  static Future<(bool, String?)> _postWithMessage(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return (true, null);
      final msg =
          (jsonDecode(res.body) as Map)['message'] as String? ??
          'Unknown error';
      return (false, msg);
    } catch (_) {
      return (false, 'Network error');
    }
  }

  static Future<(bool, String?)> _putWithMessage(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200 || res.statusCode == 201) return (true, null);
      final msg =
          (jsonDecode(res.body) as Map)['message'] as String? ??
          'Unknown error';
      return (false, msg);
    } catch (_) {
      return (false, 'Network error');
    }
  }

  // --- Students List Configuration ---
  static Future<List<dynamic>> fetchAssignedStudents() async {
    final role = UserSession.role?.toLowerCase() ?? '';
    // Maps perfectly to both Counselor and Warden endpoints since patterns match!
    if (role == 'counselor' || role == 'warden' || role == 'parent') {
      return _getList('/$role/${UserSession.userId}/students');
    }
    return [];
  }

  static Future<List<dynamic>> fetchAllStudents() async {
    return _getList('/rector/students');
  }

  static Future<Map<String, dynamic>?> fetchStudentDetails(
    int studentId,
  ) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/student/$studentId/details'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // --- Unified Leaves Extractor ---
  static Future<List<dynamic>> fetchLeaves({bool history = false}) async {
    // Dynamic endpoint construction replacing 8 redundant functions
    final String role = UserSession.role ?? '';
    final String suffix = history ? '/history' : '';

    if (role == 'STUDENT') {
      return _getList(
        '/student/leave/${UserSession.studentId}',
      ); // Notice the use of static studentId!
    } else if (role == 'PARENT') {
      return _getList('/parent/leaves$suffix?parentId=${UserSession.userId}');
    } else if (role == 'COUNSELOR') {
      return _getList(
        '/counselor/leaves$suffix?counselorId=${UserSession.userId}',
      );
    } else if (role == 'WARDEN') {
      return _getList('/warden/leaves$suffix?wardenId=${UserSession.userId}');
    } else if (role == 'ADMIN') {
      return _getList('/admin/leaves$suffix');
    }
    return [];
  }

  static Future<bool> submitLeaveRequest(
    String fromDate,
    String toDate,
    String reason,
  ) async {
    if (UserSession.studentId == null) return false;
    return _postStatus('/student/leave', {
      'student_id':
          UserSession.studentId, // Exactly matches backend requirement
      'from_date': fromDate,
      'to_date': toDate,
      'reason': reason,
    });
  }

  static Future<bool> processLeaveAction(int leaveId, bool approve) async {
    final String role = UserSession.role?.toLowerCase() ?? '';
    final String action = approve ? 'approve' : 'reject';
    // Perfectly maps to: /api/parent/leave/:id/approve, /api/counselor/leave/:id/approve, etc.
    return _postStatus('/$role/leave/$leaveId/$action', null);
  }

  // --- Complaints ---

  // Rector: fetch all complaints (optional status filter: 'PENDING', 'RESOLVED', 'REJECTED')
  static Future<List<dynamic>> fetchAllComplaints({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    return _getList('/complaints$query');
  }

  // Student: fetch their own complaint history
  static Future<List<dynamic>> fetchStudentComplaints() async {
    if (UserSession.studentId == null) return [];
    return _getList('/student/${UserSession.studentId}/complaints');
  }

  // Student: submit a new complaint
  static Future<bool> submitComplaint(String description) async {
    if (UserSession.studentId == null) return false;
    return _postStatus('/complaints', {
      'student_id': UserSession.studentId,
      'description': description,
    });
  }

  // Rector: resolve or reject a complaint (records rector_id + end_date)
  static Future<bool> updateComplaintStatus(
    int complaintId,
    String status,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/complaints/$complaintId/status'),
        headers: _headers,
        body: jsonEncode({'status': status, 'rector_id': UserSession.userId}),
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // --- Attendance ---
  static Future<Map<String, dynamic>?> getStudentAttendance() async {
    try {
      final res = await http.get(
        Uri.parse(
          '$baseUrl/student/${UserSession.studentId ?? UserSession.userId}/attendance',
        ),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  static Future<bool> submitAttendance(
    String date,
    List<Map<String, dynamic>> records,
  ) async {
    return _postStatus('/warden/attendance/submit', {
      'warden_id': UserSession.userId,
      'attendance_date': date,
      'attendanceRecords': records,
    });
  }

  static Future<List<dynamic>> fetchAttendanceForDate(String date) async {
    return _getList('/warden/${UserSession.userId}/attendance/$date');
  }

  static Future<List<dynamic>> fetchWardenAttendanceHistory() async {
    if (UserSession.role == 'ADMIN') {
      return _getList('/admin/attendance-history');
    }
    return _getList('/warden/${UserSession.userId}/attendance-history');
  }

  static Future<List<dynamic>> fetchDetailedAttendanceHistory() async {
    if (UserSession.role == 'ADMIN') {
      return _getList('/admin/attendance-history/detailed');
    }
    return _getList('/warden/${UserSession.userId}/attendance-history/detailed');
  }

  // --- Late Students ---
  static Future<List<dynamic>> fetchLateStudents(String date) async {
    if (UserSession.role == 'RECTOR') {
      return _getList('/rector/late-students?date=$date');
    } else if (UserSession.role == 'WARDEN') {
      return _getList('/warden/${UserSession.userId}/late-students?date=$date');
    }
    return [];
  }

  // --- Room Transfers ---
  static Future<List<dynamic>> fetchRoomTransfers() async {
    return _getList('/warden/${UserSession.userId}/room-transfers');
  }

  static Future<bool> updateRoomTransferStatus(
    int requestId,
    String status,
  ) async {
    return _postStatus('/room-transfer/$requestId/status', {'status': status});
  }

  static Future<List<dynamic>> fetchAvailableRooms() async {
    return _getList('/rooms/available');
  }

  static Future<bool> submitRoomTransferRequest(
    int requestedRoomId,
    String reason,
  ) async {
    if (UserSession.studentId == null) return false;
    return _postStatus('/student/room-transfer', {
      'student_id': UserSession.studentId,
      'requested_room_id': requestedRoomId,
      'reason': reason,
    });
  }

  static Future<List<dynamic>> fetchStudentRoomTransfers() async {
    if (UserSession.studentId == null) return [];
    return _getList('/student/${UserSession.studentId}/room-transfers');
  }

  // --- Food Menu ---

  // Fetch today's menu (all roles view)
  static Future<Map<String, dynamic>?> fetchTodaysMenu() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/menu/today'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // Fetch menu for a specific day (Rector editing)
  static Future<Map<String, dynamic>?> fetchMenuForDay(String day) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/menu/$day'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  // Fetch entire food item catalog (Rector: populates edit dropdowns)
  static Future<List<dynamic>> fetchFoodItemsCatalog() async {
    return _getList('/menu/items/all');
  }

  // Rector: replace all items in a meal slot for a given day
  static Future<bool> updateMealSlot(
    String day,
    String meal,
    List<int> itemIds,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/menu/$day/$meal'),
        headers: _headers,
        body: jsonEncode({'item_ids': itemIds}),
      );
      return res.statusCode == 200;
    } catch (_) {}
    return false;
  }
  // ─── Rector: Admissions ──────────────────────────────────

  /// Register a student — rector only needs email, roll_no, phone.
  /// Temp password is auto-set to roll_no on the backend.
  /// Returns (success, errorMessage, responseData).
  static Future<(bool, String?, Map<String, dynamic>?)> registerNewStudent({
    required String email,
    required String rollNo,
    String? phone,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/rector/student'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'roll_no': rollNo,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }),
      );
      if (res.statusCode == 201) {
        return (true, null, jsonDecode(res.body) as Map<String, dynamic>);
      }
      final msg =
          (jsonDecode(res.body) as Map)['message'] as String? ??
          'Unknown error';
      return (false, msg, null);
    } catch (_) {
      return (false, 'Network error', null);
    }
  }

  /// Students with no parent assigned yet.
  static Future<List<dynamic>> fetchNewStudents() =>
      _getList('/rector/students/new');

  /// All registered parent users (for linking sheet).
  static Future<List<dynamic>> fetchExistingParents() =>
      _getList('/rector/parents');

  /// All counselors (for assignment dropdown).
  static Future<List<dynamic>> fetchCounselors() =>
      _getList('/rector/counselors');

  /// Link an EXISTING parent account to a student.
  static Future<(bool, String?)> linkExistingParent({
    required int studentId,
    required int parentUserId,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/rector/student/$studentId/parent'),
        headers: _headers,
        body: jsonEncode({'parent_user_id': parentUserId}),
      );
      if (res.statusCode == 200) return (true, null);
      final msg =
          (jsonDecode(res.body) as Map)['message'] as String? ??
          'Unknown error';
      return (false, msg);
    } catch (_) {
      return (false, 'Network error');
    }
  }

  /// Create a new parent and link them to a student.
  static Future<(bool, String?)> registerAndLinkParent({
    required int studentId,
    required String name,
    required String email,
    required String phone,
    required String password,
  }) => _postWithMessage('/rector/student/$studentId/parent', {
    'name': name,
    'email': email,
    'phone': phone,
    'password': password,
  });

  // ─── USER PROFILE MANAGEMENT ────────────────────────────────

  /// Fetch latest user data from the backend
  static Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/user/$userId'),
        headers: _headers,
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return null;
  }

  /// Update name, phone, or other profile fields
  static Future<(bool, String?)> updateUserProfile(
    int userId, {
    required String name,
    String? phone,
  }) async {
    return _putWithMessage('/user/$userId', {'name': name, 'phone': phone});
  }

  static Future<bool> deleteStudent(int studentId) async {
    return _deleteStatus('/rector/remove-student/$studentId');
  }

  static Future<(bool, String?)> updatePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) => _putWithMessage('/user/$userId/password', {
    'oldPassword': oldPassword,
    'newPassword': newPassword,
  });

  // ─── COUNSELOR — STUDENT ASSIGNMENT ─────────────────

  /// Fetch students with no counselor assigned
  static Future<List<dynamic>> fetchUnassignedStudents() =>
      _getList('/counselor/students/unassigned');

  /// Counselor claims a student
  static Future<bool> assignStudentToCounselor(int studentId) async {
    return _putWithMessage('/counselor/student/$studentId/assign', {
      'counselor_id': UserSession.userId,
    }).then((res) => res.$1);
  }

  /// Counselor releases a student
  static Future<bool> unassignStudentFromCounselor(int studentId) async {
    return _putWithMessage(
      '/counselor/student/$studentId/unassign',
      {},
    ).then((res) => res.$1);
  }

  // ─── WARDEN — STUDENT ASSIGNMENT ────────────────────

  /// Students with no room assigned yet
  static Future<List<dynamic>> fetchUnassignedRoomStudents() =>
      _getList('/warden/students/unassigned');

  /// Available rooms in the current Warden's managed hostel
  static Future<List<dynamic>> fetchWardenAvailableRooms() =>
      _getList('/warden/${UserSession.userId}/available-rooms');

  /// Warden assigns a student to a room
  static Future<bool> assignRoomToStudent(int studentId, int roomId) async {
    return _putWithMessage('/warden/student/$studentId/assign-room', {
      'room_id': roomId,
    }).then((res) => res.$1);
  }

  // ─── ADMIN — STAFF MANAGEMENT ────────────────────────
  static Future<List<dynamic>> fetchStaffAdmin() => _getList('/admin/staff');

  static Future<(bool, String?)> registerStaffAdmin(Map<String, dynamic> data) =>
      _postWithMessage('/admin/staff', data);

  static Future<(bool, String?)> updateStaffAdmin(int id, Map<String, dynamic> data) =>
      _putWithMessage('/admin/staff/$id', data);

  static Future<(bool, String?)> deleteStaffAdmin(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/admin/staff/$id'), headers: _headers);
    if (res.statusCode == 200) return (true, null);
    return (false, jsonDecode(res.body)['message'] as String? ?? 'Error');
  }

  static Future<List<dynamic>> fetchHostelsAdmin() => _getList('/admin/hostels');

  static Future<bool> assignWardenAdmin(int hId, int? wId) =>
      _postStatus('/admin/assign-warden', {'hostel_id': hId, 'warden_id': wId});

  static Future<(bool, String?)> deleteHostelAdmin(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/admin/hostels/$id'), headers: _headers);
    if (res.statusCode == 200) return (true, null);
    return (false, jsonDecode(res.body)['message'] as String? ?? 'Error');
  }

  static Future<(bool, String?)> createHostelAdmin(String name) =>
      _postWithMessage('/admin/hostels', {'hostel_name': name});

  static Future<(bool, String?)> updateHostelAdmin(int id, String name) =>
      _putWithMessage('/admin/hostels/$id', {'hostel_name': name});

  static Future<List<dynamic>> fetchRoomsAdmin(int hostelId) =>
      _getList('/admin/hostels/$hostelId/rooms');

  static Future<(bool, String?)> createRoomAdmin(Map<String, dynamic> data) =>
      _postWithMessage('/admin/rooms', data);

  static Future<(bool, String?)> updateRoomAdmin(int id, Map<String, dynamic> data) =>
      _putWithMessage('/admin/rooms/$id', data);

  static Future<(bool, String?)> deleteRoomAdmin(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/admin/rooms/$id'), headers: _headers);
    if (res.statusCode == 200) return (true, null);
    return (false, jsonDecode(res.body)['message'] as String? ?? 'Error');
  }

  // ─── NOTICE BOARD ───────────────────────────────────
  static Future<List<dynamic>> fetchNotices() => _getList('/notices');

  static Future<(bool, String?)> createNoticeAdmin(Map<String, dynamic> data) =>
      _postWithMessage('/admin/notices', data);

  static Future<(bool, String?)> deleteNoticeAdmin(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/admin/notices/$id'), headers: _headers);
    if (res.statusCode == 200) return (true, null);
    return (false, jsonDecode(res.body)['message'] as String? ?? 'Error');
  }

  static Future<Map<String, dynamic>?> fetchAdminStats() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/stats'), headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // --- Face Registration ---
  static Future<bool> uploadFaceRegistrationPhotos(Map<String, XFile> photos) async {
    try {
      final studentId = UserSession.studentId;
      if (studentId == null) return false;
      
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/student/$studentId/face/upload'));
      
      for (var entry in photos.entries) {
        final bytes = await entry.value.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          entry.key,
          bytes,
          filename: '${entry.key}.jpg',
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Asynchronously trigger training
        triggerFaceModelTraining();
        return true;
      }
      return false;
    } catch (e) {
      print('Upload Error: $e');
      return false;
    }
  }

  static Future<void> triggerFaceModelTraining() async {
    try {
      await http.post(Uri.parse('$baseUrl/admin/face/train'));
    } catch (e) {
      print('Trigger training error: $e');
    }
  }
}
