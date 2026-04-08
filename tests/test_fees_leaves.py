from tests.conftest import login
from hostel_app import db
from hostel_app.models import Student, Fee, Leave


def _setup_student(app):
    with app.app_context():
        s = Student(
            student_id="FS001",
            full_name="Fee Student",
            email="feestudent@example.com",
        )
        db.session.add(s)
        db.session.commit()
        return s.id


class TestFees:
    def test_add_fee(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app)
        resp = client.post(
            "/fees/add",
            data={
                "student_id": str(sid),
                "amount": "5000",
                "fee_type": "monthly",
                "month": "April 2025",
                "due_date": "2025-04-30",
            },
            follow_redirects=True,
        )
        assert b"added" in resp.data

    def test_mark_paid(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app)
        client.post(
            "/fees/add",
            data={
                "student_id": str(sid),
                "amount": "5000",
                "fee_type": "monthly",
                "month": "May 2025",
                "due_date": "2025-05-31",
            },
            follow_redirects=True,
        )
        with app.app_context():
            fee = Fee.query.first()
            fid = fee.id
        resp = client.post(f"/fees/{fid}/mark_paid", follow_redirects=True)
        assert b"paid" in resp.data

    def test_delete_fee(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app)
        client.post(
            "/fees/add",
            data={
                "student_id": str(sid),
                "amount": "500",
                "fee_type": "other",
                "month": "",
                "due_date": "",
            },
            follow_redirects=True,
        )
        with app.app_context():
            fee = Fee.query.first()
            fid = fee.id
        resp = client.post(f"/fees/{fid}/delete", follow_redirects=True)
        assert b"deleted" in resp.data


class TestLeaves:
    def test_apply_leave_admin(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app)
        resp = client.post(
            "/leaves/apply",
            data={
                "student_id": str(sid),
                "from_date": "2025-05-01",
                "to_date": "2025-05-05",
                "reason": "Family function",
            },
            follow_redirects=True,
        )
        assert b"submitted" in resp.data

    def test_review_leave_approve(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app)
        client.post(
            "/leaves/apply",
            data={
                "student_id": str(sid),
                "from_date": "2025-06-01",
                "to_date": "2025-06-03",
                "reason": "Medical",
            },
            follow_redirects=True,
        )
        with app.app_context():
            leave = Leave.query.first()
            lid = leave.id
        resp = client.post(
            f"/leaves/{lid}/review",
            data={"action": "approved", "remarks": "OK"},
            follow_redirects=True,
        )
        assert b"approved" in resp.data

    def test_leave_invalid_dates(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app)
        resp = client.post(
            "/leaves/apply",
            data={
                "student_id": str(sid),
                "from_date": "2025-05-10",
                "to_date": "2025-05-05",
                "reason": "Bad dates",
            },
            follow_redirects=True,
        )
        assert b"End date cannot be before" in resp.data
