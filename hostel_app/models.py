from datetime import datetime, timezone

from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from hostel_app import db


def _now():
    return datetime.now(timezone.utc)


class User(UserMixin, db.Model):
    __tablename__ = "users"
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    role = db.Column(db.String(20), nullable=False, default="student")  # admin, warden, student
    created_at = db.Column(db.DateTime, default=_now)

    student = db.relationship("Student", back_populates="user", uselist=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def __repr__(self):
        return f"<User {self.username}>"


class Room(db.Model):
    __tablename__ = "rooms"
    id = db.Column(db.Integer, primary_key=True)
    room_number = db.Column(db.String(20), unique=True, nullable=False)
    room_type = db.Column(db.String(20), nullable=False)  # single, double, triple
    capacity = db.Column(db.Integer, nullable=False, default=1)
    floor = db.Column(db.Integer, nullable=False, default=1)
    is_available = db.Column(db.Boolean, default=True)
    monthly_fee = db.Column(db.Float, nullable=False, default=0.0)
    created_at = db.Column(db.DateTime, default=_now)

    students = db.relationship("Student", back_populates="room")

    @property
    def occupancy(self):
        return len(self.students)

    @property
    def available_beds(self):
        return self.capacity - self.occupancy

    def __repr__(self):
        return f"<Room {self.room_number}>"


class Student(db.Model):
    __tablename__ = "students"
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), unique=True)
    student_id = db.Column(db.String(20), unique=True, nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    phone = db.Column(db.String(20))
    address = db.Column(db.String(200))
    course = db.Column(db.String(100))
    year = db.Column(db.Integer)
    room_id = db.Column(db.Integer, db.ForeignKey("rooms.id"), nullable=True)
    admission_date = db.Column(db.Date, default=_now)
    created_at = db.Column(db.DateTime, default=_now)

    user = db.relationship("User", back_populates="student")
    room = db.relationship("Room", back_populates="students")
    complaints = db.relationship("Complaint", back_populates="student")
    fees = db.relationship("Fee", back_populates="student")
    leaves = db.relationship("Leave", back_populates="student")

    def __repr__(self):
        return f"<Student {self.student_id} - {self.full_name}>"


class Complaint(db.Model):
    __tablename__ = "complaints"
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey("students.id"), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(50), nullable=False)  # maintenance, cleanliness, food, other
    status = db.Column(db.String(20), default="pending")  # pending, in_progress, resolved
    created_at = db.Column(db.DateTime, default=_now)
    updated_at = db.Column(db.DateTime, default=_now, onupdate=_now)
    resolution = db.Column(db.Text)

    student = db.relationship("Student", back_populates="complaints")

    def __repr__(self):
        return f"<Complaint {self.id} - {self.title}>"


class Fee(db.Model):
    __tablename__ = "fees"
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey("students.id"), nullable=False)
    amount = db.Column(db.Float, nullable=False)
    fee_type = db.Column(db.String(50), nullable=False)  # monthly, annual, security_deposit
    month = db.Column(db.String(20))  # e.g., "April 2025"
    status = db.Column(db.String(20), default="pending")  # pending, paid, overdue
    due_date = db.Column(db.Date)
    paid_date = db.Column(db.Date)
    created_at = db.Column(db.DateTime, default=_now)

    student = db.relationship("Student", back_populates="fees")

    def __repr__(self):
        return f"<Fee {self.id} - {self.student_id} - {self.amount}>"


class Leave(db.Model):
    __tablename__ = "leaves"
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey("students.id"), nullable=False)
    reason = db.Column(db.Text, nullable=False)
    from_date = db.Column(db.Date, nullable=False)
    to_date = db.Column(db.Date, nullable=False)
    status = db.Column(db.String(20), default="pending")  # pending, approved, rejected
    created_at = db.Column(db.DateTime, default=_now)
    reviewed_at = db.Column(db.DateTime)
    remarks = db.Column(db.Text)

    student = db.relationship("Student", back_populates="leaves")

    def __repr__(self):
        return f"<Leave {self.id} - {self.student_id}>"
