from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from datetime import datetime
from hostel_app import db
from hostel_app.models import Student, User, Room

students_bp = Blueprint("students", __name__)


def admin_required(f):
    from functools import wraps

    @wraps(f)
    def decorated(*args, **kwargs):
        if current_user.role not in ("admin", "warden"):
            flash("Access denied.", "danger")
            return redirect(url_for("main.dashboard"))
        return f(*args, **kwargs)

    return decorated


@students_bp.route("/")
@login_required
@admin_required
def list_students():
    students = Student.query.order_by(Student.full_name).all()
    return render_template("students/list.html", students=students)


@students_bp.route("/add", methods=["GET", "POST"])
@login_required
@admin_required
def add_student():
    rooms = Room.query.filter(Room.is_available == True).all()  # noqa: E712
    if request.method == "POST":
        student_id = request.form.get("student_id", "").strip()
        full_name = request.form.get("full_name", "").strip()
        email = request.form.get("email", "").strip()
        phone = request.form.get("phone", "").strip()
        address = request.form.get("address", "").strip()
        course = request.form.get("course", "").strip()
        year = request.form.get("year", "1")
        room_id = request.form.get("room_id") or None

        if Student.query.filter_by(student_id=student_id).first():
            flash("Student ID already exists.", "danger")
            return render_template("students/form.html", rooms=rooms, action="Add")

        if Student.query.filter_by(email=email).first():
            flash("Email already registered.", "danger")
            return render_template("students/form.html", rooms=rooms, action="Add")

        student = Student(
            student_id=student_id,
            full_name=full_name,
            email=email,
            phone=phone,
            address=address,
            course=course,
            year=int(year) if year else 1,
            room_id=int(room_id) if room_id else None,
        )
        db.session.add(student)

        if room_id:
            room = db.session.get(Room, int(room_id))
            if room and room.available_beds <= 1:
                room.is_available = False

        db.session.commit()
        flash(f"Student {full_name} added successfully.", "success")
        return redirect(url_for("students.list_students"))
    return render_template("students/form.html", rooms=rooms, action="Add", student=None)


@students_bp.route("/<int:student_id>/edit", methods=["GET", "POST"])
@login_required
@admin_required
def edit_student(student_id):
    student = Student.query.get_or_404(student_id)
    rooms = Room.query.all()
    if request.method == "POST":
        student.full_name = request.form.get("full_name", "").strip()
        student.email = request.form.get("email", "").strip()
        student.phone = request.form.get("phone", "").strip()
        student.address = request.form.get("address", "").strip()
        student.course = request.form.get("course", "").strip()
        year = request.form.get("year")
        student.year = int(year) if year else student.year
        new_room_id = request.form.get("room_id") or None

        # Handle room change
        if student.room_id != (int(new_room_id) if new_room_id else None):
            if student.room_id:
                old_room = db.session.get(Room, student.room_id)
                if old_room:
                    old_room.is_available = True
            student.room_id = int(new_room_id) if new_room_id else None
            if new_room_id:
                new_room = db.session.get(Room, int(new_room_id))
                if new_room and new_room.available_beds <= 1:
                    new_room.is_available = False

        db.session.commit()
        flash("Student updated successfully.", "success")
        return redirect(url_for("students.list_students"))
    return render_template("students/form.html", rooms=rooms, action="Edit", student=student)


@students_bp.route("/<int:student_id>/delete", methods=["POST"])
@login_required
@admin_required
def delete_student(student_id):
    student = Student.query.get_or_404(student_id)
    if student.room_id:
        room = db.session.get(Room, student.room_id)
        if room:
            room.is_available = True
    db.session.delete(student)
    db.session.commit()
    flash("Student deleted.", "success")
    return redirect(url_for("students.list_students"))


@students_bp.route("/<int:student_id>")
@login_required
def view_student(student_id):
    student = Student.query.get_or_404(student_id)
    if current_user.role not in ("admin", "warden"):
        own = Student.query.filter_by(user_id=current_user.id).first()
        if not own or own.id != student_id:
            flash("Access denied.", "danger")
            return redirect(url_for("main.dashboard"))
    return render_template("students/view.html", student=student)


@students_bp.route("/profile", methods=["GET", "POST"])
@login_required
def profile():
    student = Student.query.filter_by(user_id=current_user.id).first()
    if not student:
        return redirect(url_for("students.create_profile"))
    return render_template("students/view.html", student=student)


@students_bp.route("/profile/create", methods=["GET", "POST"])
@login_required
def create_profile():
    if Student.query.filter_by(user_id=current_user.id).first():
        return redirect(url_for("students.profile"))
    rooms = Room.query.filter(Room.is_available == True).all()  # noqa: E712
    if request.method == "POST":
        student_id = request.form.get("student_id", "").strip()
        full_name = request.form.get("full_name", "").strip()
        phone = request.form.get("phone", "").strip()
        address = request.form.get("address", "").strip()
        course = request.form.get("course", "").strip()
        year = request.form.get("year", "1")

        if Student.query.filter_by(student_id=student_id).first():
            flash("Student ID already exists.", "danger")
            return render_template("students/create_profile.html", rooms=rooms)

        student = Student(
            user_id=current_user.id,
            student_id=student_id,
            full_name=full_name,
            email=current_user.email,
            phone=phone,
            address=address,
            course=course,
            year=int(year) if year else 1,
        )
        db.session.add(student)
        db.session.commit()
        flash("Profile created successfully.", "success")
        return redirect(url_for("main.dashboard"))
    return render_template("students/create_profile.html", rooms=rooms)
