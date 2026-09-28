-- Limpieza y normalización del raw. Decisiones de calidad de datos documentadas
-- aquí (y en el README):
--   * id_cliente nulo/vacío -> se descarta (no se puede rastrear sin cliente)
--   * amount no numérico -> queda NULL tras el cast seguro (no se descarta la
--     fila completa, para no perder trazabilidad; se puede filtrar aguas abajo)
--   * strings vacíos -> se normalizan a NULL
--   * type -> se normaliza a minúsculas para evitar duplicar categorías por casing
--
-- HALLAZGO CRÍTICO: el parquet fuente NO trae ningún identificador único por
-- transacción. "id_cliente" es el identificador del CLIENTE (se repite ~16-17
-- veces por cliente en un solo corte: 50,000 filas / 3,000 clientes únicos).
-- Usarlo tal cual como unique_key del snapshot SCD2 colapsaba todas las
-- transacciones de un mismo cliente en una sola fila "vigente", perdiendo
-- datos reales silenciosamente.
--
-- Solución: se construye un transaction_id sintético a partir de una LLAVE
-- DE NEGOCIO (los campos que identifican la transacción y que, según el
-- enunciado, NO deberían cambiar entre cortes): id_cliente + date + product
-- + fund + type. Los campos que el enunciado explícitamente señala como
-- corregibles (amount, description, "u otro campo") quedan FUERA de la
-- llave y son los que entran al row_hash para detectar correcciones.
-- Supuesto documentado: se asume que esta combinación es única por cliente
-- dentro de un mismo corte (validar con el dataset real antes de producción).

with source as (
    select * from {{ source('raw', 'transactions') }}
),

cleaned as (
    select
        nullif(trim(id_cliente), '')                  as id_cliente,
        (case
            when date ~ '^\d{4}-\d{2}-\d{2}' then date::date
            when date ~ '^\d{2}/\d{2}/\d{4}$'          -- formato dd/mm/yyyy detectado en la fuente
                then to_date(date, 'DD/MM/YYYY')
            else null
        end)                                            as movement_date,
        nullif(trim(product), '')                      as product,
        (case
            when amount ~ '^-?\d+(\.\d+)?$' then amount::numeric(18, 2)
            else null
        end)                                                as amount,
        nullif(trim(description), '')                       as description,
        lower(initcap(nullif(trim(regexp_replace(
            fund, '\s+', ' ', 'g')), '')))                   as fund,  --- evitar espacios extra y normalizar casing
        (case
            when lower(trim(type)) 
                in ('entrada', 'in')  then 'entrada'
            when lower(trim(type)) 
                in ('salida', 'out')  then 'salida'
            else null
        end)                                                 as type,
        lower(nullif(trim(commercial_name), ''))             as commercial_name,
        _source_file,
        _batch_id,
        _loaded_at
    from source
    where nullif(trim(id_cliente), '') is not null
),

deduped as (
    -- Si la misma llave de negocio (cliente+fecha+producto+fondo+tipo)
    -- aparece más de una vez DENTRO del mismo corte, nos quedamos con la
    -- última fila cargada. Regla arbitraria pero explícita y documentada.
    select
        *,
        row_number() over (
            partition by id_cliente, movement_date, product, fund, type, _batch_id
            order by _loaded_at desc
        ) as _rn
    from cleaned
)

select
    -- transaction_id: llave de negocio hasheada, usada como unique_key del
    -- snapshot SCD2. Solo cambia si cambia la IDENTIDAD de la transacción
    -- (no si se corrige un valor como amount o description).
    md5(
        coalesce(id_cliente, '~')          || '|' ||
        coalesce(movement_date::text, '~') || '|' ||
        coalesce(product, '~')             || '|' ||
        coalesce(fund, '~')                || '|' ||
        coalesce(type, '~')
    ) as transaction_id,
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
    -- row_hash: SOLO los campos "de valor" que el enunciado indica que
    -- pueden corregirse entre cortes. Si esto cambia, es una CORRECCIÓN;
    -- si cambia la llave de arriba, sería una transacción distinta.
    md5(
        coalesce(amount::text, '~')      || '|' ||
        coalesce(description, '~')        || '|' ||
        coalesce(commercial_name, '~')
    ) as row_hash
from deduped
where _rn = 1