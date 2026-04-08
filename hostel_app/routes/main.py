from flask import Blueprint, render_template, redirect, url_for
from flask_login import login_required, current_user
from hostel_app.models import Student, Room, Complaint, Fee, Leave

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    if current_user.is_authenticated:
        return redirect(url_for("main.dashboard"))
    return redirect(url_for("auth.login"))


@main_bp.route("/dashboard")
@login_required
def dashboard():
    if current_user.role == "admin" or current_user.role == "warden":
        total_students = Student.query.count()
        total_rooms = Room.query.count()
        available_rooms = Room.query.filter_by(is_available=True).count()
        pending_complaints = Complaint.query.filter_by(status="pending").count()
        pending_fees = Fee.query.filter_by(status="pending").count()
        pending_leaves = Leave.query.filter_by(status="pending").count()
        return render_template(
            "main/admin_dashboard.html",
            total_students=total_students,
            total_rooms=total_rooms,
            available_rooms=available_rooms,
            pending_complaints=pending_complaints,
            pending_fees=pending_fees,
            pending_leaves=pending_leaves,
        )
    # Student dashboard
    student = Student.query.filter_by(user_id=current_user.id).first()
    if not student:
        return render_template("main/student_setup.html")
    complaints = Complaint.query.filter_by(student_id=student.id).order_by(Complaint.created_at.desc()).limit(5).all()
    fees = Fee.query.filter_by(student_id=student.id).order_by(Fee.created_at.desc()).limit(5).all()
    leaves = Leave.query.filter_by(student_id=student.id).order_by(Leave.created_at.desc()).limit(5).all()
    return render_template(
        "main/student_dashboard.html",
        student=student,
        complaints=complaints,
        fees=fees,
        leaves=leaves,
    )
