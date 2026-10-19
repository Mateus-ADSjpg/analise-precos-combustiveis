-- =====================================================================
-- Validações do modelo estrela (rodar depois do 01_modelo_estrela.sql)
-- =====================================================================

-- 1) Tamanho das dimensões
SELECT 'produto' AS dimensao, COUNT(*) FROM analytics.dim_produto
UNION ALL SELECT 'bandeira', COUNT(*) FROM analytics.dim_bandeira
UNION ALL SELECT 'posto', COUNT(*) FROM analytics.dim_posto
UNION ALL SELECT 'calendario', COUNT(*) FROM analytics.dim_calendario;

-- 2) Nenhuma linha perdida nos JOINs (os dois números devem ser iguais)
SELECT
    (SELECT COUNT(*) FROM staging.precos)        AS linhas_staging,
    (SELECT COUNT(*) FROM analytics.fato_precos) AS linhas_fato;

-- 3) Preço médio por produto (conferir com o notebook de exploração)
SELECT p.produto, ROUND(AVG(f.valor_venda), 2) AS preco_medio, COUNT(*) AS coletas
FROM analytics.fato_precos f
JOIN analytics.dim_produto p USING (id_produto)
GROUP BY p.produto
ORDER BY preco_medio DESC;