import os
from pathlib import Path
from app.db import get_conn

def main():
    sql_file = os.environ["SQL_FILE"]
    sql = Path(sql_file).read_text()
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
    print(f"Applied {sql_file}")

if __name__ == "__main__":
    main()
