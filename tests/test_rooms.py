from tests.conftest import login


def _create_room(client):
    return client.post(
        "/rooms/add",
        data={
            "room_number": "101",
            "room_type": "single",
            "capacity": "1",
            "floor": "1",
            "monthly_fee": "5000",
        },
        follow_redirects=True,
    )


class TestRooms:
    def test_add_room(self, client, admin_user):
        login(client, "admin", "admin123")
        resp = _create_room(client)
        assert resp.status_code == 200
        assert b"101" in resp.data

    def test_add_duplicate_room(self, client, admin_user):
        login(client, "admin", "admin123")
        _create_room(client)
        resp = _create_room(client)
        assert b"already exists" in resp.data

    def test_list_rooms_requires_login(self, client):
        resp = client.get("/rooms/", follow_redirects=False)
        assert resp.status_code == 302

    def test_edit_room(self, client, admin_user, app):
        from hostel_app.models import Room
        from hostel_app import db

        login(client, "admin", "admin123")
        _create_room(client)
        with app.app_context():
            room = Room.query.filter_by(room_number="101").first()
            room_id = room.id
        resp = client.post(
            f"/rooms/{room_id}/edit",
            data={
                "room_number": "101",
                "room_type": "double",
                "capacity": "2",
                "floor": "1",
                "monthly_fee": "6000",
            },
            follow_redirects=True,
        )
        assert b"updated" in resp.data

    def test_delete_room(self, client, admin_user, app):
        from hostel_app.models import Room

        login(client, "admin", "admin123")
        _create_room(client)
        with app.app_context():
            room = Room.query.filter_by(room_number="101").first()
            room_id = room.id
        resp = client.post(f"/rooms/{room_id}/delete", follow_redirects=True)
        assert b"deleted" in resp.data

    def test_student_cannot_access_rooms(self, client, student_user):
        login(client, "teststudent", "test1234")
        resp = client.get("/rooms/", follow_redirects=True)
        assert b"Access denied" in resp.data
