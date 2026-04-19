from db import query_db, execute_db
import json

# =================================================================
# 📝 DATABASE QUERY UTILITY
# =================================================================
# Instructions:
# 1. Add your SQL queries to the QUERIES list below.
# 2. Run this file: python db_query.py
# 3. SELECT queries will print results as JSON.
# 4. INSERT/UPDATE/DELETE will print the number of affected rows.
# =================================================================

QUERIES = [
    """
    CREATE TABLE IF NOT EXISTS notice (
      notice_id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      author_id INTEGER,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (author_id) REFERENCES "user"(user_id)
    )
    """
]

def run_queries(queries:list[str]):
    print("=" * 60)
    print("Hostel DB Query Tool")
    print("=" * 60)
    
    for sql in queries:
        sql = sql.strip()
        if not sql: continue
        
        print(f"\nSQL: {sql}")
        try:
            # Try to fetch results first
            results = query_db(sql)
            if results is not None:
                if isinstance(results, list):
                    if results:
                        print(f"Success! Found {len(results)} rows:")
                        print(json.dumps(results, indent=4))
                    else:
                        print("Result: Empty set (0 rows)")
                else:
                    # Case for 'one=True' or other single-row returns
                    print("Success! Single result:")
                    print(json.dumps(results, indent=4))
            else:
                # If no results (maybe it was an EXECUTE query)
                last_id, rowcount = execute_db(sql)
                print(f"Success! Rows affected: {rowcount}")
                if last_id:
                    print(f"Last Insert ID: {last_id}")
        except Exception as e:
            # If query_db fails, it might be an EXECUTE query
            try:
                last_id, rowcount = execute_db(sql)
                print(f"Success! Rows affected: {rowcount}")
                if last_id:
                    print(f"Last Insert ID: {last_id}")
            except Exception as e2:
                print(f"Database Error: {e2}")
    
    print("\n" + "=" * 60)
    print("Execution Finished")
    print("=" * 60)

if __name__ == "__main__":
    run_queries(QUERIES)
