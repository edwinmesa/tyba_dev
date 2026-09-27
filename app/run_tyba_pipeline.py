import os
import sys
from pathlib import Path
from utils.db_connection import get_connection
from utils.dbt_tasks import run_dbt_snapshot
from utils.db_load_transactions import is_already_processed, load_parquet_file


RAW_DATA_PATH = Path(os.environ.get("RAW_DATA_PATH", "/app/data/raw"))


def main() -> None:
    # Get all parquet files in the RAW_DATA_PATH
    files = sorted(RAW_DATA_PATH.glob("*.parquet"))
    if not files:
        print(f">> No se encontraron archivos parquet en {RAW_DATA_PATH}.")
        sys.exit(0)

    # Open a database connection
    conn = get_connection()
    # Check which files have already been processed
    pending = [f for f in files if not is_already_processed(conn, f.name)]

    if not pending:
        print("Todos los cortes ya fueron procesados anteriormente.")
        conn.close()
        return
    # Show files that are pending processing
    print(f"Cortes pendientes a procesar: {[f.name for f in pending]}")

    # Process each pending file
    for file_path in pending:
        print(f">> Cargando corte: {file_path.name}")
        n_rows = load_parquet_file(conn, str(file_path), file_path.name)
        print(f"   {n_rows} filas cargadas a raw.transactions.")

        # Run dbt snapshot after loading the file
        print(f">> Ejecutando dbt snapshot tras cargar {file_path.name}...")
        run_dbt_snapshot()

    conn.close()
    print("Todos los cortes fueron procesados y snapshoteados correctamente.")


if __name__ == "__main__":
    main()
