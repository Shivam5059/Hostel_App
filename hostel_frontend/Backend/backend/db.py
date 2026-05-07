import sqlite3
import os

# Connecting to the sqlite database in the same directory
DB_PATH = os.path.join(os.path.dirname(__file__), "hostel_management.sqlite")

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row  # This enables column access by name: row['column_name']
    conn.execute("PRAGMA foreign_keys = ON")
    
    # Ensure gate_log table exists for Raspberry Pi face recognition
    conn.execute('''
        CREATE TABLE IF NOT EXISTS gate_log (
            log_id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER,
            event_type TEXT CHECK (event_type IN ('entry', 'exit')),
            confidence REAL,
            log_time TEXT,
            FOREIGN KEY (student_id) REFERENCES student(student_id)
        )
    ''')
    conn.commit()
    return conn

def query_db(query, args=(), one=False):
    """
    Query the database and return results as a list of dictionaries.
    """
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute(query, args)
        rv = c.fetchall()
        # Convert sqlite3.Row to standard dicts
        res = [dict(row) for row in rv]
        return (res[0] if res else None) if one else res
    except Exception as e:
        print(f"Database Query Error: {e}")
        raise e
    finally:
        c.close()
        conn.close()

def execute_db(query, args=()):
    """
    Execute a query that modifies the database (INSERT, UPDATE, DELETE).
    Returns the lastrowid and rowcount.
    """
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.execute(query, args)
        conn.commit()
        return c.lastrowid, c.rowcount
    except Exception as e:
        conn.rollback()
        print(f"Database Execute Error: {e}")
        raise e
    finally:
        c.close()
        conn.close()

def execute_many_db(query, args_list=()):
    """
    Execute a query for multiple rows that modifies the database.
    """
    conn = get_db_connection()
    c = conn.cursor()
    try:
        c.executemany(query, args_list)
        conn.commit()
        return c.rowcount
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        c.close()
        conn.close()
