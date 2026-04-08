PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS "user" (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  email TEXT UNIQUE,
  phone TEXT,
  password TEXT,
  role TEXT CHECK (role IN ('ADMIN','RECTOR','WARDEN','COUNSELOR','STUDENT','PARENT')),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hostel (
  hostel_id INTEGER PRIMARY KEY AUTOINCREMENT,
  hostel_name TEXT,
  warden_id INTEGER
);

CREATE TABLE IF NOT EXISTS room (
  room_id INTEGER PRIMARY KEY AUTOINCREMENT,
  hostel_id INTEGER,
  room_number TEXT,
  capacity INTEGER,
  FOREIGN KEY (hostel_id) REFERENCES hostel(hostel_id)
);

CREATE TABLE IF NOT EXISTS student (
  student_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  roll_no TEXT,
  counselor_id INTEGER,
  parent_id INTEGER,
  hostel_id INTEGER,
  room_id INTEGER,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id),
  FOREIGN KEY (room_id) REFERENCES room(room_id)
);

CREATE TABLE IF NOT EXISTS leave_request (
  leave_id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER,
  from_date TEXT,
  to_date TEXT,
  reason TEXT,
  parent_approved INTEGER DEFAULT 0,
  counselor_approved INTEGER DEFAULT 0,
  warden_approved INTEGER DEFAULT 0,
  status TEXT CHECK (status IN ('PENDING','APPROVED','REJECTED')) DEFAULT 'PENDING',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES student(student_id)
);

CREATE TABLE IF NOT EXISTS attendance (
  attendance_id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL,
  warden_id INTEGER NOT NULL,
  attendance_date TEXT NOT NULL,
  status TEXT CHECK (status IN ('PRESENT','ABSENT')) NOT NULL,
  marked_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (warden_id) REFERENCES "user"(user_id),
  UNIQUE (student_id, attendance_date)
);

CREATE TABLE IF NOT EXISTS complaint(
  complaint_id  INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id    INTEGER NOT NULL,                          -- FK to student table
  description   TEXT NOT NULL,
  status        TEXT CHECK (status IN ('PENDING','RESOLVED','REJECTED')) DEFAULT 'PENDING',
  rector_id     INTEGER,                                   -- FK to user (rector who acted)
  register_date TEXT DEFAULT CURRENT_TIMESTAMP,
  end_date      TEXT,                                      -- set when RESOLVED or REJECTED
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (rector_id)  REFERENCES "user"(user_id)
);

CREATE TABLE IF NOT EXISTS room_transfer_requests(
  request_id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL,
  current_room_id INTEGER,
  requested_room_id INTEGER NOT NULL,
  reason TEXT NOT NULL,
  status TEXT CHECK (status IN ('PENDING','APPROVED','REJECTED')) DEFAULT 'PENDING',
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (current_room_id) REFERENCES room(room_id),
  FOREIGN KEY (requested_room_id) REFERENCES room(room_id)
);
