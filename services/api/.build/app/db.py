import json
import os
from functools import lru_cache

import boto3
import psycopg


@lru_cache
def _get_db_secret() -> dict:
    secret_arn = os.environ["DB_SECRET_ARN"]
    client = boto3.client(
        "secretsmanager",
        region_name=os.environ.get("AWS_REGION", "us-west-2"),
    )
    resp = client.get_secret_value(SecretId=secret_arn)
    return json.loads(resp["SecretString"])


def get_conn():
    secret = _get_db_secret()
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=secret["username"],
        password=secret["password"],
        connect_timeout=5,
    )
