# Hostel App

A hostel management web application built with Python (Flask) and SQLite.

## Features

- **Authentication** – Role-based login for admin, warden, and students
- **Student Management** – Add, edit, view, and delete student profiles
- **Room Management** – Track rooms, capacity, occupancy, and fees
- **Complaints** – Students submit complaints; admins update status and add resolutions
- **Fee Management** – Record and track hostel fees; mark payments
- **Leave Management** – Students apply for leave; admins approve or reject

## Tech Stack

| Layer      | Technology               |
|------------|--------------------------|
| Backend    | Python 3, Flask          |
| Database   | SQLite (via SQLAlchemy)  |
| Auth       | Flask-Login              |
| Frontend   | Jinja2 + Bootstrap 5     |
| Tests      | pytest + pytest-flask    |

## Setup

```bash
# 1. Clone the repository
git clone https://github.com/Shivam5059/Hostel_App.git
cd Hostel_App

# 2. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Run the application
python run.py
```

The application will be available at http://127.0.0.1:5000.

**Default admin credentials:** username `admin`, password `admin123`

## Running Tests

```bash
pytest tests/ -v
```

## Project Structure

```
hostel_app/
├── __init__.py          # App factory, extensions
├── config.py            # Configuration (development / testing)
├── models.py            # SQLAlchemy models
├── routes/
│   ├── auth.py          # Login, logout, register
│   ├── main.py          # Dashboard
│   ├── students.py      # Student CRUD
│   ├── rooms.py         # Room CRUD
│   ├── complaints.py    # Complaint management
│   ├── fees.py          # Fee management
│   └── leaves.py        # Leave applications
├── templates/           # Jinja2 HTML templates
└── static/css/          # Custom styles
tests/                   # pytest test suite
run.py                   # Application entry point
requirements.txt         # Python dependencies
```
