import pyarrow.parquet as pq
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "yellow_tripdata_2024-06.parquet"
schema = pq.read_schema(path)
print("=== Schema ===")
print(schema)
table = pq.read_table(path, columns=schema.name[:5])
print("\n=== Schema rows (first 3) ===")
print(table.slice(0,3).to_pandas())