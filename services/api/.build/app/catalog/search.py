from typing import Any, List, Optional
from app.db import get_conn

def search_products(
    species: Optional[str],
    format_: Optional[str],
    life_stage: Optional[str],
    exclude_canonical_ids: List[str],
    limit: int = 25,
):
    where = ["p.is_active = true"]
    params: List[Any] = []

    if species:
        where.append("p.species = %s")
        params.append(species)
    if format_:
        where.append("p.format = %s")
        params.append(format_)
    if life_stage:
        where.append("p.life_stage = %s")
        params.append(life_stage)

    exclude_sql = ""
    if exclude_canonical_ids:
        exclude_sql = """
          AND NOT EXISTS (
            SELECT 1
            FROM product_ingredient_lists il
            JOIN product_ingredient_items pi ON pi.ingredient_list_id = il.id
            WHERE il.product_id = p.id
              AND il.version = (
                SELECT MAX(version)
                FROM product_ingredient_lists
                WHERE product_id = p.id
              )
              AND pi.canonical_id = ANY(%s::uuid[])
          )
        """
        params.append(exclude_canonical_ids)

    sql = f"""
      SELECT
        p.id, p.slug, p.name, p.species, p.format, p.life_stage,
        b.id AS brand_id, b.slug AS brand_slug, b.name AS brand_name
      FROM products p
      JOIN brands b ON b.id = p.brand_id
      WHERE {" AND ".join(where)}
      {exclude_sql}
      ORDER BY b.name, p.name
      LIMIT %s
    """
    params.append(limit)

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, tuple(params))
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
            "brand": {"id": str(r[6]), "slug": r[7], "name": r[8]},
        })

    return items
