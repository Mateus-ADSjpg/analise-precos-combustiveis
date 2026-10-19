import os

from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text

load_dotenv()  # lê o arquivo .env e carrega as variáveis


def criar_engine():
    """Cria a conexão com o PostgreSQL usando as credenciais do .env."""
    url = URL.create(
        "postgresql+psycopg2",
        username=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT")),
        database=os.getenv("DB_NAME"),
    )
    return create_engine(url)


if __name__ == "__main__":
    engine = criar_engine()
    with engine.connect() as conexao:
        versao = conexao.execute(text("SELECT version()")).scalar()
        print("Conectado!", versao)