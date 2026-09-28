-- Active: 1790548526819@@postgres@5432@tyba
-- Histórico completo (todas las versiones de todos los ids) con una
-- clasificación explícita del tipo de evento, para auditoría y para las
-- consultas de "insights" (cuántos registros nuevos/corregidos/eliminados
-- hubo entre cada par de cortes).

-- Histórico completo (todas las versiones de todos los ids) con una
-- clasificación explícita del tipo de evento, para auditoría y para las
-- consultas de "insights" (cuántos registros nuevos/corregidos/eliminados
-- hubo entre cada par de cortes).
--
-- Nota: dbt solo agrega la columna dbt_is_deleted al snapshot a partir de
-- la SEGUNDA corrida de `dbt snapshot` (la primera vez no hay nada contra
-- qué comparar para detectar eliminaciones). Este modelo lo detecta en
-- tiempo de compilación para no romperse si solo se ha procesado un corte.

{% set snapshot_relation = ref('snapshot_transactions') %}
{% set snapshot_columns = adapter.get_columns_in_relation(snapshot_relation) | map(attribute='name') | list %}
{% set has_is_deleted = 'dbt_is_deleted' in snapshot_columns %}

select
    id_cliente,
    movement_date,
    product,
    amount,
    description,
    fund,
    type,
    commercial_name,
    _source_file,
    _batch_id,
    dbt_valid_from as valid_from,
    dbt_valid_to   as valid_to,
    {% if has_is_deleted -%}
    dbt_is_deleted::boolean as is_deleted,
    {%- else -%}
    false as is_deleted,  -- aún no hay segunda corrida de snapshot que la haya generado
    {%- endif %}
    case
        when row_number() over (partition by id_cliente order by dbt_valid_from) = 1
            then 'new'
        {% if has_is_deleted -%}
        when dbt_is_deleted::boolean = true
            then 'deleted'
        {%- endif %}
        else 'corrected'
    end as event_type
from {{ snapshot_relation }}