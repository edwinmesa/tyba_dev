import os
import psycopg2


def get_connection():
    """
    Returns a connection to the PostgreSQL database using 
    environment variables for configuration.
    """
    return psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        port=os.environ["POSTGRES_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )
