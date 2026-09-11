"""
One-time RDS bootstrap: creates the app's MySQL user with the IAM auth
plugin and grants it access to the app schema.

`iam_database_authentication_enabled = true` on the RDS instance (rds.tf)
only turns the *feature* on — it does not create or configure any MySQL
user to use it. That's this script's job. Idempotent (CREATE USER IF NOT
EXISTS), safe to re-run. Run via SSM Run Command against an app instance,
which already has boto3 + MySQLdb through the running container, and
reads the RDS master secret itself using its own instance role rather
than having the secret passed in from outside.
"""

import json
import os
import sys

import boto3
import MySQLdb

REGION = os.environ["AWS_REGION"]
MASTER_SECRET_ARN = os.environ["MASTER_SECRET_ARN"]
DB_HOST = os.environ["DB_HOST"]
DB_NAME = os.environ["DB_NAME"]
APP_DB_USER = os.environ["APP_DB_USER"]

sm = boto3.client("secretsmanager", region_name=REGION)
secret = json.loads(sm.get_secret_value(SecretId=MASTER_SECRET_ARN)["SecretString"])

conn = MySQLdb.connect(
    host=DB_HOST,
    user=secret["username"],
    passwd=secret["password"],
    db=DB_NAME,
    ssl_mode="REQUIRED",
)
cur = conn.cursor()
cur.execute(
    f"CREATE USER IF NOT EXISTS '{APP_DB_USER}'@'%' "
    "IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS'"
)
cur.execute(f"GRANT ALL PRIVILEGES ON `{DB_NAME}`.* TO '{APP_DB_USER}'@'%'")
cur.execute("FLUSH PRIVILEGES")
conn.commit()
print(f"IAM auth user '{APP_DB_USER}' ready on {DB_NAME}")
sys.exit(0)
