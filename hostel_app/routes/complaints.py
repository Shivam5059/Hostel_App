from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from hostel_app import db
from hostel_app.models import Complaint, Student

complaints_bp = Blueprint("complaints", __name__)


@complaints_bp.route("/")
@login_required
def list_complaints():
    if current_user.role in ("admin", "warden"):
        complaints = Complaint.query.order_by(Complaint.created_at.desc()).all()
    else:
        student = Student.query.filter_by(user_id=current_user.id).first()
        if not student:
            flash("Please create your profile first.", "warning")
            return redirect(url_for("students.create_profile"))
        complaints = Complaint.query.filter_by(student_id=student.id).order_by(Complaint.created_at.desc()).all()
    return render_template("complaints/list.html", complaints=complaints)


@complaints_bp.route("/new", methods=["GET", "POST"])
@login_required
def new_complaint():
    student = Student.query.filter_by(user_id=current_user.id).first()
    if not student and current_user.role not in ("admin", "warden"):
        flash("Please create your profile first.", "warning")
        return redirect(url_for("students.create_profile"))
    if request.method == "POST":
        title = request.form.get("title", "").strip()
        description = request.form.get("description", "").strip()
        category = request.form.get("category", "other")
        student_id = student.id if student else int(request.form.get("student_id", 0))
        complaint = Complaint(
            student_id=student_id,
            title=title,
            description=description,
            category=category,
        )
        db.session.add(complaint)
        db.session.commit()
        flash("Complaint submitted successfully.", "success")
        return redirect(url_for("complaints.list_complaints"))
    students = Student.query.all() if current_user.role in ("admin", "warden") else None
    return render_template("complaints/form.html", student=student, students=students)


@complaints_bp.route("/<int:complaint_id>")
@login_required
def view_complaint(complaint_id):
    complaint = Complaint.query.get_or_404(complaint_id)
    if current_user.role not in ("admin", "warden"):
        student = Student.query.filter_by(user_id=current_user.id).first()
        if not student or student.id != complaint.student_id:
            flash("Access denied.", "danger")
            return redirect(url_for("complaints.list_complaints"))
    return render_template("complaints/view.html", complaint=complaint)


@complaints_bp.route("/<int:complaint_id>/update", methods=["POST"])
@login_required
def update_status(complaint_id):
    if current_user.role not in ("admin", "warden"):
        flash("Access denied.", "danger")
        return redirect(url_for("complaints.list_complaints"))
    complaint = Complaint.query.get_or_404(complaint_id)
    status = request.form.get("status")
    resolution = request.form.get("resolution", "").strip()
    if status in ("pending", "in_progress", "resolved"):
        complaint.status = status
        complaint.resolution = resolution or complaint.resolution
        db.session.commit()
        flash("Complaint status updated.", "success")
    return redirect(url_for("complaints.view_complaint", complaint_id=complaint_id))
