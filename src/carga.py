import csv
from io import StringIO

import pandas as pd
from sqlalchemy import text

from conexao import criar_engine
from limpeza import PASTA_PROCESSED


def copiar_postgres(tabela, conexao, colunas, linhas):
    """Insere os dados usando o COPY do PostgreSQL (muito mais rápido que INSERT)."""
    conexao_bruta = conexao.connection
    with conexao_bruta.cursor() as cursor:
        buffer = StringIO()
        csv.writer(buffer).writerows(linhas)
        buffer.seek(0)

        nomes_colunas = ", ".join(f'"{c}"' for c in colunas)
        nome_tabela = f"{tabela.schema}.{tabela.name}"
        cursor.copy_expert(
            f"COPY {nome_tabela} ({nomes_colunas}) FROM STDIN WITH CSV", buffer
        )


if __name__ == "__main__":
    df = pd.read_parquet(PASTA_PROCESSED / "precos_combustiveis.parquet")
    print(f"{len(df):,} linhas lidas do Parquet")

    engine = criar_engine()

    with engine.begin() as conexao:
        conexao.execute(text("CREATE SCHEMA IF NOT EXISTS staging"))

    df.to_sql(
        "precos",
        engine,
        schema="staging",
        if_exists="replace",
        index=False,
        method=copiar_postgres,
        chunksize=100_000,
    )

    # Validação: o banco tem que ter exatamente o mesmo número de linhas do Parquet
    with engine.connect() as conexao:
        total = conexao.execute(text("SELECT COUNT(*) FROM staging.precos")).scalar()

    print(f"{total:,} linhas na tabela staging.precos")
    print("OK" if total == len(df) else "ATENÇÃO: contagem diferente!")