from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from hostel_app import db
from hostel_app.models import Room

rooms_bp = Blueprint("rooms", __name__)


def admin_required(f):
    from functools import wraps

    @wraps(f)
    def decorated(*args, **kwargs):
        if current_user.role not in ("admin", "warden"):
            flash("Access denied.", "danger")
            return redirect(url_for("main.dashboard"))
        return f(*args, **kwargs)

    return decorated


@rooms_bp.route("/")
@login_required
@admin_required
def list_rooms():
    rooms = Room.query.order_by(Room.room_number).all()
    return render_template("rooms/list.html", rooms=rooms)


@rooms_bp.route("/add", methods=["GET", "POST"])
@login_required
@admin_required
def add_room():
    if request.method == "POST":
        room_number = request.form.get("room_number", "").strip()
        room_type = request.form.get("room_type", "single")
        capacity = request.form.get("capacity", "1")
        floor = request.form.get("floor", "1")
        monthly_fee = request.form.get("monthly_fee", "0")

        if Room.query.filter_by(room_number=room_number).first():
            flash("Room number already exists.", "danger")
            return render_template("rooms/form.html", action="Add", room=None)

        room = Room(
            room_number=room_number,
            room_type=room_type,
            capacity=int(capacity),
            floor=int(floor),
            monthly_fee=float(monthly_fee),
            is_available=True,
        )
        db.session.add(room)
        db.session.commit()
        flash(f"Room {room_number} added successfully.", "success")
        return redirect(url_for("rooms.list_rooms"))
    return render_template("rooms/form.html", action="Add", room=None)


@rooms_bp.route("/<int:room_id>/edit", methods=["GET", "POST"])
@login_required
@admin_required
def edit_room(room_id):
    room = Room.query.get_or_404(room_id)
    if request.method == "POST":
        room.room_number = request.form.get("room_number", "").strip()
        room.room_type = request.form.get("room_type", room.room_type)
        capacity = request.form.get("capacity")
        room.capacity = int(capacity) if capacity else room.capacity
        floor = request.form.get("floor")
        room.floor = int(floor) if floor else room.floor
        monthly_fee = request.form.get("monthly_fee")
        room.monthly_fee = float(monthly_fee) if monthly_fee else room.monthly_fee
        room.is_available = room.available_beds > 0
        db.session.commit()
        flash("Room updated successfully.", "success")
        return redirect(url_for("rooms.list_rooms"))
    return render_template("rooms/form.html", action="Edit", room=room)


@rooms_bp.route("/<int:room_id>/delete", methods=["POST"])
@login_required
@admin_required
def delete_room(room_id):
    room = Room.query.get_or_404(room_id)
    if room.students:
        flash("Cannot delete a room with occupants.", "danger")
        return redirect(url_for("rooms.list_rooms"))
    db.session.delete(room)
    db.session.commit()
    flash("Room deleted.", "success")
    return redirect(url_for("rooms.list_rooms"))


@rooms_bp.route("/<int:room_id>")
@login_required
def view_room(room_id):
    room = Room.query.get_or_404(room_id)
    return render_template("rooms/view.html", room=room)
