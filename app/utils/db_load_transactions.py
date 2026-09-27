import io
import uuid
from datetime import datetime, timezone
import polars as pl


RAW_COLUMNS = [
    "id",
    "date",
    "product",
    "amount",
    "description",
    "fund",
    "type",
    "commercial_name",
]


def is_already_processed(conn, filename: str) -> bool:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM raw._processed_files WHERE filename = %s;",
            (filename,),
        )
        return cur.fetchone() is not None


def load_parquet_file(conn, file_path: str, filename: str) -> int:
    # Leer Parquet directamente con Polars
    df = pl.read_parquet(file_path)

    # Crear columnas faltantes
    missing_columns = [
        col for col in RAW_COLUMNS
        if col not in df.columns
    ]

    if missing_columns:
        df = df.with_columns(
            [
                pl.lit(None).alias(col)
                for col in missing_columns
            ]
        )

    # Mantener únicamente las columnas esperadas
    df = df.select(RAW_COLUMNS)

    batch_id = str(uuid.uuid4())
    loaded_at = datetime.now(timezone.utc)

    # Agregar metadata
    df = df.with_columns(
        [
            pl.lit(filename).alias("_source_file"),
            pl.lit(batch_id).alias("_batch_id"),
            pl.lit(loaded_at).alias("_loaded_at"),
        ]
    )

    # Todo a String para COPY
    df = df.cast(pl.String)

    # Convertir a TSV en memoria
    buffer = io.StringIO()

    buffer.write(
        df.write_csv(
            separator="\t",
            include_header=False,
            null_value="",
        )
    )

    buffer.seek(0)

    with conn.cursor() as cur:
        cur.copy_expert(
            """
            COPY raw.transactions (
                id_cliente,
                date,
                product,
                amount,
                description,
                fund,
                type,
                commercial_name,
                _source_file,
                _batch_id,
                _loaded_at
            )
            FROM STDIN WITH (
                FORMAT csv,
                DELIMITER E'\\t',
                NULL ''
            )
            """,
            buffer,
        )

        cur.execute(
            """
            INSERT INTO raw._processed_files (
                filename,
                batch_id,
                processed_at,
                row_count
            )
            VALUES (%s, %s, %s, %s);
            """,
            (
                filename,
                batch_id,
                loaded_at,
                df.height,
            ),
        )

    conn.commit()

    return df.height
