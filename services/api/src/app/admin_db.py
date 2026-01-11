from pathlib import Path
from app.db import get_conn

# /var/task/app/admin_db.py -> parents[1] == /var/task
BASE = Path(__file__).resolve().parents[1] / "db"

def apply_sql(filename: str) -> None:
    sql = (BASE / filename).read_text()
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()

def apply_all() -> None:
    apply_sql("schema.sql")
    apply_sql("seed.sql")
