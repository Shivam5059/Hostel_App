from tests.conftest import login, logout


class TestAuth:
    def test_login_page_loads(self, client):
        resp = client.get("/login")
        assert resp.status_code == 200
        assert b"Hostel Manager" in resp.data

    def test_login_success(self, client, admin_user):
        resp = login(client, "admin", "admin123")
        assert resp.status_code == 200
        assert b"Dashboard" in resp.data

    def test_login_wrong_password(self, client, admin_user):
        resp = login(client, "admin", "wrongpassword")
        assert b"Invalid username or password" in resp.data

    def test_login_unknown_user(self, client):
        resp = login(client, "nobody", "pass")
        assert b"Invalid username or password" in resp.data

    def test_logout(self, client, admin_user):
        login(client, "admin", "admin123")
        resp = logout(client)
        assert b"logged out" in resp.data

    def test_register_new_user(self, client):
        resp = client.post(
            "/register",
            data={
                "username": "newuser",
                "email": "newuser@test.com",
                "password": "newpass123",
                "confirm_password": "newpass123",
            },
            follow_redirects=True,
        )
        assert b"Account created" in resp.data

    def test_register_password_mismatch(self, client):
        resp = client.post(
            "/register",
            data={
                "username": "user2",
                "email": "user2@test.com",
                "password": "abc",
                "confirm_password": "xyz",
            },
            follow_redirects=True,
        )
        assert b"Passwords do not match" in resp.data

    def test_register_duplicate_username(self, client, admin_user):
        resp = client.post(
            "/register",
            data={
                "username": "admin",
                "email": "other@test.com",
                "password": "pass123",
                "confirm_password": "pass123",
            },
            follow_redirects=True,
        )
        assert b"Username already taken" in resp.data

    def test_protected_route_redirects(self, client):
        resp = client.get("/dashboard", follow_redirects=False)
        assert resp.status_code == 302

    def test_register_page_loads(self, client):
        resp = client.get("/register")
        assert resp.status_code == 200
        assert b"Create Account" in resp.data
