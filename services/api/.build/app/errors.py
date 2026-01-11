from typing import Any, Dict, List, Optional


def error_response(code: str, message: str, request_id: str, status_code: int = 400,
                   details: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
    body = {
        "error": {
            "code": code,
            "message": message,
            "request_id": request_id,
        }
    }
    if details:
        body["error"]["details"] = details

    return {
        "statusCode": status_code,
        "headers": {
            "content-type": "application/json",
            "x-request-id": request_id,
        },
        "body": __import__("json").dumps(body, ensure_ascii=False),
    }
