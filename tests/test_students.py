from tests.conftest import login
from hostel_app import db
from hostel_app.models import Student


def _create_student(app, client):
    resp = client.post(
        "/students/add",
        data={
            "student_id": "S001",
            "full_name": "Alice Smith",
            "email": "alice@example.com",
            "phone": "9876543210",
            "address": "123 Main St",
            "course": "B.Tech",
            "year": "2",
        },
        follow_redirects=True,
    )
    return resp


class TestStudents:
    def test_add_student(self, client, admin_user, app):
        login(client, "admin", "admin123")
        resp = _create_student(app, client)
        assert resp.status_code == 200
        assert b"Alice Smith" in resp.data

    def test_list_students(self, client, admin_user, app):
        login(client, "admin", "admin123")
        _create_student(app, client)
        resp = client.get("/students/")
        assert resp.status_code == 200
        assert b"Alice Smith" in resp.data

    def test_duplicate_student_id(self, client, admin_user, app):
        login(client, "admin", "admin123")
        _create_student(app, client)
        resp = client.post(
            "/students/add",
            data={
                "student_id": "S001",
                "full_name": "Bob Jones",
                "email": "bob@example.com",
            },
            follow_redirects=True,
        )
        assert b"already exists" in resp.data

    def test_view_student(self, client, admin_user, app):
        login(client, "admin", "admin123")
        _create_student(app, client)
        with app.app_context():
            student = Student.query.filter_by(student_id="S001").first()
            sid = student.id
        resp = client.get(f"/students/{sid}")
        assert b"Alice Smith" in resp.data

    def test_edit_student(self, client, admin_user, app):
        login(client, "admin", "admin123")
        _create_student(app, client)
        with app.app_context():
            student = Student.query.filter_by(student_id="S001").first()
            sid = student.id
        resp = client.post(
            f"/students/{sid}/edit",
            data={
                "full_name": "Alice Johnson",
                "email": "alice@example.com",
                "course": "M.Tech",
                "year": "1",
            },
            follow_redirects=True,
        )
        assert b"updated" in resp.data

    def test_delete_student(self, client, admin_user, app):
        login(client, "admin", "admin123")
        _create_student(app, client)
        with app.app_context():
            student = Student.query.filter_by(student_id="S001").first()
            sid = student.id
        resp = client.post(f"/students/{sid}/delete", follow_redirects=True)
        assert b"deleted" in resp.data

    def test_student_user_cannot_list_students(self, client, student_user):
        login(client, "teststudent", "test1234")
        resp = client.get("/students/", follow_redirects=True)
        assert b"Access denied" in resp.data
