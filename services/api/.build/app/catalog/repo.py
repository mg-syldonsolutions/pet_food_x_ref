from app.db import get_conn


def list_products(limit: int = 20):
    sql = """
      SELECT
        p.id, p.slug, p.name, p.species, p.format, p.life_stage, p.is_active,
        b.id AS brand_id, b.slug AS brand_slug, b.name AS brand_name
      FROM products p
      JOIN brands b ON b.id = p.brand_id
      WHERE p.is_active = true
      ORDER BY b.name, p.name
      LIMIT %s
    """
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (limit,))
            rows = cur.fetchall()

    items = []
    for r in rows:
        items.append({
            "id": str(r[0]),
            "slug": r[1],
            "name": r[2],
            "species": r[3],
            "format": r[4],
            "life_stage": r[5],
            "is_active": r[6],
            "brand": {
                "id": str(r[7]),
                "slug": r[8],
                "name": r[9],
            },
        })

    return items
