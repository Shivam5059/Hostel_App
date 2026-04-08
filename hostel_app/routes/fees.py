from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from datetime import date, datetime
from hostel_app import db
from hostel_app.models import Fee, Student

fees_bp = Blueprint("fees", __name__)


def admin_required(f):
    from functools import wraps

    @wraps(f)
    def decorated(*args, **kwargs):
        if current_user.role not in ("admin", "warden"):
            flash("Access denied.", "danger")
            return redirect(url_for("main.dashboard"))
        return f(*args, **kwargs)

    return decorated


@fees_bp.route("/")
@login_required
def list_fees():
    if current_user.role in ("admin", "warden"):
        fees = Fee.query.order_by(Fee.created_at.desc()).all()
    else:
        student = Student.query.filter_by(user_id=current_user.id).first()
        if not student:
            flash("Please create your profile first.", "warning")
            return redirect(url_for("students.create_profile"))
        fees = Fee.query.filter_by(student_id=student.id).order_by(Fee.created_at.desc()).all()
    return render_template("fees/list.html", fees=fees)


@fees_bp.route("/add", methods=["GET", "POST"])
@login_required
@admin_required
def add_fee():
    students = Student.query.order_by(Student.full_name).all()
    if request.method == "POST":
        student_id = request.form.get("student_id")
        amount = request.form.get("amount", "0")
        fee_type = request.form.get("fee_type", "monthly")
        month = request.form.get("month", "").strip()
        due_date_str = request.form.get("due_date", "")
        due_date = datetime.strptime(due_date_str, "%Y-%m-%d").date() if due_date_str else None

        fee = Fee(
            student_id=int(student_id),
            amount=float(amount),
            fee_type=fee_type,
            month=month,
            status="pending",
            due_date=due_date,
        )
        db.session.add(fee)
        db.session.commit()
        flash("Fee record added.", "success")
        return redirect(url_for("fees.list_fees"))
    return render_template("fees/form.html", students=students)


@fees_bp.route("/<int:fee_id>/mark_paid", methods=["POST"])
@login_required
@admin_required
def mark_paid(fee_id):
    fee = Fee.query.get_or_404(fee_id)
    fee.status = "paid"
    fee.paid_date = date.today()
    db.session.commit()
    flash("Fee marked as paid.", "success")
    return redirect(url_for("fees.list_fees"))


@fees_bp.route("/<int:fee_id>/delete", methods=["POST"])
@login_required
@admin_required
def delete_fee(fee_id):
    fee = Fee.query.get_or_404(fee_id)
    db.session.delete(fee)
    db.session.commit()
    flash("Fee record deleted.", "success")
    return redirect(url_for("fees.list_fees"))
