import pytest
from hostel_app import create_app, db
from hostel_app.config import TestingConfig


@pytest.fixture
def app():
    app = create_app(TestingConfig)
    with app.app_context():
        db.create_all()
        yield app
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def admin_user(app):
    from hostel_app.models import User

    with app.app_context():
        user = User.query.filter_by(username="admin").first()
        if not user:
            user = User(username="admin", email="admin@hostel.com", role="admin")
            user.set_password("admin123")
            db.session.add(user)
            db.session.commit()
        return user


@pytest.fixture
def student_user(app):
    from hostel_app.models import User

    with app.app_context():
        user = User(username="teststudent", email="teststudent@example.com", role="student")
        user.set_password("test1234")
        db.session.add(user)
        db.session.commit()
        return user


def login(client, username, password):
    return client.post(
        "/login",
        data={"username": username, "password": password},
        follow_redirects=True,
    )


def logout(client):
    return client.get("/logout", follow_redirects=True)
