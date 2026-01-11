import json
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Tuple, Optional


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def get_request_id(headers: Optional[Dict[str, str]], aws_request_id: str) -> str:
    headers = headers or {}
    rid = headers.get("x-request-id") or headers.get("X-Request-Id") or headers.get("X-REQUEST-ID")
    if rid:
        return rid
    # Fall back to Lambda request id for correlation if client did not send one
    return str(uuid.UUID(aws_request_id.replace("-", "")[:32])) if _looks_like_uuidish(aws_request_id) else aws_request_id


def _looks_like_uuidish(s: str) -> bool:
    # Best-effort: context.aws_request_id is already UUID-like, but keep safe.
    return len(s) >= 32


def log_json(level: str, service: str, env: str, request_id: str, message: str, **fields: Any) -> None:
    payload = {
        "timestamp": now_iso(),
        "level": level,
        "service": service,
        "env": env,
        "request_id": request_id,
        "message": message,
        **fields,
    }
    print(json.dumps(payload, ensure_ascii=False))


def timed() -> Tuple[float, float]:
    start = time.perf_counter()
    return start, start


def elapsed_ms(start: float) -> int:
    return int((time.perf_counter() - start) * 1000)
