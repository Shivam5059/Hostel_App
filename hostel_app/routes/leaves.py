from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from datetime import datetime, timezone
from hostel_app import db
from hostel_app.models import Leave, Student

leaves_bp = Blueprint("leaves", __name__)


@leaves_bp.route("/")
@login_required
def list_leaves():
    if current_user.role in ("admin", "warden"):
        leaves = Leave.query.order_by(Leave.created_at.desc()).all()
    else:
        student = Student.query.filter_by(user_id=current_user.id).first()
        if not student:
            flash("Please create your profile first.", "warning")
            return redirect(url_for("students.create_profile"))
        leaves = Leave.query.filter_by(student_id=student.id).order_by(Leave.created_at.desc()).all()
    return render_template("leaves/list.html", leaves=leaves)


@leaves_bp.route("/apply", methods=["GET", "POST"])
@login_required
def apply_leave():
    student = Student.query.filter_by(user_id=current_user.id).first()
    if not student and current_user.role not in ("admin", "warden"):
        flash("Please create your profile first.", "warning")
        return redirect(url_for("students.create_profile"))
    if request.method == "POST":
        reason = request.form.get("reason", "").strip()
        from_date_str = request.form.get("from_date", "")
        to_date_str = request.form.get("to_date", "")
        student_id = student.id if student else int(request.form.get("student_id", 0))
        try:
            from_date = datetime.strptime(from_date_str, "%Y-%m-%d").date()
            to_date = datetime.strptime(to_date_str, "%Y-%m-%d").date()
        except ValueError:
            flash("Invalid date format.", "danger")
            return render_template("leaves/form.html", student=student)
        if to_date < from_date:
            flash("End date cannot be before start date.", "danger")
            return render_template("leaves/form.html", student=student)
        leave = Leave(
            student_id=student_id,
            reason=reason,
            from_date=from_date,
            to_date=to_date,
        )
        db.session.add(leave)
        db.session.commit()
        flash("Leave application submitted.", "success")
        return redirect(url_for("leaves.list_leaves"))
    students = Student.query.all() if current_user.role in ("admin", "warden") else None
    return render_template("leaves/form.html", student=student, students=students)


@leaves_bp.route("/<int:leave_id>/review", methods=["POST"])
@login_required
def review_leave(leave_id):
    if current_user.role not in ("admin", "warden"):
        flash("Access denied.", "danger")
        return redirect(url_for("leaves.list_leaves"))
    leave = Leave.query.get_or_404(leave_id)
    action = request.form.get("action")
    remarks = request.form.get("remarks", "").strip()
    if action in ("approved", "rejected"):
        leave.status = action
        leave.reviewed_at = datetime.now(timezone.utc)
        leave.remarks = remarks
        db.session.commit()
        flash(f"Leave {action}.", "success")
    return redirect(url_for("leaves.list_leaves"))
