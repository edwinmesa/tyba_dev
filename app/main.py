import os
import psycopg2
import psycopg2.extras
from fastapi import FastAPI, HTTPException


app = FastAPI()


def get_connection():
    return psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ["POSTGRES_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        cursor_factory=psycopg2.extras.RealDictCursor,
    )


def fetch_all(query: str, params: tuple = ()):
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params)
            return cur.fetchall()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/transactions")
def get_transactions(limit: int = 100, offset: int = 0):
    rows = fetch_all(
        """
        SELECT * FROM marts.dim_current_transactions
        ORDER BY id_cliente
        LIMIT %s OFFSET %s;
        """,
        (limit, offset),
    )
    return {"count": len(rows), "results": rows}


@app.get("/transactions_by_client/{id_cliente}")
def obtener_movimiento(id_cliente: str):
    rows = fetch_all(
        "SELECT * FROM marts.dim_current_transactions WHERE id_cliente = %s;",
        (id_cliente,),
    )
    if not rows:
        raise HTTPException(status_code=404,
                            detail="Cliente no encontrado o eliminado")
    return rows


@app.get("/files_processed")
def get_files_processed(limit: int = 100, offset: int = 0):
    rows = fetch_all(
        """
        SELECT * FROM raw._processed_files
        """
    )
    return {"count": len(rows), "results": rows}
