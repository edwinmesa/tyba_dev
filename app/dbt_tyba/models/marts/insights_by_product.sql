-- Insight 1: volumen de movimientos y monto total, agrupado por producto,
-- fondo y tipo, sobre el estado ACTUAL (no histórico) — responde
-- "¿cómo se ve el negocio hoy?"

select
    product,
    fund,
    type,
    count(*)                as transaction_count,
    sum(amount)              as total_amount,
    round(avg(amount), 2)    as avg_amount
from {{ ref('dim_current_transactions') }}
group by product, fund, type
order by total_amount desc
