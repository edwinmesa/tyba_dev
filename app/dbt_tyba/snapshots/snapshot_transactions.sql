{% snapshot snapshot_transactions %}

{{
    config(
      target_schema='snapshots',
      unique_key='transaction_id',
      strategy='check',
      check_cols=['row_hash'],
      invalidate_hard_deletes=True
    )
}}

-- El snapshot ve SOLO el estado del corte más reciente (el que run_pipeline.py
-- acaba de cargar). Así dbt compara "estado de hoy" contra "estado de ayer":
--   * transaction_id nuevo            -> se inserta su primera versión
--   * mismo transaction_id, otro row_hash (amount/description/commercial_name)
--                                     -> se cierra la versión anterior y se abre otra
--   * transaction_id que estaba y ya no viene en este corte
--                                     -> invalidate_hard_deletes cierra la fila (dbt_valid_to)
--   * mismo row_hash                  -> no se toca
--
-- Si leyera todos los cortes acumulados, una transacción eliminada seguiría
-- apareciendo en la fuente (con los datos del corte viejo) y nunca se detectaría.
--
-- transaction_id es sintético (ver stg_transactions.sql): el parquet no trae
-- un id único por transacción, solo id_cliente (identificador del cliente).
-- stg_transactions ya deduplica por llave de negocio dentro de cada corte.

select
    transaction_id,
    id_cliente,
    movement_date,
    product,
    amount,
    description,
    fund,
    type,
    commercial_name,
    row_hash,
    _source_file,
    _batch_id,
    _loaded_at
from {{ ref('stg_transactions') }}
where _batch_id = (
    select _batch_id
    from {{ ref('stg_transactions') }}
    order by _loaded_at desc
    limit 1
)

{% endsnapshot %}