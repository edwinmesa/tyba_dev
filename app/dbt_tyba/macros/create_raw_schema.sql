-- Se ejecuta con: dbt run-operation create_raw_schema
{% macro create_raw_schema() %}

    {% set sql %}
        create schema if not exists raw;

        -- Particionada por RANGE sobre _loaded_at (mes a mes). Usamos
        -- _loaded_at y no "date"/movement_date porque ese campo llega como
        -- texto sucio del parquet (puede venir nulo o mal formado) y no es
        -- seguro usarlo como llave de partición. _loaded_at lo controla el
        -- loader, siempre es válido.
        create table if not exists raw.transactions (
            id_cliente      text,
            date            text,
            product         text,
            amount          text,
            description     text,
            fund            text,
            type            text,
            commercial_name text,
            _source_file    text not null,
            _batch_id       text not null,
            _loaded_at      timestamptz not null
        ) partition by range (_loaded_at);

        -- Partición "catch-all": si por algo (ej. corrida justo en el
        -- cambio de mes) no existe todavía la partición del mes correcto,
        -- los INSERT/COPY no fallan; caen aquí temporalmente.
        create table if not exists raw.transactions_default
            partition of raw.transactions default;

        create table if not exists raw._processed_files (
            filename     text primary key,
            batch_id     text not null,
            processed_at timestamptz not null,
            row_count    integer not null
        );

        -- Sobre tabla particionada, el índice se crea una vez en el padre
        -- y Postgres lo propaga automáticamente a cada partición (PG >= 11).
        create index if not exists idx_raw_transactions_id
            on raw.transactions (id_cliente);
        create index if not exists idx_raw_transactions_type_fund
            on raw.transactions (type, fund);
    {% endset %}

    {% do run_query(sql) %}
    {{ log("Esquema raw creado/verificado (particionado por mes).", info=True) }}

    {{ create_current_month_partition() }}

{% endmacro %}


{% macro create_current_month_partition() %}
-- Crea explícitamente la partición del mes en curso, para que las cargas
-- de este run caigan en su partición real y no en la "default". Se corre
-- en cada invocación del pipeline; si la partición ya existe, no hace nada.

    {% set sql %}
        do $$
        declare
            partition_name text := 'transactions_' || to_char(now(), 'YYYY_MM');
            start_date     date := date_trunc('month', now());
            end_date       date := date_trunc('month', now()) + interval '1 month';
        begin
            if not exists (
                select 1 from pg_class where relname = partition_name
            ) then
                execute format(
                    'create table raw.%I partition of raw.transactions
                     for values from (%L) to (%L);',
                    partition_name, start_date, end_date
                );
            end if;
        end $$;
    {% endset %}

    {% do run_query(sql) %}
    {{ log("Partición del mes actual verificada/creada.", info=True) }}

{% endmacro %}