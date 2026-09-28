-- Active: 1790548526819@@postgres@5432@tyba
-- Foto del estado vigente: una fila por id, la versión más reciente que no
-- ha sido cerrada ni marcada como eliminada.

select
    id_cliente,
    movement_date,
    product,
    amount,
    description,
    fund,
    type,
    commercial_name,
    dbt_valid_from as valid_from,
    dbt_updated_at as last_updated_at
from {{ ref('snapshot_transactions') }}
where dbt_valid_to is null
