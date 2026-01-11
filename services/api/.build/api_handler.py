import json
from app.main import handle_request


def lambda_handler(event, context):
    return handle_request(event, context)
