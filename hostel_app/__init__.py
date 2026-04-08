from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from hostel_app.config import Config

db = SQLAlchemy()
login_manager = LoginManager()
login_manager.login_view = "auth.login"
login_manager.login_message_category = "warning"


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    login_manager.init_app(app)

    from hostel_app.routes.auth import auth_bp
    from hostel_app.routes.main import main_bp
    from hostel_app.routes.students import students_bp
    from hostel_app.routes.rooms import rooms_bp
    from hostel_app.routes.complaints import complaints_bp
    from hostel_app.routes.fees import fees_bp
    from hostel_app.routes.leaves import leaves_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    app.register_blueprint(students_bp, url_prefix="/students")
    app.register_blueprint(rooms_bp, url_prefix="/rooms")
    app.register_blueprint(complaints_bp, url_prefix="/complaints")
    app.register_blueprint(fees_bp, url_prefix="/fees")
    app.register_blueprint(leaves_bp, url_prefix="/leaves")

    with app.app_context():
        db.create_all()
        _seed_admin(app)

    return app


def _seed_admin(app):
    from hostel_app.models import User

    if not User.query.filter_by(role="admin").first():
        admin = User(
            username="admin",
            email="admin@hostel.com",
            role="admin",
        )
        admin.set_password("admin123")
        db.session.add(admin)
        db.session.commit()


@login_manager.user_loader
def load_user(user_id):
    from hostel_app.models import User

    return db.session.get(User, int(user_id))
