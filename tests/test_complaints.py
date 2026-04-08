from tests.conftest import login
from hostel_app import db
from hostel_app.models import Student, Complaint


def _setup_student(app, client):
    """Create a student record directly in the DB for use in tests."""
    with app.app_context():
        s = Student(
            student_id="CS001",
            full_name="Test Student",
            email="teststudent@example.com",
        )
        db.session.add(s)
        db.session.commit()
        return s.id


class TestComplaints:
    def test_admin_can_view_all_complaints(self, client, admin_user, app):
        login(client, "admin", "admin123")
        resp = client.get("/complaints/")
        assert resp.status_code == 200

    def test_admin_can_submit_complaint(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app, client)
        resp = client.post(
            "/complaints/new",
            data={
                "student_id": str(sid),
                "title": "Broken Tap",
                "category": "maintenance",
                "description": "The tap in bathroom is broken.",
            },
            follow_redirects=True,
        )
        assert b"submitted" in resp.data

    def test_update_complaint_status(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app, client)
        # Create complaint
        client.post(
            "/complaints/new",
            data={
                "student_id": str(sid),
                "title": "Noisy Room",
                "category": "other",
                "description": "Too noisy.",
            },
            follow_redirects=True,
        )
        with app.app_context():
            complaint = Complaint.query.first()
            cid = complaint.id
        resp = client.post(
            f"/complaints/{cid}/update",
            data={"status": "resolved", "resolution": "Fixed it."},
            follow_redirects=True,
        )
        assert b"updated" in resp.data

    def test_view_complaint(self, client, admin_user, app):
        login(client, "admin", "admin123")
        sid = _setup_student(app, client)
        client.post(
            "/complaints/new",
            data={
                "student_id": str(sid),
                "title": "Light not working",
                "category": "maintenance",
                "description": "Light in corridor is off.",
            },
            follow_redirects=True,
        )
        with app.app_context():
            complaint = Complaint.query.first()
            cid = complaint.id
        resp = client.get(f"/complaints/{cid}")
        assert b"Light not working" in resp.data
