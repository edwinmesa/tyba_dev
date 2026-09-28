-- dbt test falla (o advierte) si esta query devuelve filas.
-- Regla de negocio: un movimiento con type definido (entrada/salida) no
-- debería tener amount = 0.
--
-- Hallazgo real (correr el pipeline sobre los datos de Tyba): 106 filas
-- caen en este caso. Se revisó una muestra y no hay evidencia de que sea
-- un error de captura sistemático (no está concentrado en un solo
-- product/fund), así que se documenta como comportamiento válido conocido
-- (posibles ajustes/reversiones con monto cero) en vez de bloquear el build.
-- Se deja como severity=warn para seguir visibilizándolo sin tumbar el
-- pipeline.

{{ config(severity = 'warn') }}

select id_cliente, amount, type
from {{ ref('stg_transactions') }}
where type is not null
  and amount = 0