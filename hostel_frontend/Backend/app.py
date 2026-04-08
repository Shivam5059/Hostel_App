from flask import Flask, request, jsonify
from flask_cors import CORS
import bcrypt
from db import query_db, execute_db, execute_many_db, get_db_connection

app = Flask(__name__)
CORS(app)

@app.route("/", methods=["GET"])
def index():
    return "Hostel Management Backend is running 🚀 (Python Flask)"

# ==========================================
# AUTHENTICATION
# ==========================================
@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json()
    email = data.get("email")
    password = data.get("password")

    user = query_db("SELECT * FROM user WHERE email = ?", [email], one=True)
    if not user:
        return jsonify({"message": "Invalid credentials"}), 401

    if not user.get('password') or not bcrypt.checkpw(password.encode('utf-8'), user['password'].encode('utf-8')):
        return jsonify({"message": "Invalid credentials"}), 401

    return jsonify({
        "message": "Login successful",
        "user": {
            "user_id": user['user_id'],
            "name": user['name'],
            "role": user['role']
        }
    })

# ==========================================
# USER PROFILE MANAGEMENT
# ==========================================
@app.route("/api/user/<int:user_id>", methods=["GET"])
def get_user_profile(user_id):
    query = """
        SELECT u.user_id, u.name, u.email, u.phone, u.role, u.created_at,
               s.roll_no, s.student_id, r.room_number, h.hostel_name
        FROM "user" u
        LEFT JOIN student s ON u.user_id = s.user_id
        LEFT JOIN room r ON s.room_id = r.room_id
        LEFT JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE u.user_id = ?
    """
    user = query_db(query, [user_id], one=True)
    if not user:
        return jsonify({"message": "User not found"}), 404
    return jsonify(user)

@app.route("/api/user/<int:user_id>", methods=["PUT"])
def update_user_profile(user_id):
    data = request.get_json()
    name = data.get("name")
    phone = data.get("phone")

    if not name or len(name.strip()) < 2:
        return jsonify({"message": "Name must be at least 2 characters long"}), 400

    _, rowcount = execute_db(
        'UPDATE "user" SET name = ?, phone = ? WHERE user_id = ?',
        [name.strip(), phone.strip() if phone else None, user_id]
    )
    if rowcount == 0:
        return jsonify({"message": "User not found"}), 404

    return jsonify({
        "message": "Profile updated successfully",
        "updated": {"name": name.strip(), "phone": phone.strip() if phone else None}
    })

@app.route("/api/user/<int:user_id>/password", methods=["PUT"])
def update_user_password(user_id):
    data = request.get_json()
    oldPassword = data.get("oldPassword")
    newPassword = data.get("newPassword")

    if not oldPassword or not newPassword:
        return jsonify({"message": "oldPassword and newPassword are required"}), 400
    if len(newPassword) < 8:
        return jsonify({"message": "New password must be at least 8 characters long"}), 400

    user = query_db('SELECT password FROM "user" WHERE user_id = ?', [user_id], one=True)
    if not user:
        return jsonify({"message": "User not found"}), 404

    if not user.get('password') or not bcrypt.checkpw(oldPassword.encode('utf-8'), user['password'].encode('utf-8')):
        return jsonify({"message": "Incorrect current password"}), 401

    hashed = bcrypt.hashpw(newPassword.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    execute_db('UPDATE "user" SET password = ? WHERE user_id = ?', [hashed, user_id])
    
    return jsonify({"message": "Password updated successfully"})

# ==========================================
# LEAVE MANAGEMENT
# ==========================================
@app.route("/api/student/leave/<int:student_id>", methods=["GET"])
def get_student_leaves(student_id):
    query = """
        SELECT leave_id, from_date, to_date, reason, status, created_at
        FROM leave_request
        WHERE student_id = ?
        ORDER BY created_at DESC
    """
    leaves = query_db(query, [student_id])
    return jsonify(leaves)

@app.route("/api/student/leave", methods=["POST"])
def submit_leave():
    data = request.get_json()
    student_id = data.get("student_id")
    from_date = data.get("from_date")
    to_date = data.get("to_date")
    reason = data.get("reason")

    query = """
        INSERT INTO leave_request (student_id, from_date, to_date, reason)
        VALUES (?, ?, ?, ?)
    """
    last_id, _ = execute_db(query, [student_id, from_date, to_date, reason])
    return jsonify({
        "message": "Leave request submitted successfully",
        "leave_id": last_id
    })

def update_leave_status(leave_id):
    query = """
        SELECT parent_approved, counselor_approved, warden_approved
        FROM leave_request
        WHERE leave_id = ?
    """
    leave = query_db(query, [leave_id], one=True)
    if not leave:
        return None

    new_status = 'PENDING'
    if leave['parent_approved'] == -1 or leave['counselor_approved'] == -1 or leave['warden_approved'] == -1:
        new_status = 'REJECTED'
    elif leave['parent_approved'] == 1 and leave['counselor_approved'] == 1 and leave['warden_approved'] == 1:
        new_status = 'APPROVED'

    execute_db("UPDATE leave_request SET status = ? WHERE leave_id = ?", [new_status, leave_id])
    return new_status

@app.route("/api/<role>/leave/<int:leave_id>/<action>", methods=["POST"])
def approve_reject_leave(role, leave_id, action):
    if role not in ['parent', 'counselor', 'warden'] or action not in ['approve', 'reject']:
        return jsonify({"message": "Invalid endpoint"}), 404

    column = f"{role}_approved"
    value = 1 if action == 'approve' else -1
    query = f"UPDATE leave_request SET {column} = ? WHERE leave_id = ?"
    execute_db(query, [value, leave_id])

    new_status = update_leave_status(leave_id)
    return jsonify({"message": f"Action recorded. Leave status: {new_status}"})

@app.route("/api/<role>/leaves", methods=["GET"])
def get_assigned_leaves(role):
    parent_id = request.args.get("parentId")
    counselor_id = request.args.get("counselorId")
    warden_id = request.args.get("wardenId")

    joins = """
        JOIN student s ON lr.student_id = s.student_id
        JOIN "user" u ON s.user_id = u.user_id
    """
    if role == 'parent' and parent_id:
        assigned_column = 's.parent_id'
        assigned_id = parent_id
        condition = "lr.status = 'PENDING' AND lr.parent_approved = 0"
    elif role == 'counselor' and counselor_id:
        assigned_column = 's.counselor_id'
        assigned_id = counselor_id
        condition = "lr.status = 'PENDING' AND lr.parent_approved = 1 AND lr.counselor_approved = 0"
    elif role == 'warden' and warden_id:
        joins += " JOIN room r ON s.room_id = r.room_id JOIN hostel h ON r.hostel_id = h.hostel_id"
        assigned_column = 'h.warden_id'
        assigned_id = warden_id
        condition = "lr.status = 'PENDING' AND lr.parent_approved = 1 AND lr.warden_approved = 0"
    else:
        return jsonify({"message": "Invalid endpoint or missing params"}), 404

    created_at_field = "" if role == "parent" else "lr.created_at,"
    query = f"""
        SELECT lr.leave_id, lr.student_id, lr.from_date, lr.to_date, lr.reason, lr.status,
               lr.parent_approved, lr.counselor_approved, lr.warden_approved,
               {created_at_field} u.name as student_name
        FROM leave_request lr {joins}
        WHERE {assigned_column} = ? AND {condition}
        ORDER BY lr.created_at DESC
    """
    leaves = query_db(query, [assigned_id])
    return jsonify(leaves)

@app.route("/api/<role>/leaves/history", methods=["GET"])
def get_leave_history(role):
    parent_id = request.args.get("parentId")
    counselor_id = request.args.get("counselorId")
    warden_id = request.args.get("wardenId")

    joins = """
        JOIN student s ON lr.student_id = s.student_id
        JOIN "user" u ON s.user_id = u.user_id
    """
    if role == 'parent' and parent_id:
        assigned_column = 's.parent_id'
        assigned_id = parent_id
        approved_column = 'lr.parent_approved'
    elif role == 'counselor' and counselor_id:
        assigned_column = 's.counselor_id'
        assigned_id = counselor_id
        approved_column = 'lr.counselor_approved'
    elif role == 'warden' and warden_id:
        joins += " JOIN room r ON s.room_id = r.room_id JOIN hostel h ON r.hostel_id = h.hostel_id"
        assigned_column = 'h.warden_id'
        assigned_id = warden_id
        approved_column = 'lr.warden_approved'
    else:
        return jsonify({"message": "Invalid endpoint or missing params"}), 404

    created_at_field = "" if role == "parent" else "lr.created_at,"
    query = f"""
        SELECT lr.leave_id, lr.student_id, lr.from_date, lr.to_date, lr.reason, lr.status,
               lr.parent_approved, lr.counselor_approved, lr.warden_approved,
               {created_at_field} u.name as student_name
        FROM leave_request lr {joins}
        WHERE {assigned_column} = ? AND {approved_column} != 0
        ORDER BY lr.created_at DESC
    """
    history = query_db(query, [assigned_id])
    return jsonify(history)

# ==========================================
# STUDENT MANAGEMENT
# ==========================================
@app.route("/api/counselor/<int:counselor_id>/students", methods=["GET"])
def get_counselor_students(counselor_id):
    query = """
        SELECT s.student_id, s.roll_no, u.name, u.email, h.hostel_name
        FROM student s
        JOIN "user" u ON s.user_id = u.user_id
        LEFT JOIN room r ON s.room_id = r.room_id
        LEFT JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE s.counselor_id = ?
    """
    return jsonify(query_db(query, [counselor_id]))

@app.route("/api/warden/<int:warden_id>/students", methods=["GET"])
def get_warden_students(warden_id):
    query = """
        SELECT s.student_id, s.roll_no, u.name, u.email, h.hostel_name
        FROM student s
        JOIN "user" u ON s.user_id = u.user_id
        JOIN room r ON s.room_id = r.room_id
        JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE h.warden_id = ?
    """
    return jsonify(query_db(query, [warden_id]))

@app.route("/api/parent/<int:parent_id>/students", methods=["GET"])
def get_parent_students(parent_id):
    query = """
        SELECT s.student_id, s.roll_no, u.name, u.email, h.hostel_name, r.room_number
        FROM student s
        JOIN "user" u ON s.user_id = u.user_id
        LEFT JOIN room r ON s.room_id = r.room_id
        LEFT JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE s.parent_id = ?
    """
    return jsonify(query_db(query, [parent_id]))

# ==========================================
# ATTENDANCE SYSTEM
# ==========================================
def calculate_attendance_summary(attendance_rows):
    total = len(attendance_rows)
    present = sum(1 for row in attendance_rows if row['status'] == 'PRESENT')
    absent = total - present
    percentage = round((present / total) * 100, 2) if total > 0 else 0
    return {
        "total_classes": total,
        "present_count": present,
        "absent_count": absent,
        "attendance_percentage": percentage
    }

def fetch_student_attendance_records(student_id):
    query = """
        SELECT a.attendance_id, a.student_id, a.warden_id, w.name AS warden_name,
               a.attendance_date, a.status, a.marked_at
        FROM attendance a
        LEFT JOIN "user" w ON a.warden_id = w.user_id
        WHERE a.student_id = ?
        ORDER BY a.attendance_date DESC, a.marked_at DESC
    """
    return query_db(query, [student_id])

@app.route("/api/student/<int:student_id>/attendance", methods=["GET"])
def get_student_attendance(student_id):
    lookup_query = "SELECT student_id FROM student WHERE student_id = ? OR user_id = ? LIMIT 1"
    student = query_db(lookup_query, [student_id, student_id], one=True)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    actual_student_id = student['student_id']
    records = fetch_student_attendance_records(actual_student_id)
    return jsonify({
        "student_id": actual_student_id,
        "attendance_summary": calculate_attendance_summary(records),
        "attendance_records": records
    })

@app.route("/api/student/<int:student_id>/details", methods=["GET"])
def get_student_details(student_id):
    details_query = """
        SELECT s.student_id, s.user_id, u.name, u.email, u.phone,
               s.roll_no, s.counselor_id, r.room_id, r.room_number, h.hostel_name
        FROM student s
        JOIN "user" u ON u.user_id = s.user_id
        LEFT JOIN room r ON s.room_id = r.room_id
        LEFT JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE s.student_id = ? LIMIT 1
    """
    student = query_db(details_query, [student_id], one=True)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    records = fetch_student_attendance_records(student['student_id'])
    # Combine dicts
    result = dict(student)
    result["attendance_summary"] = calculate_attendance_summary(records)
    result["attendance_records"] = records
    return jsonify(result)

@app.route("/api/warden/attendance/submit", methods=["POST"])
def submit_attendance():
    data = request.get_json()
    warden_id = data.get("warden_id")
    attendance_date = data.get("attendance_date")
    records = data.get("attendanceRecords", [])

    if not warden_id or not attendance_date or not records:
        return jsonify({"message": "Missing required fields"}), 400

    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute("BEGIN TRANSACTION")
        c.execute("DELETE FROM attendance WHERE warden_id = ? AND attendance_date = ?", [warden_id, attendance_date])
        
        args_list = [(r['student_id'], warden_id, attendance_date, r['status']) for r in records]
        c.executemany(
            "INSERT INTO attendance (student_id, warden_id, attendance_date, status) VALUES (?, ?, ?, ?)",
            args_list
        )
        conn.commit()
        return jsonify({"message": "Attendance submitted successfully", "attendance_date": attendance_date, "records_submitted": len(records)})
    except Exception as e:
        conn.rollback()
        return jsonify({"message": "Failed to commit attendance records"}), 500
    finally:
        c.close()
        conn.close()

@app.route("/api/warden/<int:warden_id>/attendance-history", methods=["GET"])
def get_attendance_history(warden_id):
    query = """
        SELECT a.attendance_date, COUNT(*) AS total_students,
               SUM(CASE WHEN a.status = 'PRESENT' THEN 1 ELSE 0 END) AS present_count,
               SUM(CASE WHEN a.status = 'ABSENT' THEN 1 ELSE 0 END) AS absent_count,
               MAX(a.marked_at) AS marked_at
        FROM attendance a
        WHERE a.warden_id = ?
        GROUP BY a.attendance_date ORDER BY a.attendance_date DESC
    """
    return jsonify(query_db(query, [warden_id]))

@app.route("/api/warden/<int:warden_id>/attendance/<date>", methods=["GET"])
def get_attendance_date_details(warden_id, date):
    query = """
        SELECT a.attendance_id, a.student_id, u.name, s.roll_no, a.status, a.attendance_date, a.marked_at
        FROM attendance a
        JOIN student s ON a.student_id = s.student_id
        JOIN "user" u ON s.user_id = u.user_id
        WHERE a.warden_id = ? AND a.attendance_date = ?
        ORDER BY u.name ASC
    """
    return jsonify(query_db(query, [warden_id, date]))

# ==========================================
# COMPLAINT SYSTEM
# ==========================================
@app.route("/api/complaints", methods=["POST"])
def submit_complaint():
    data = request.get_json()
    student_id = data.get("student_id")
    description = data.get("description")
    if not student_id or not description:
        return jsonify({"message": "Missing required fields"}), 400

    last_id, _ = execute_db("INSERT INTO complaint (student_id, description) VALUES (?, ?)", [student_id, description])
    return jsonify({"message": "Complaint submitted successfully", "complaint_id": last_id})

@app.route("/api/complaints", methods=["GET"])
def get_complaints():
    status = request.args.get("status")
    valid_statuses = ['PENDING', 'RESOLVED', 'REJECTED']
    condition = ""
    params = []

    if status and status.upper() in valid_statuses:
        condition = "WHERE c.status = ?"
        params.append(status.upper())

    query = f"""
        SELECT c.complaint_id, c.description, c.status, c.register_date, c.end_date,
               u.name AS student_name, s.roll_no,
               ru.name AS rector_name
        FROM complaint c
        JOIN student s ON c.student_id = s.student_id
        JOIN "user" u ON s.user_id = u.user_id
        LEFT JOIN "user" ru ON c.rector_id = ru.user_id
        {condition}
        ORDER BY c.register_date DESC
    """
    return jsonify(query_db(query, params))

@app.route("/api/complaints/<int:complaint_id>", methods=["GET"])
def get_complaint(complaint_id):
    query = """
        SELECT c.complaint_id, c.description, c.status, c.register_date, c.end_date,
               u.name AS student_name, s.roll_no, s.student_id,
               ru.name AS rector_name
        FROM complaint c
        JOIN student s ON c.student_id = s.student_id
        JOIN "user" u ON s.user_id = u.user_id
        LEFT JOIN "user" ru ON c.rector_id = ru.user_id
        WHERE c.complaint_id = ?
    """
    comp = query_db(query, [complaint_id], one=True)
    if not comp:
        return jsonify({"message": "Complaint not found"}), 404
    return jsonify(comp)

@app.route("/api/complaints/<int:complaint_id>/status", methods=["PUT"])
def update_complaint_status(complaint_id):
    data = request.get_json()
    status = data.get("status")
    rector_id = data.get("rector_id")

    if status not in ['RESOLVED', 'REJECTED']:
        return jsonify({"message": "Status must be RESOLVED or REJECTED"}), 400
    if not rector_id:
        return jsonify({"message": "rector_id is required"}), 400

    execute_db(
        "UPDATE complaint SET status = ?, rector_id = ?, end_date = CURRENT_TIMESTAMP WHERE complaint_id = ?",
        [status, rector_id, complaint_id]
    )
    return jsonify({"message": f"Complaint marked as {status}"})

@app.route("/api/student/<int:student_id>/complaints", methods=["GET"])
def get_student_complaints(student_id):
    query = """
        SELECT c.complaint_id, c.description, c.status, c.register_date, c.end_date,
               ru.name AS rector_name
        FROM complaint c
        LEFT JOIN "user" ru ON c.rector_id = ru.user_id
        WHERE c.student_id = ?
        ORDER BY c.register_date DESC
    """
    return jsonify(query_db(query, [student_id]))

# ==========================================
# ROOM TRANSFER SYSTEM
# ==========================================
@app.route("/api/rooms/available", methods=["GET"])
def get_available_rooms():
    query = """
        SELECT r.room_id, r.room_number, r.capacity, h.hostel_name, h.hostel_id,
               (SELECT COUNT(*) FROM student s WHERE s.room_id = r.room_id) as occupied
        FROM room r
        JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE occupied < r.capacity
    """
    return jsonify(query_db(query))

@app.route("/api/student/room-transfer", methods=["POST"])
def submit_room_transfer():
    data = request.get_json()
    student_id = data.get("student_id")
    requested_room_id = data.get("requested_room_id")
    reason = data.get("reason")

    if not student_id or not requested_room_id or not reason:
        return jsonify({"message": "Missing required fields"}), 400

    student = query_db("SELECT room_id FROM student WHERE student_id = ?", [student_id], one=True)
    if not student:
        return jsonify({"message": "Student not found"}), 500

    current_room_id = student['room_id']
    execute_db(
        "INSERT INTO room_transfer_requests (student_id, current_room_id, requested_room_id, reason) VALUES (?, ?, ?, ?)",
        [student_id, current_room_id, requested_room_id, reason]
    )
    return jsonify({"message": "Room transfer request submitted successfully"})

@app.route("/api/student/<int:student_id>/room-transfers", methods=["GET"])
def get_student_room_transfers(student_id):
    query = """
        SELECT rt.request_id, rt.status, rt.reason, rt.created_at,
               cr.room_number as current_room, rr.room_number as requested_room,
               ch.hostel_name as current_hostel, rh.hostel_name as requested_hostel
        FROM room_transfer_requests rt
        LEFT JOIN room cr ON rt.current_room_id = cr.room_id
        LEFT JOIN hostel ch ON cr.hostel_id = ch.hostel_id
        JOIN room rr ON rt.requested_room_id = rr.room_id
        JOIN hostel rh ON rr.hostel_id = rh.hostel_id
        WHERE rt.student_id = ?
        ORDER BY rt.created_at DESC
    """
    return jsonify(query_db(query, [student_id]))

@app.route("/api/warden/<int:warden_id>/room-transfers", methods=["GET"])
def get_warden_room_transfers(warden_id):
    query = """
        SELECT rt.request_id, rt.student_id, u.name as student_name, 
               cr.room_number as current_room, ch.hostel_name as current_hostel,
               rr.room_number as requested_room, rh.hostel_name as requested_hostel,
               rt.reason, rt.status, rt.created_at
        FROM room_transfer_requests rt
        JOIN student s ON rt.student_id = s.student_id
        JOIN "user" u ON s.user_id = u.user_id
        LEFT JOIN room cr ON rt.current_room_id = cr.room_id
        LEFT JOIN hostel ch ON cr.hostel_id = ch.hostel_id
        JOIN room rr ON rt.requested_room_id = rr.room_id
        JOIN hostel rh ON rr.hostel_id = rh.hostel_id
        WHERE ch.warden_id = ?
        ORDER BY rt.created_at DESC
    """
    return jsonify(query_db(query, [warden_id]))

@app.route("/api/room-transfer/<int:request_id>/status", methods=["POST"])
def update_room_transfer_status(request_id):
    data = request.get_json()
    status = data.get("status")
    if status not in ["PENDING", "APPROVED", "REJECTED"]:
        return jsonify({"message": "Invalid status value"}), 400

    execute_db("UPDATE room_transfer_requests SET status = ? WHERE request_id = ?", [status, request_id])
    if status == "APPROVED":
        req_entry = query_db("SELECT student_id, requested_room_id FROM room_transfer_requests WHERE request_id = ?", [request_id], one=True)
        if req_entry:
            execute_db("UPDATE student SET room_id = ? WHERE student_id = ?", [req_entry['requested_room_id'], req_entry['student_id']])
            
    return jsonify({"message": "Room transfer status updated successfully"})

# ==========================================
# FOOD MENU SYSTEM
# ==========================================
from datetime import datetime

def fetch_menu_for_day(day):
    query = """
        SELECT dm.meal_type, fi.item_id, fi.item_name, fi.is_veg
        FROM daily_menu dm
        LEFT JOIN menu_food_items mfi ON dm.menu_id = mfi.menu_id
        LEFT JOIN food_items fi ON mfi.item_id = fi.item_id
        WHERE dm.day_of_week = ?
        ORDER BY dm.meal_type, fi.item_name
    """
    rows = query_db(query, [day])
    grouped = {"Breakfast": [], "Lunch": [], "Dinner": []}
    for row in rows:
        if row['item_id'] and row['meal_type'] in grouped:
            grouped[row['meal_type']].append({
                "item_id": row['item_id'],
                "item_name": row['item_name'],
                "is_veg": bool(row['is_veg'])
            })
    return grouped

@app.route("/api/menu/today", methods=["GET"])
def get_today_menu():
    today = datetime.now().strftime('%A')
    return jsonify({"day": today, "menu": fetch_menu_for_day(today)})

@app.route("/api/menu/<day>", methods=["GET"])
def get_menu_day(day):
    valid_days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    if day not in valid_days:
        return jsonify({"message": "Invalid day"}), 400
    return jsonify({"day": day, "menu": fetch_menu_for_day(day)})

@app.route("/api/menu/items/all", methods=["GET"])
def get_all_food_items():
    return jsonify(query_db("SELECT item_id, item_name, is_veg FROM food_items ORDER BY item_name"))

@app.route("/api/menu/items", methods=["POST"])
def add_food_item():
    data = request.get_json()
    item_name = data.get("item_name")
    is_veg = data.get("is_veg")

    if not item_name:
        return jsonify({"message": "item_name is required"}), 400

    last_id, _ = execute_db("INSERT INTO food_items (item_name, is_veg) VALUES (?, ?)", [item_name, 1 if is_veg else 0])
    return jsonify({"message": "Food item added", "item_id": last_id})

@app.route("/api/menu/<day>/<meal>", methods=["PUT"])
def update_meal_items(day, meal):
    valid_days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
    valid_meals = ['Breakfast', 'Lunch', 'Dinner']
    data = request.get_json()
    item_ids = data.get("item_ids")

    if day not in valid_days or meal not in valid_meals:
        return jsonify({"message": "Invalid day or meal type"}), 400
    if not isinstance(item_ids, list):
        return jsonify({"message": "item_ids must be an array"}), 400

    menu = query_db("SELECT menu_id FROM daily_menu WHERE day_of_week = ? AND meal_type = ?", [day, meal], one=True)
    if not menu:
        return jsonify({"message": "Meal slot not found"}), 500

    menu_id = menu['menu_id']
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute("BEGIN TRANSACTION")
        c.execute("DELETE FROM menu_food_items WHERE menu_id = ?", [menu_id])
        if item_ids:
            c.executemany("INSERT OR IGNORE INTO menu_food_items (menu_id, item_id) VALUES (?, ?)", [(menu_id, i) for i in item_ids])
        conn.commit()
    except Exception as e:
        conn.rollback()
        return jsonify({"message": "Failed to update items"}), 500
    finally:
        c.close()
        conn.close()
    
    return jsonify({"message": f"{day} {meal} updated with {len(item_ids)} items"})


# ==========================================
# WARDEN — STUDENT ASSIGNMENT
# ==========================================
@app.route("/api/warden/students/unassigned", methods=["GET"])
def get_unassigned_students_warden():
    query = """
        SELECT s.student_id, s.roll_no, u.name, u.email, u.phone, u.created_at
        FROM student s
        JOIN "user" u ON s.user_id = u.user_id
        WHERE s.room_id IS NULL
        ORDER BY u.created_at DESC
    """
    return jsonify(query_db(query))

@app.route("/api/warden/<int:warden_id>/available-rooms", methods=["GET"])
def get_warden_available_rooms(warden_id):
    query = """
        SELECT r.room_id, r.room_number, r.capacity, h.hostel_name,
               (SELECT COUNT(*) FROM student s WHERE s.room_id = r.room_id) as occupied
        FROM room r
        JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE h.warden_id = ? AND (SELECT COUNT(*) FROM student s WHERE s.room_id = r.room_id) < r.capacity
    """
    return jsonify(query_db(query, [warden_id]))

@app.route("/api/warden/student/<int:student_id>/assign-room", methods=["PUT"])
def assign_student_room(student_id):
    data = request.get_json()
    room_id = data.get("room_id")
    if not room_id:
        return jsonify({"message": "room_id is required"}), 400

    _, rowcount = execute_db("UPDATE student SET room_id = ? WHERE student_id = ?", [room_id, student_id])
    if rowcount == 0:
        return jsonify({"message": "Student not found"}), 404
    return jsonify({"message": "Room assigned successfully"})


# ==========================================
# RECTOR — ADMISSIONS MANAGEMENT
# ==========================================
@app.route("/api/rector/counselors", methods=["GET"])
def get_rector_counselors():
    return jsonify(query_db('SELECT user_id, name, email FROM "user" WHERE UPPER(role) = "COUNSELOR" ORDER BY name'))

@app.route("/api/rector/student", methods=["POST"])
def register_student():
    data = request.get_json()
    email = data.get("email")
    roll_no = data.get("roll_no")
    phone = data.get("phone")

    if not email or not roll_no:
        return jsonify({"message": "email and roll_no are required"}), 400

    if query_db('SELECT user_id FROM "user" WHERE email = ?', [email]):
        return jsonify({"message": "Email is already registered"}), 409
    if query_db('SELECT student_id FROM student WHERE roll_no = ?', [roll_no]):
        return jsonify({"message": "Roll number is already registered"}), 409
    if phone and query_db('SELECT user_id FROM "user" WHERE phone = ?', [phone]):
        return jsonify({"message": "Phone number is already registered"}), 409

    hashed = bcrypt.hashpw(roll_no.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute("BEGIN TRANSACTION")
        c.execute('INSERT INTO "user" (name, email, phone, password, role) VALUES (?, ?, ?, ?, "STUDENT")', [roll_no, email, phone, hashed])
        user_id = c.lastrowid
        c.execute("INSERT INTO student (user_id, roll_no) VALUES (?, ?)", [user_id, roll_no])
        student_id = c.lastrowid
        conn.commit()
    except Exception as e:
        conn.rollback()
        return jsonify({"message": "Failed to create user (Rolling back)"}), 500
    finally:
        c.close()
        conn.close()

    return jsonify({
        "message": "Student registered successfully",
        "student_id": student_id,
        "user_id": user_id,
        "temp_password": roll_no
    }), 201

@app.route("/api/rector/students/new", methods=["GET"])
def get_new_students():
    query = """
        SELECT s.student_id, s.roll_no, u.name, u.email, u.phone, u.created_at,
               r.room_number, h.hostel_name
        FROM student s
        JOIN "user" u  ON s.user_id  = u.user_id
        LEFT JOIN room r   ON s.room_id   = r.room_id
        LEFT JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE s.parent_id IS NULL
        ORDER BY u.created_at DESC
    """
    return jsonify(query_db(query))

@app.route("/api/rector/parents", methods=["GET"])
def get_parents():
    return jsonify(query_db('SELECT user_id, name, email, phone FROM "user" WHERE UPPER(role) = "PARENT" ORDER BY name'))

@app.route("/api/rector/student/<int:student_id>/parent", methods=["PUT"])
def link_existing_parent(student_id):
    data = request.get_json()
    parent_user_id = data.get("parent_user_id")
    if not parent_user_id:
        return jsonify({"message": "parent_user_id is required"}), 400

    _, rowcount = execute_db("UPDATE student SET parent_id = ? WHERE student_id = ?", [parent_user_id, student_id])
    if rowcount == 0:
        return jsonify({"message": "Student not found"}), 404
    return jsonify({"message": "Parent linked successfully"})

@app.route("/api/rector/student/<int:student_id>/parent", methods=["POST"])
def register_and_link_parent(student_id):
    data = request.get_json()
    name = data.get("name")
    email = data.get("email")
    phone = data.get("phone")
    password = data.get("password")

    if not name or not email or not password:
        return jsonify({"message": "name, email and password are required"}), 400

    if query_db('SELECT user_id FROM "user" WHERE email = ?', [email]):
        return jsonify({"message": "A user with this email already exists"}), 409
    if phone and query_db('SELECT user_id FROM "user" WHERE phone = ?', [phone]):
        return jsonify({"message": "A user with this phone number already exists"}), 409

    hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute("BEGIN TRANSACTION")
        c.execute('INSERT INTO "user" (name, email, phone, password, role) VALUES (?, ?, ?, ?, "PARENT")', [name, email, phone, hashed])
        parent_user_id = c.lastrowid
        c.execute("UPDATE student SET parent_id = ? WHERE student_id = ?", [parent_user_id, student_id])
        conn.commit()
    except Exception as e:
        conn.rollback()
        return jsonify({"message": "Transaction failed (Rolling back)"}), 500
    finally:
        c.close()
        conn.close()

    return jsonify({"message": "Parent registered and linked successfully", "parent_id": parent_user_id}), 201


# ==========================================
# COUNSELOR — STUDENT ASSIGNMENT
# ==========================================
@app.route("/api/counselor/students/unassigned", methods=["GET"])
def get_counselor_unassigned_students():
    query = """
        SELECT s.student_id, s.roll_no, u.name, u.email, u.phone, u.created_at,
               r.room_number, h.hostel_name
        FROM student s
        JOIN "user" u  ON s.user_id  = u.user_id
        LEFT JOIN room r   ON s.room_id   = r.room_id
        LEFT JOIN hostel h ON r.hostel_id = h.hostel_id
        WHERE s.counselor_id IS NULL
        ORDER BY u.created_at DESC
    """
    return jsonify(query_db(query))

@app.route("/api/counselor/student/<int:student_id>/assign", methods=["PUT"])
def assign_counselor(student_id):
    data = request.get_json()
    counselor_id = data.get("counselor_id")
    if not counselor_id:
        return jsonify({"message": "counselor_id is required"}), 400

    _, rowcount = execute_db("UPDATE student SET counselor_id = ? WHERE student_id = ?", [counselor_id, student_id])
    if rowcount == 0:
        return jsonify({"message": "Student not found"}), 404
    return jsonify({"message": "Student assigned successfully"})

@app.route("/api/counselor/student/<int:student_id>/unassign", methods=["PUT"])
def unassign_counselor(student_id):
    _, rowcount = execute_db("UPDATE student SET counselor_id = NULL WHERE student_id = ?", [student_id])
    if rowcount == 0:
        return jsonify({"message": "Student not found"}), 404
    return jsonify({"message": "Student unassigned successfully"})
