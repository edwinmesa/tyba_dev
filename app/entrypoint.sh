#!/bin/bash
set -e

echo ">> Esperando a que Postgres esté listo..."
until nc -z "${POSTGRES_HOST}" "${POSTGRES_PORT}"; do
  sleep 1
done
echo ">> Postgres disponible."

export DBT_PROFILES_DIR=/app/dbt_tyba

cd /app/dbt_tyba || exit 1

echo ">> Limpiando archivos generados por dbt..."

rm -rf target
rm -rf logs
rm -rf dbt_packages

echo ">> Limpiando cache de dbt..."

rm -rf ~/.cache/dbt

echo ">> Instalando dependencias..."
dbt deps

echo ">> Ejecutando create_raw_schema..."
dbt run-operation create_raw_schema

echo ">> Creando modelos de staging (necesarios antes del primer snapshot)..."
dbt run --select staging.* 

# run_tyba_pipeline.py hace lo siguiente por cada archivo NUEVO en /app/data/raw
# (en orden alfabético = orden cronológico de los cortes):
#   1. lo carga en raw.movimientos vía COPY
#   2. corre `dbt snapshot` inmediatamente después de cargarlo
# Esto simula el procesamiento día a día: cada corte se snapshotea

# individualmente para que la lógica de SCD2 detecte nuevo/corregido/eliminado
# comparando exactamente contra el corte anterior, no contra un batch mezclado.


echo ">> Procesando cortes pendientes..."
python /app/run_tyba_pipeline.py

echo ">> Construyendo modelos (staging + marts)..."
dbt run

echo ">> Corriendo tests de calidad..."
dbt test

echo ">> Pipeline completado exitosamente."
