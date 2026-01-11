import json
import os
from typing import Any, Dict, Optional

from app.errors import error_response
from app.observability import get_request_id, log_json, elapsed_ms
from app.symptoms import SYMPTOMS


SERVICE_NAME = os.getenv("SERVICE_NAME", "api")
ENV = os.getenv("ENV", "prod")


def _ok(body: Any, request_id: str, status_code: int = 200) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json",
            "x-request-id": request_id,
        },
        "body": json.dumps(body, ensure_ascii=False),
    }


def _parse_event(event: Dict[str, Any]) -> Dict[str, Any]:
    # REST API Gateway (proxy) shape
    method = event.get("httpMethod") or event.get("requestContext", {}).get("http", {}).get("method")
    path = event.get("path") or event.get("rawPath")
    headers = event.get("headers") or {}
    return {"method": method, "path": path, "headers": headers}


def handle_request(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    method = None
    path = None
    headers: Optional[Dict[str, str]] = None
    try:
        parsed = _parse_event(event)
        # Coerce to strings to avoid AttributeError if event fields are not strings
        method = str(parsed.get("method") or "").upper()
        path = str(parsed.get("path") or "")
        headers = parsed.get("headers") or {}
        request_id = get_request_id(headers, getattr(context, "aws_request_id", "unknown"))

        start = __import__("time").perf_counter()
        log_json(
            "INFO",
            SERVICE_NAME,
            ENV,
            request_id,
            "request_start",
            method=method,
            path=path,
        )

        # Routes
        if method == "GET" and path.endswith("/health"):
            resp = _ok({"status": "ok", "env": ENV, "time": __import__("datetime").datetime.utcnow().isoformat() + "Z"}, request_id)

        elif method == "GET" and path.endswith("/meta/symptoms"):
            resp = _ok({"items": [{"code": c, "label": l} for c, l in SYMPTOMS]}, request_id)

        elif method == "GET" and path.endswith("/db/ping"):
            try:
                from app.db import get_conn
                with get_conn() as conn:
                    with conn.cursor() as cur:
                        cur.execute("SELECT 1;")
                        val = cur.fetchone()[0]
                resp = _ok({"ok": True, "value": val}, request_id)
            except Exception as e:
                resp = error_response(
                    code="DB_UNAVAILABLE",
                    message="Database connectivity check failed.",
                    request_id=request_id,
                    status_code=503,
                    details=[{"field": "db", "issue": str(e)}],
                )

        elif method == "GET" and path.endswith("/catalog/products"):
            from app.catalog.repo import list_products
            items = list_products(limit=20)
            resp = _ok({"items": items, "next_cursor": None}, request_id)

        elif method == "GET" and path.startswith("/catalog/products/"):
            token = path.rstrip("/").split("/catalog/products/", 1)[1]
            if not token:
                resp = error_response(
                    code="BAD_REQUEST",
                    message="Missing product id or slug.",
                    request_id=request_id,
                    status_code=400,
                )
            else:
                from app.catalog.product_detail import get_product_by_id_or_slug
                product = get_product_by_id_or_slug(token)
                if not product:
                    resp = error_response(
                        code="NOT_FOUND",
                        message="Product not found.",
                        request_id=request_id,
                        status_code=404,
                        details=[{"field": "product", "issue": "No product for given id/slug"}],
                    )
                else:
                    resp = _ok(product, request_id)

        elif method == "POST" and path.endswith("/compare"):
            try:
                body = event.get("body") or "{}"
                payload = json.loads(body) if isinstance(body, str) else body
                from app.compare.service import compare_products
                out = compare_products(payload)
                resp = _ok(out, request_id)
            except ValueError as ve:
                resp = error_response(
                    code="BAD_REQUEST",
                    message=str(ve),
                    request_id=request_id,
                    status_code=400,
                )

        elif method == "POST" and path.endswith("/catalog/search"):
            try:
                body = event.get("body") or "{}"
                payload = json.loads(body) if isinstance(body, str) else body

                species = payload.get("species")
                format_ = payload.get("format")
                life_stage = payload.get("life_stage")
                exclude_ids = payload.get("exclude_canonical_ids") or []
                limit = int(payload.get("limit") or 25)

                if not isinstance(exclude_ids, list):
                    raise ValueError("exclude_canonical_ids must be a list")

                from app.catalog.search import search_products
                items = search_products(species, format_, life_stage, exclude_ids, limit=limit)

                resp = _ok({"items": items, "next_cursor": None}, request_id)

            except ValueError as ve:
                resp = error_response(
                    code="BAD_REQUEST",
                    message=str(ve),
                    request_id=request_id,
                    status_code=400,
                )

        elif method == "POST" and path.endswith("/admin/migrate"):
            try:
                admin_key = (headers or {}).get("x-admin-key")
                if admin_key != os.environ.get("ADMIN_KEY"):
                    resp = error_response(
                        code="FORBIDDEN",
                        message="Not authorized.",
                        request_id=request_id,
                        status_code=403,
                    )
                else:
                    from pathlib import Path
                    from app.db import get_conn
                    from app.ingredients.resolve import load_rules, resolve_to_canonical

                    # 1) Apply migration SQL
                    sql = Path("db/migrations/001_add_canonical_id.sql").read_text()
                    with get_conn() as conn:
                        with conn.cursor() as cur:
                            cur.execute(sql)
                        conn.commit()

                    # 2) Backfill canonical_id
                    rules = load_rules()
                    select_sql = """
                        SELECT id::text, raw_text
                        FROM product_ingredient_items
                        WHERE canonical_id IS NULL
                    """
                    update_sql = """
                        UPDATE product_ingredient_items
                        SET canonical_id = %s::uuid
                        WHERE id = %s::uuid
                    """

                    updated = 0
                    with get_conn() as conn:
                        with conn.cursor() as cur:
                            cur.execute(select_sql)
                            rows = cur.fetchall()
                            for item_id, raw_text in rows:
                                matched = resolve_to_canonical(raw_text, rules)
                                if matched:
                                    canonical_id, _ = matched
                                    cur.execute(update_sql, (canonical_id, item_id))
                                    updated += 1
                        conn.commit()

                    resp = _ok({"ok": True, "backfilled": updated}, request_id)

            except Exception as e:
                resp = error_response(
                    code="MIGRATION_FAILED",
                    message=str(e),
                    request_id=request_id,
                    status_code=500,
                )

        else:
            resp = error_response(
                code="NOT_FOUND",
                message="Route not found.",
                request_id=request_id,
                status_code=404,
                details=[{"field": "path", "issue": f"No route for {method} {path}"}],
            )

        log_json(
            "INFO",
            SERVICE_NAME,
            ENV,
            request_id,
            "request_end",
            method=method,
            path=path,
            status=resp.get("statusCode"),
            latency_ms=elapsed_ms(start),
        )
        return resp

    except Exception as e:
        # Try to return a compliant error response even if parsing failed
        rid = "unknown"
        try:
            rid = get_request_id(headers, getattr(context, "aws_request_id", "unknown"))
        except Exception:
            pass

        log_json(
            "ERROR",
            SERVICE_NAME,
            ENV,
            rid,
            "unhandled_exception",
            method=method,
            path=path,
            error_type=type(e).__name__,
            error_message=str(e),
        )
        return error_response(
            code="INTERNAL",
            message="Unexpected server error.",
            request_id=rid,
            status_code=500,
        )
