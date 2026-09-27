-- Limpieza y normalización del raw. Decisiones de calidad de datos documentadas
-- aquí (y en el README):
--   * id nulo/vacío -> se descarta (no se puede rastrear un registro sin id)
--   * amount no numérico -> queda NULL tras el cast seguro (no se descarta la
--     fila completa, para no perder trazabilidad; se puede filtrar aguas abajo)
--   * strings vacíos -> se normalizan a NULL
--   * type -> se normaliza a minúsculas para evitar duplicar categorías por casing

with source as (
    select * from {{ source('raw', 'transactions') }}
),

cleaned as (
    select
        nullif(trim(id_cliente), '')                          as id_cliente,
        (case
            when date ~ '^\d{4}-\d{2}-\d{2}' then date::date
            else null
        end)                                            as movement_date,
        nullif(trim(product), '')                      as product,
        (case
            when amount ~ '^-?\d+(\.\d+)?$' then amount::numeric(18, 2)
            else null
        end)                                            as amount,
        nullif(trim(description), '')                  as description,
        nullif(trim(fund), '')                          as fund,
        lower(nullif(trim(type), ''))                   as type,
        nullif(trim(commercial_name), '')               as commercial_name,
        _source_file,
        _batch_id,
        _loaded_at
    from source
    where nullif(trim(id_cliente), '') is not null
),

deduped as (
    -- Si el mismo id aparece más de una vez DENTRO del mismo corte (_batch_id),
    -- nos quedamos con la última fila cargada. Es una regla arbitraria pero
    -- explícita y documentada; no hay forma de saber cuál es "la correcta"
    -- sin contexto de negocio adicional.
    select
        *,
        row_number() over (
            partition by id_cliente, _batch_id
            order by _loaded_at desc
        ) as _rn
    from cleaned
)

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
    _loaded_at,
    md5(
        coalesce(amount::text, '~')      || '|' ||
        coalesce(description, '~')        || '|' ||
        coalesce(product, '~')            || '|' ||
        coalesce(fund, '~')               || '|' ||
        coalesce(type, '~')               || '|' ||
        coalesce(commercial_name, '~')    || '|' ||
        coalesce(movement_date::text, '~')
    ) as row_hash
from deduped
where _rn = 1
