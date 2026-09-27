import os
import subprocess

DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", "/app/dbt_tyba")


def run_dbt_snapshot() -> None:
    """Runs the dbt snapshot command in the specified DBT project directory."""
    result = subprocess.run(
        ["dbt", "snapshot"],
        cwd=DBT_PROJECT_DIR,
        env={**os.environ, "DBT_PROFILES_DIR": DBT_PROJECT_DIR},
    )
    if result.returncode != 0:
        raise RuntimeError(
            "dbt snapshot falló, abortando el procesamiento de cortes."
        )
