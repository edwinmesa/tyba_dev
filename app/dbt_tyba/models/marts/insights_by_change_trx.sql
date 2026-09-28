-- Active: 1790548526819@@postgres@5432@tyba@marts
-- # ¿cómo evolucionaron los datos de un día a otro?
-- # cuántos registros nuevos, corregidos y eliminados hubo en cada corte procesado

select
    _batch_id,
    _source_file,
    event_type,
    count(*) as event_count
from {{ ref('fct_historical_transactions') }}
group by _batch_id, _source_file, event_type
order by _source_file, event_type
