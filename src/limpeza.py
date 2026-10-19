from pathlib import Path

import pandas as pd

# Pastas do projeto (calculadas a partir da localização deste arquivo)
PASTA_PROJETO = Path(__file__).resolve().parent.parent
PASTA_RAW = PASTA_PROJETO / "dados" / "raw"
PASTA_PROCESSED = PASTA_PROJETO / "dados" / "processed"


def ler_arquivo(caminho):
    """Lê um CSV semestral da ANP com as configurações descobertas na exploração."""
    return pd.read_csv(
        caminho,
        sep=";",
        encoding="utf-8",
        decimal=",",
        low_memory=False,
        # Códigos são texto: evita perder zeros à esquerda e tipos misturados entre arquivos
        dtype={"CNPJ da Revenda": str, "Cep": str, "Numero Rua": str},
    )

# Nomes novos das colunas: minúsculos, sem espaço e sem acento (padrão para banco de dados)
COLUNAS = {
    "Regiao - Sigla": "regiao",
    "Estado - Sigla": "uf",
    "Municipio": "municipio",
    "Revenda": "revenda",
    "CNPJ da Revenda": "cnpj",
    "Nome da Rua": "rua",
    "Numero Rua": "numero",
    "Complemento": "complemento",
    "Bairro": "bairro",
    "Cep": "cep",
    "Produto": "produto",
    "Data da Coleta": "data_coleta",
    "Valor de Venda": "valor_venda",
    "Unidade de Medida": "unidade",
    "Bandeira": "bandeira",
}


def limpar(df):
    """Aplica as limpezas definidas na exploração (notebook 01, seção 5)."""
    # Linhas 100% vazias no final do arquivo
    df = df.dropna(how="all")

    # Coluna sem nenhum valor preenchido
    df = df.drop(columns=["Valor de Compra"])

    # Espaços sobrando no início/fim de todas as colunas de texto
    for coluna in df.columns:                                  # ← este é o laço do strip
        if pd.api.types.is_string_dtype(df[coluna]):
            df[coluna] = df[coluna].str.strip()

    # Padroniza códigos: só dígitos, com zeros à esquerda (2025.02 veio sem pontuação)
    df["CNPJ da Revenda"] = (
        df["CNPJ da Revenda"].str.replace(r"\D", "", regex=True).str.zfill(14)
    )
    df["Cep"] = df["Cep"].str.replace(r"\D", "", regex=True).str.zfill(8)

    # Data no padrão brasileiro (dia/mês/ano)
    df["Data da Coleta"] = pd.to_datetime(df["Data da Coleta"], format="%d/%m/%Y")

    # Linhas repetidas (nenhuma em 2025.01, mas outros semestres podem ter)
    df = df.drop_duplicates()

    # Renomeia as colunas para o padrão do banco
    df = df.rename(columns=COLUNAS)

    return df

def processar_todos(arquivos):
    """Lê e limpa cada arquivo, e junta tudo numa base única."""
    partes = []
    for caminho in arquivos:
        bruto = ler_arquivo(caminho)
        limpo = limpar(bruto)
        limpo["arquivo_origem"] = caminho.name
        print(f"{caminho.name}: {len(bruto):,} lidas → {len(limpo):,} após limpeza")
        partes.append(limpo)

    return pd.concat(partes, ignore_index=True)

if __name__ == "__main__":
    arquivos = sorted(PASTA_RAW.glob("*.csv"))
    print(f"{len(arquivos)} arquivos encontrados\n")

    df = processar_todos(arquivos)
    print(f"\nTotal: {len(df):,} linhas")

    PASTA_PROCESSED.mkdir(exist_ok=True)
    destino = PASTA_PROCESSED / "precos_combustiveis.parquet"
    df.to_parquet(destino, index=False)
    print(f"Arquivo salvo em: {destino}")