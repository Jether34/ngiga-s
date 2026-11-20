"""Write the current SQLite rows as SQL for import into the MySQL schema."""
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

default_db = Path(__file__).resolve().parents[1] / "laboratory.db"
source = sqlite3.connect(sys.argv[1] if len(sys.argv) > 1 else default_db)
source.row_factory = sqlite3.Row
output = open(sys.argv[2], "w", encoding="utf-8", newline="\n") if len(sys.argv) > 2 else sys.stdout


def sql_value(value):
    if value is None:
        return "NULL"
    if isinstance(value, str):
        return "'" + value.replace("\\", "\\\\").replace("'", "''").replace("\0", "") + "'"
    return str(value)


def normalize_time(value):
    if value is None:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed.strftime("%Y-%m-%d %H:%M:%S.%f")


tables = {
    "users": ["id", "email", "password_hash", "name", "account_id", "role"],
    "equipment": ["id", "name", "category", "min_stock"],
    "units": ["id", "equipment_id", "serial", "status"],
    "loans": ["id", "user_id", "unit_id", "borrowed_at", "due_at", "returned_at", "status"],
    "receipts": ["loan_id", "receipt_number", "created_at"],
    "transactions": ["id", "equipment_id", "unit_id", "loan_id", "type", "quantity", "created_at", "actor_id", "idempotency_key"],
}
time_columns = {"borrowed_at", "due_at", "returned_at", "created_at"}
print("USE `stockroom`;", file=output)
print("SET FOREIGN_KEY_CHECKS=0;", file=output)
for table, columns in tables.items():
    print(f"DELETE FROM `{table}`;", file=output)
    for row in source.execute(f"SELECT {','.join(columns)} FROM `{table}`"):
        values = [normalize_time(row[col]) if col in time_columns else row[col] for col in columns]
        names = ", ".join(f"`{name}`" for name in columns)
        encoded = ", ".join(sql_value(value) for value in values)
        print(f"INSERT INTO `{table}` ({names}) VALUES ({encoded});", file=output)
print("SET FOREIGN_KEY_CHECKS=1;", file=output)
if output is not sys.stdout:
    output.close()
