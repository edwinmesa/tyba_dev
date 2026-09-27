-- dbt test falla si esta query devuelve filas.
-- Regla de negocio: un movimiento con type definido (entrada/salida) no
-- debería tener amount = 0; si ocurre, probablemente sea un dato sucio que
-- vale la pena revisar manualmente.

select id, amount, type
from {{ ref('stg_transactions') }}
where type is not null
  and amount = 0
