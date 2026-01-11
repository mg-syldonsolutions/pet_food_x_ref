import json
import re
from collections import defaultdict
from typing import Dict, List, Tuple, Any

from app.db import get_conn

UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)

def _norm(s: str) -> str:
    return " ".join(s.strip().lower().split())

def _fetch_products(tokens: List[str]) -> List[Dict[str, Any]]:
    # Returns rows with id/slug/name
    by_id = [t for t in tokens if UUID_RE.match(t)]
    by_slug = [t for t in tokens if not UUID_RE.match(t)]

    products: Dict[str, Dict[str, Any]] = {}

    with get_conn() as conn:
        with conn.cursor() as cur:
            if by_id:
                cur.execute(
                    """
                    SELECT id, slug, name
                    FROM products
                    WHERE id = ANY(%s::uuid[])
                    """,
                    (by_id,),
                )
                for r in cur.fetchall():
                    products[str(r[0])] = {"id": str(r[0]), "slug": r[1], "name": r[2], "token": str(r[0])}

            if by_slug:
                cur.execute(
                    """
                    SELECT id, slug, name
                    FROM products
                    WHERE slug = ANY(%s)
                    """,
                    (by_slug,),
                )
                for r in cur.fetchall():
                    products[r[1]] = {"id": str(r[0]), "slug": r[1], "name": r[2], "token": r[1]}

    # Preserve input order; drop unknowns
    ordered = []
    for t in tokens:
        if t in products:
            ordered.append(products[t])
        else:
            # if token was uuid, key is uuid string; if slug, key is slug
            if UUID_RE.match(t) and t in products:
                ordered.append(products[t])
    return ordered

def _fetch_latest_ingredient_items(product_ids: List[str], include_trace: bool, include_may_contain: bool) -> Dict[str, List[str]]:
    """
    Returns: {product_id: [raw_text...]} using latest ingredient_list version
    """
    # Filter trace/may_contain based on flags
    clauses = []
    if not include_trace:
        clauses.append("pi.is_trace = false")
    if not include_may_contain:
        clauses.append("pi.is_may_contain = false")
    where_extra = (" AND " + " AND ".join(clauses)) if clauses else ""

    sql = f"""
      WITH latest AS (
        SELECT DISTINCT ON (product_id)
          product_id, id AS ingredient_list_id
        FROM product_ingredient_lists
        WHERE product_id = ANY(%s::uuid[])
        ORDER BY product_id, version DESC
      )
      SELECT
        l.product_id,
        pi.raw_text
      FROM latest l
      JOIN product_ingredient_items pi ON pi.ingredient_list_id = l.ingredient_list_id
      WHERE 1=1 {where_extra}
      ORDER BY l.product_id, pi.order_index ASC
    """

    out: Dict[str, List[str]] = defaultdict(list)
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, (product_ids,))
            for product_id, raw_text in cur.fetchall():
                out[str(product_id)].append(raw_text)
    return out

def compare_products(payload: Dict[str, Any]) -> Dict[str, Any]:
    tokens = payload.get("product_tokens") or []
    if not isinstance(tokens, list) or len(tokens) < 2:
        raise ValueError("product_tokens must be a list with at least 2 items")

    mode = payload.get("mode") or "raw"
    if mode not in ("raw", "canonical"):
        raise ValueError("mode must be one of: raw, canonical")


    include_trace = bool(payload.get("include_trace", False))
    include_may_contain = bool(payload.get("include_may_contain", False))

    products = _fetch_products(tokens)
    if len(products) < 2:
        raise ValueError("At least 2 valid products are required")

    product_ids = [p["id"] for p in products]
    items_by_product = _fetch_latest_ingredient_items(product_ids, include_trace, include_may_contain)

    rules = None
    if mode == "canonical":
        from app.ingredients.resolve import load_rules, resolve_to_canonical, norm as norm_ing
        rules = load_rules()

    # Build presence counts on normalized ingredient text
    counts: Dict[str, int] = defaultdict(int)
    display: Dict[str, str] = {}

    for pid in product_ids:
        seen = set()
        for raw in items_by_product.get(pid, []):
            raw_clean = raw.strip()
            if not raw_clean:
                continue

            if mode == "raw":
                key = _norm(raw_clean)
                disp = raw_clean

            else:
                matched = resolve_to_canonical(raw_clean, rules)
                if matched:
                    canonical_id, canonical_name = matched
                    key = canonical_id
                    disp = canonical_name
                else:
                    key = "raw:" + norm_ing(raw_clean)
                    disp = f"(unmapped) {raw_clean}"

            if key not in seen:
                seen.add(key)
                counts[key] += 1
                display.setdefault(key, disp)


    total = len(product_ids)

    scored = []
    for k, c in counts.items():
        scored.append({
            "ingredient": display.get(k, k),
            "ingredient_key": k,
            "in_count": c,
            "percent": round(c / total, 4),
        })


    in_all = sorted([x for x in scored if x["in_count"] == total], key=lambda x: x["ingredient"].lower())
    in_some = sorted([x for x in scored if 0 < x["in_count"] < total], key=lambda x: (-x["in_count"], x["ingredient"].lower()))

    return {
        "product_count": total,
        "products": products,
        "in_all": in_all,
        "in_some": in_some,
        "notes": {
            "mode": mode,
            "normalization": "trim+lower+collapse_spaces",
            "trace_included": include_trace,
            "may_contain_included": include_may_contain,
        },
    }
