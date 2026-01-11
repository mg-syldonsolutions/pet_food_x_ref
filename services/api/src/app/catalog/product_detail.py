import re
from app.db import get_conn

UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)

def get_product_by_id_or_slug(token: str):
    by_id = bool(UUID_RE.match(token))

    sql_product = f"""
      SELECT
        p.id, p.slug, p.name, p.species, p.format, p.life_stage, p.is_active,
        b.id AS brand_id, b.slug AS brand_slug, b.name AS brand_name
      FROM products p
      JOIN brands b ON b.id = p.brand_id
      WHERE {"p.id = %s" if by_id else "p.slug = %s"}
      LIMIT 1
    """

    sql_latest_list = """
      SELECT il.id, il.version, il.effective_date, il.source_type, il.source_ref, il.notes
      FROM product_ingredient_lists il
      WHERE il.product_id = %s
      ORDER BY il.version DESC
      LIMIT 1
    """

    sql_items = """
      SELECT id, raw_text, order_index, is_may_contain, is_trace
      FROM product_ingredient_items
      WHERE ingredient_list_id = %s
      ORDER BY order_index ASC
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql_product, (token,))
            row = cur.fetchone()
            if not row:
                return None

            product_id = row[0]
            product = {
                "id": str(row[0]),
                "slug": row[1],
                "name": row[2],
                "species": row[3],
                "format": row[4],
                "life_stage": row[5],
                "is_active": row[6],
                "brand": {"id": str(row[7]), "slug": row[8], "name": row[9]},
                "ingredient_list": None,
            }

            cur.execute(sql_latest_list, (product_id,))
            il = cur.fetchone()
            if not il:
                return product

            ingredient_list_id = il[0]
            cur.execute(sql_items, (ingredient_list_id,))
            items = cur.fetchall()

            product["ingredient_list"] = {
                "id": str(il[0]),
                "version": il[1],
                "effective_date": il[2].isoformat() if il[2] else None,
                "source_type": il[3],
                "source_ref": il[4],
                "notes": il[5],
                "items": [
                    {
                        "id": str(r[0]),
                        "raw_text": r[1],
                        "order_index": r[2],
                        "is_may_contain": r[3],
                        "is_trace": r[4],
                    }
                    for r in items
                ],
            }

            return product
