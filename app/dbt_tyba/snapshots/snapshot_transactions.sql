{% snapshot snapshot_transactions %}

{{
    config(
      target_schema='snapshots',
      unique_key='id_cliente',
      strategy='check',
      check_cols=['row_hash'],
      invalidate_hard_deletes=True
    )
}}

-- Cómo resuelve esto cada situación del enunciado:
--   * Registro nuevo:      id no existía en el snapshot -> dbt inserta primera versión
--   * Registro corregido:  cambia row_hash -> dbt cierra la versión anterior
--                           (dbt_valid_to) y abre una nueva (dbt_valid_from)
--   * Registro eliminado:  id existía antes y ya no aparece en este corte ->
--                           invalidate_hard_deletes cierra la fila y la marca
--                           dbt_is_deleted = true
--   * Sin cambios:         mismo row_hash -> dbt no toca la fila
--
-- Nota: este snapshot se corre una vez POR CORTE (ver src/run_pipeline.py),
-- así el "estado actual" contra el que compara siempre es exactamente el
-- corte inmediatamente anterior.

with ranked as (
    select
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
        _loaded_at,
        row_number() over (partition by id_cliente order by _loaded_at desc) as _rn
    from {{ ref('stg_transactions') }}
)

-- Postgres no soporta QUALIFY (a diferencia de Snowflake/DuckDB/BigQuery),
-- por eso el filtro de "versión más reciente por id" va en un CTE aparte.
select
    id_cliente, movement_date, product, amount, description, fund, type,
    commercial_name, row_hash, _source_file, _batch_id, _loaded_at
from ranked
where _rn = 1

{% endsnapshot %}
