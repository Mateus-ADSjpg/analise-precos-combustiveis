-- =====================================================================
-- Modelo estrela: camada analytics (consumida pelo Power BI)
-- Origem: staging.precos (carregada por src/carga.py)
-- =====================================================================

-- Recria a camada do zero (idempotente: pode rodar quantas vezes quiser)
DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;


-- ---------------------------------------------------------------------
-- dim_produto: os combustíveis e sua unidade de medida
-- ---------------------------------------------------------------------
CREATE TABLE analytics.dim_produto AS
SELECT
    ROW_NUMBER() OVER (ORDER BY produto) AS id_produto,
    produto,
    unidade
FROM (SELECT DISTINCT produto, unidade FROM staging.precos) p;

ALTER TABLE analytics.dim_produto ADD PRIMARY KEY (id_produto);


-- ---------------------------------------------------------------------
-- dim_bandeira: distribuidoras (BRANCA = posto sem bandeira)
-- ---------------------------------------------------------------------
CREATE TABLE analytics.dim_bandeira AS
SELECT
    ROW_NUMBER() OVER (ORDER BY bandeira) AS id_bandeira,
    bandeira,
    (bandeira = 'BRANCA') AS bandeira_branca
FROM (SELECT DISTINCT bandeira FROM staging.precos) b;

ALTER TABLE analytics.dim_bandeira ADD PRIMARY KEY (id_bandeira);


-- ---------------------------------------------------------------------
-- dim_posto: um registro por CNPJ, com os dados da coleta mais recente
-- (o mesmo posto pode mudar de nome ou endereço ao longo dos semestres)
-- ---------------------------------------------------------------------
CREATE TABLE analytics.dim_posto AS
SELECT
    ROW_NUMBER() OVER (ORDER BY cnpj) AS id_posto,
    cnpj, revenda, rua, numero, complemento, bairro, cep,
    municipio, uf, regiao
FROM (
    SELECT DISTINCT ON (cnpj)
        cnpj, revenda, rua, numero, complemento, bairro, cep,
        municipio, uf, regiao
    FROM staging.precos
    ORDER BY cnpj, data_coleta DESC
) p;

ALTER TABLE analytics.dim_posto ADD PRIMARY KEY (id_posto);


-- ---------------------------------------------------------------------
-- dim_calendario: um dia por linha, do primeiro ao último dia coletado
-- ---------------------------------------------------------------------
CREATE TABLE analytics.dim_calendario AS
SELECT
    d::date                                                AS data,
    EXTRACT(YEAR FROM d)::int                              AS ano,
    EXTRACT(MONTH FROM d)::int                             AS mes,
    (ARRAY['Jan','Fev','Mar','Abr','Mai','Jun',
           'Jul','Ago','Set','Out','Nov','Dez'])[EXTRACT(MONTH FROM d)::int] AS nome_mes,
    TO_CHAR(d, 'YYYY-MM')                                  AS ano_mes,
    EXTRACT(QUARTER FROM d)::int                           AS trimestre,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END AS semestre,
    EXTRACT(ISODOW FROM d)::int                            AS dia_semana_num,
    (ARRAY['Seg','Ter','Qua','Qui','Sex','Sáb','Dom'])[EXTRACT(ISODOW FROM d)::int] AS dia_semana
FROM generate_series(
    (SELECT MIN(data_coleta) FROM staging.precos),
    (SELECT MAX(data_coleta) FROM staging.precos),
    INTERVAL '1 day'
) AS d;

ALTER TABLE analytics.dim_calendario ADD PRIMARY KEY (data);

-- ---------------------------------------------------------------------
-- fato_precos: uma linha por coleta de preço (posto x produto x dia)
-- Guarda só as chaves das dimensões e a métrica (valor_venda)
-- ---------------------------------------------------------------------
CREATE TABLE analytics.fato_precos AS
SELECT
    ROW_NUMBER() OVER () AS id_coleta,
    s.data_coleta::date  AS data,
    po.id_posto,
    pr.id_produto,
    b.id_bandeira,
    s.valor_venda::numeric(10, 2) AS valor_venda
FROM staging.precos s
JOIN analytics.dim_posto    po ON po.cnpj    = s.cnpj
JOIN analytics.dim_produto  pr ON pr.produto = s.produto AND pr.unidade = s.unidade
JOIN analytics.dim_bandeira b  ON b.bandeira = s.bandeira;

ALTER TABLE analytics.fato_precos ADD PRIMARY KEY (id_coleta);

-- Chaves estrangeiras: garantem que todo ID da fato existe na dimensão
ALTER TABLE analytics.fato_precos
    ADD CONSTRAINT fk_fato_data     FOREIGN KEY (data)        REFERENCES analytics.dim_calendario (data),
    ADD CONSTRAINT fk_fato_posto    FOREIGN KEY (id_posto)    REFERENCES analytics.dim_posto (id_posto),
    ADD CONSTRAINT fk_fato_produto  FOREIGN KEY (id_produto)  REFERENCES analytics.dim_produto (id_produto),
    ADD CONSTRAINT fk_fato_bandeira FOREIGN KEY (id_bandeira) REFERENCES analytics.dim_bandeira (id_bandeira);

-- Índices nas chaves: deixam filtros e junções bem mais rápidos
CREATE INDEX idx_fato_data     ON analytics.fato_precos (data);
CREATE INDEX idx_fato_posto    ON analytics.fato_precos (id_posto);
CREATE INDEX idx_fato_produto  ON analytics.fato_precos (id_produto);
CREATE INDEX idx_fato_bandeira ON analytics.fato_precos (id_bandeira);