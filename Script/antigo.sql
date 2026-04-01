WITH base AS (
    SELECT
        TO_DATE(SUBSTR(C.GLDGJ,2,5),'YYDDD')                 AS DATA_LANCAMENTO,
        C.GLDCT                                              AS TIPO_DOCUMENTO,
        TO_CHAR(C.GLDOC)                                     AS NUM_DOCUMENTO,
        C.GLAA / 100                                         AS VALOR_TRANSACAO,
        TRIM(TO_CHAR(C.GLANI))                               AS CONTA_II,
        TRIM(TO_CHAR(GMOBJ || GMSUB))                        AS CONTA_ESTRUTURA,
        TRIM(TO_CHAR(A.GMDL01))                              AS DESCRICAO_CONTA_II,
        CAST(C.GLEXA AS VARCHAR2(30))                        AS EXPLICACAO,
        C.GLAID                                              AS CHAVE_CONTA,
        TO_CHAR(D.DRDL01)                                    AS CONTA,
        TRIM(TO_CHAR(E.DRDL01))                              AS CONTA_I,
        A.GMSUB                                              AS ORDEM_CONTA,
        TO_CHAR(GMOBJ || GMSUB || ' ' || A.GMDL01)           AS CONTA_COMPLETA,
        F.MCMCU || ' ' || F.MCDL01                           AS CENTRO_CUSTO,

        /* Pega o texto do percentual na F0005 a partir dos códigos da F0006 */
        (SELECT DRSPHD FROM PRODCTL.F0005
          WHERE DRSY='00' AND DRRT='49' AND TRIM(F.MCRP49)=TRIM(DRKY)) AS RATEIO_BALAO_STR,
        (SELECT DRSPHD FROM PRODCTL.F0005
          WHERE DRSY='00' AND DRRT='50' AND TRIM(F.MCRP50)=TRIM(DRKY)) AS RATEIO_MULTIUSO_STR,

        A.GMCO || ' - ' || G.CCNAME                          AS EMPRESA,
        TRIM(TO_CHAR(B.MCMCU || ' ' || B.MCDL01))            AS FILIAL,
        NULL                                                 AS CFOP,
        NULL                                                 AS NOTA,
        CAST(' ' AS VARCHAR2(25))                            AS ITEM,
        ' '                                                  AS TAMANHO,
        ' '                                                  AS TIPO,
        ' '                                                  AS COR,
        ' '                                                  AS EMBALAGEM,
        1                                                    AS QUERY_INFO
    FROM PRODDTA.F0901 A
    JOIN PRODDTA.F0911 C        ON (A.GMAID = C.GLAID)
    LEFT JOIN PRODCTL.F0005 D    ON (D.DRSY='09' AND D.DRRT='09' AND TRIM(D.DRKY)=TRIM(A.GMR009))
    LEFT JOIN PRODCTL.F0005 E    ON (E.DRSY='09' AND E.DRRT='10' AND TRIM(E.DRKY)=TRIM(A.GMR010))
    LEFT JOIN PRODDTA.F0006 F    ON (F.MCMCU = A.GMMCU)
    JOIN PRODDTA.F0010 G         ON (G.CCCO = A.GMCO)
    LEFT JOIN PRODDTA.F0006 B    ON (TRIM(F.MCRP04) = TRIM(B.MCMCU))
    WHERE
        C.GLLT  = 'AA'
        AND C.GLPOST = 'P'
        /* Ajuste seu período/filtros conforme necessário */
        AND C.GLDGJ >= 121000
        --AND C.GLDGJ <= sys.date_to_julian('28/02/2025')
        /* Evite filtros que removam contas sem rateio; mantenha apenas os que você realmente precisa */
        AND NVL(TRIM(D.DRDL01), '§§') NOT IN ('Faturamento Bruto','(-) IMPOSTOS FATURADO')
        AND NVL(TRIM(E.DRDL01), '§§') <> 'Devoluções'
        AND TRIM(GMOBJ || GMSUB) NOT IN ('311210001','311210004','311210003')
        --AND TRIM(GMOBJ || GMSUB) = ('510120005')
        --AND GLDOC = 684383
),
base_norm AS (
    /* Converte DRSPHD (p.ex. '20', '20,5', '20%') para número decimal seguro */
    SELECT
        b.*,
        CASE WHEN REGEXP_LIKE(NVL(TRIM(b.RATEIO_BALAO_STR), 'x'), '^\d+([.,]\d+)?%?$')
             THEN TO_NUMBER(REPLACE(REPLACE(TRIM(b.RATEIO_BALAO_STR), '%', ''), ',', '.'))
        END AS RATEIO_BALAO,
        CASE WHEN REGEXP_LIKE(NVL(TRIM(b.RATEIO_MULTIUSO_STR), 'x'), '^\d+([.,]\d+)?%?$')
             THEN TO_NUMBER(REPLACE(REPLACE(TRIM(b.RATEIO_MULTIUSO_STR), '%', ''), ',', '.'))
        END AS RATEIO_MULTIUSO
    FROM base b
)

-- 1) SEM RATEIO: quando MCRP49 (=> RATEIO_BALAO) está NULL => 1 linha, valor original, LINHA em branco
SELECT
    DATA_LANCAMENTO,
    TIPO_DOCUMENTO,
    NUM_DOCUMENTO,
    CAST(VALOR_TRANSACAO AS NUMBER(38,4))                         AS VALOR_TRANSACAO,
    CONTA_II,
    CONTA_ESTRUTURA,
    DESCRICAO_CONTA_II,
    EXPLICACAO,
    CHAVE_CONTA,
    CONTA,
    CONTA_I,
    ORDEM_CONTA,
    CONTA_COMPLETA,
    CENTRO_CUSTO,
    CAST(NULL AS NUMBER(10,4))                                     AS PERCENTUAL,
    EMPRESA,
    FILIAL,
    CFOP,
    NOTA,
    ITEM,
    ' '                                                             AS LINHA,
    TAMANHO,
    TIPO,
    COR,
    EMBALAGEM,
    QUERY_INFO
FROM base_norm
WHERE RATEIO_BALAO IS NULL

UNION ALL

-- 2) COM RATEIO 49 (BALOES): quando MCRP49 tem valor => aplica rateio na "linha original"
SELECT
    DATA_LANCAMENTO,
    TIPO_DOCUMENTO,
    NUM_DOCUMENTO,
    CAST(ROUND(VALOR_TRANSACAO * RATEIO_BALAO / 100, 4) AS NUMBER(38,4)) AS VALOR_TRANSACAO,
    CONTA_II,
    CONTA_ESTRUTURA,
    DESCRICAO_CONTA_II,
    EXPLICACAO,
    CHAVE_CONTA,
    CONTA,
    CONTA_I,
    ORDEM_CONTA,
    CONTA_COMPLETA,
    CENTRO_CUSTO,
    CAST(RATEIO_BALAO AS NUMBER(10,4))                                AS PERCENTUAL,
    EMPRESA,
    FILIAL,
    CFOP,
    NOTA,
    ITEM,
    'BALOES'                                                           AS LINHA,
    TAMANHO,
    TIPO,
    COR,
    EMBALAGEM,
    QUERY_INFO
FROM base_norm
WHERE RATEIO_BALAO IS NOT NULL

UNION ALL

-- 3) COM RATEIO 50 (LUVAS MULTIUSO): só entra quando MCRP49 TEM valor (linha 2) E MCRP50 TAMBÉM TEM valor
SELECT
    DATA_LANCAMENTO,
    TIPO_DOCUMENTO,
    NUM_DOCUMENTO,
    CAST(ROUND(VALOR_TRANSACAO * RATEIO_MULTIUSO / 100, 4) AS NUMBER(38,4)) AS VALOR_TRANSACAO,
    CONTA_II,
    CONTA_ESTRUTURA,
    DESCRICAO_CONTA_II,
    EXPLICACAO,
    CHAVE_CONTA,
    CONTA,
    CONTA_I,
    ORDEM_CONTA,
    CONTA_COMPLETA,
    CENTRO_CUSTO,
    CAST(RATEIO_MULTIUSO AS NUMBER(10,4))                                  AS PERCENTUAL,
    EMPRESA,
    FILIAL,
    CFOP,
    NOTA,
    ITEM,
    'LUVAS MULTIUSO'                                                        AS LINHA,
    TAMANHO,
    TIPO,
    COR,
    EMBALAGEM,
    QUERY_INFO
FROM base_norm
WHERE RATEIO_BALAO IS NOT NULL  -- só gera a cópia quando 49 existe
  AND RATEIO_MULTIUSO IS NOT NULL

UNION ALL   --- DIFAL

(SELECT         TO_DATE(SUBSTR(I.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                F.dfbicm/100 AS VALOR_TRANSACAO,
                '100.310110.006'   AS CONTA_II,
				'310110006'  AS CONTA_ESTRUTURA,
				'DIFAL - ICMS' AS DESCRICAO_CONTA_II,
				CAST('DIFAL DOC' || A.fdbnnf AS VARCHAR2(30)) AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				'(-) IMPOSTOS FATURADO' AS CONTA,
                '(-) Impostos s/ Faturamento'  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                '310110006      DIFAL - ICMS                  '  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) AS ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                8 QUERY_INFO

--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM proddta.f7611B A
JOIN PRODDTA.F7601B I ON (I.FHFCO = A.FDFCO AND I.FHbNNF = A.fdbNNF AND A.FDDCT = I.FHDCT AND A.FDN001 = I.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
LEFT JOIN PRODDTA.F5576007 F ON (F.dfbNNF = A.fdbNNF AND A.FDDCT = F.dfDCT AND A.FDN001 = F.dfN001 AND A.FDBSER = F.dfBSER AND F.dfUKID = A.FDUKID)
WHERE A.FDPDCT IN ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
--AND A.fdmcu in ('        0180','        0280')
AND I.FHISSU>=121000
--AND I.FHISSU<=116031
AND A.FDNXTR NOT IN ('996','994')
AND A.FDLTTR >= '615'
--AND A.fdbnnf = '195828'
--and f.dfdoco = 638390
)

UNION ALL   --- VALOR DO FATURAMENTO

(SELECT         TO_DATE(SUBSTR(I.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                --(A.fdaexp/100)*(-1) AS VALOR_TRANSACAO,
                ((A.fdaexp/100)+(A.fdbipi/100)+(A.fdBVIS/100)-(A.fdBDIZ/100))*(-1) AS VALOR_TRANSACAO,
             --   A.fdbipi/100 VALOR_IPI,
             --   A.fdBVIS/100 VALOR_ICMS,

                CASE WHEN A.FDPDCT='SX' THEN  '100.310110.005' ELSE '100.310110.001' END  AS CONTA_II,

				CASE WHEN A.FDPDCT='SX' THEN  '310110005' ELSE '310110001' END AS CONTA_ESTRUTURA,

				CASE WHEN A.FDPDCT='SX' THEN  'FAT.BRUTO MERC.EXTERNO' ELSE 'FAT.BRUTO MERC.INTERNO' END AS DESCRICAO_CONTA_II,

				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,

				'Faturamento Bruto' AS CONTA,

                CASE WHEN A.FDPDCT='SX' THEN  'Receita Mercado Externo' ELSE 'Receita Mercado Interno' END AS CONTA_I,

				NULL AS  ORDEM_CONTA,

                CASE WHEN A.FDPDCT='SX' THEN  '310110005 FAT. BRUTO MERC.EXTERNO'
                ELSE '310110001 FAT.BRUTO MERC.INTERNO' END AS CONTA_COMPLETA,

                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,

                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                7 QUERY_INFO

--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM proddta.f7611B A
JOIN PRODDTA.F7601B I ON (I.FHFCO = A.FDFCO AND I.FHbNNF = A.fdbNNF AND A.FDDCT = I.FHDCT AND A.FDN001 = I.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE
A.FDPDCT IN ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
--AND A.fdmcu in ('        0180','        0280')
--AND
and I.FHISSU>=121000
--AND I.FHISSU<=123059
AND A.FDNXTR NOT IN ('996','994')
AND A.FDLTTR >= '615'
-- VALOR LANCAMNETO DIRETO NA CONTABILIDADE
--AND A.fdbnnf = '42275'
)

UNION ALL   --- VALOR DO IPI S/ FATURAMENTO

(SELECT         TO_DATE(SUBSTR(I.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                A.fdbipi/100 AS VALOR_TRANSACAO,

                '100.310110.002'   AS CONTA_II,
				'310110002'  AS CONTA_ESTRUTURA,
				'IPI S/FAT.BRUTO M.INTERNO' AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				'(-) IMPOSTOS FATURADO' AS CONTA,
                '(-) Impostos s/ Faturamento'  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                '310110002      IPI S/FAT.BRUTO M.INTERNO'  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) AS ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                8 QUERY_INFO

--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM proddta.f7611B A
JOIN PRODDTA.F7601B I ON (I.FHFCO = A.FDFCO AND I.FHbNNF = A.fdbNNF AND A.FDDCT = I.FHDCT AND A.FDN001 = I.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE A.FDPDCT IN ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
--AND A.fdmcu in ('        0180','        0280')
AND I.FHISSU>=121000
--AND I.FHISSU<=116031
AND A.FDNXTR NOT IN ('996','994')
AND A.FDLTTR >= '615'
--AND A.fdbnnf = '195828'
)

UNION ALL   --- VALOR DO ICMS ST S/ FATURAMENTO

(SELECT         TO_DATE(SUBSTR(I.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                A.fdBVIS/100 AS VALOR_TRANSACAO,

                '100.310110.003'   AS CONTA_II,
				'310110003'  AS CONTA_ESTRUTURA,
				'ICMS ST.FAT.BRUTO M.INTERNO' AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				'(-) IMPOSTOS FATURADO' AS CONTA,
                '(-) Impostos s/ Faturamento'  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                '310110003      ICMS ST.FAT.BRUTO M.INTERNO'  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) AS  ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                9 QUERY_INFO


--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM proddta.f7611B A
JOIN PRODDTA.F7601B I ON (I.FHFCO = A.FDFCO AND I.FHbNNF = A.fdbNNF AND A.FDDCT = I.FHDCT AND A.FDN001 = I.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE A.FDPDCT IN ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
--A.fddct in ('EM','JA','JE','NO','NS','ST')
--AND A.fdmcu in ('        0180','        0280')
AND I.FHISSU>=121000
--AND I.FHISSU<=116031
AND A.FDNXTR NOT IN ('996','994')
AND A.FDLTTR >= '615'
--OR (A.FDNXTR IN ('999') AND A.FDPDCT IN ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')  -- VALOR LANCAMNETO DIRETO NA CONTABILIDADE
--AND A.fdbnnf = '42275'
AND A.fdBVIS <> 0
)

UNION ALL   --- VALOR DO ICMS  ABATIMENTO DA RECEITA

(SELECT         TO_DATE(SUBSTR(I.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                A.fdbicm/100 AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311210.001'))   AS CONTA_II,
				TRIM(TO_CHAR('311210001'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('ICMS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Impostos s/ Vendas'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311210001      ICMS')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                10 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM proddta.f7611B A
JOIN PRODDTA.F7601B I ON (I.FHFCO = A.FDFCO AND I.FHbNNF = A.fdbNNF AND A.FDDCT = I.FHDCT AND A.FDN001 = I.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE
A.FDPDCT IN ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
AND I.FHISSU>=121000
--and I.FHISSU<=116031
AND A.FDNXTR NOT IN ('996','994')
AND A.FDLTTR >= '615'
--AND A.fdbnnf = '42275'
--AND B.dpbrnop IN (5101,5102,5118,5401,5551,6101,6102,6107,6108,6109,6116,6401,7101,7127)
)

UNION ALL   --- DEVOLUÇÕES MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                ((A.fdaexp/100)+(A.fdbipi/100)+(A.fdBVIS/100)-(A.fdBDIZ/100)) AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311220.001'))   AS CONTA_II,
				TRIM(TO_CHAR('311220001'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('ICMS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Devoluções'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311220001 DEV.VENDA MERC.INTERNO')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                11 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE A.FDPDCT IN ('VR','VX')
AND AA.FHISSU>=121000
--AND A.FDISSU<=116031
AND A.FDNXTR IN ('615','610','617','620','999')
AND B.dpbrnop NOT IN (1949)
)

UNION ALL   --- DEVOLUÇÕES IPI  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (A.fdbipi/100)*(-1) AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311220.002'))   AS CONTA_II,
				TRIM(TO_CHAR('311220002'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('ICMS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Devoluções'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311220002 IPI DEV.VENDA M.INTERNO')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                12 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE A.FDPDCT IN ('VR','VX')
AND AA.FHISSU>=121000
--AND A.FDISSU<=116031
AND A.FDNXTR IN ('615','610','617','620','999')
AND B.dpbrnop NOT IN (1949)
)

UNION ALL   --- DEVOLUÇÕES ICMS  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (A.fdbicm/100)*(-1) AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311220.003'))   AS CONTA_II,
				TRIM(TO_CHAR('311220003'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('ICMS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Devoluções'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311220003 ICMS DEV.VENDA M.INTERNO')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                13 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE A.FDPDCT IN ('VR','VX')
AND AA.FHISSU>=121000
--AND A.FDISSU<=116031
AND A.FDNXTR IN ('615','610','617','620','999')
AND B.dpbrnop NOT IN (1949)
)

UNION ALL   --- DEVOLUÇÕES ICMS ST  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (A.fdBVIS/100)*(-1) AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311220.006'))   AS CONTA_II,
				TRIM(TO_CHAR('311220006'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('ICMS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Devoluções'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311220006 ICMS ST DEV.VENDA M.INTERNO')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                14 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE A.FDPDCT IN ('VR','VX')
AND AA.FHISSU>=121000
--AND A.FDISSU<=116031
AND A.FDNXTR IN ('615','610','617','620','999')
AND B.dpbrnop NOT IN (1949)
)

UNION ALL   --- DEVOLUÇÕES PIS  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (AB.TDBRTXA/100)*(-1) AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311220.004'))   AS CONTA_II,
				TRIM(TO_CHAR('311220004'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('PIS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Devoluções'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311220004 PIS DEV.VENDA M.INTERNO')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                15 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN PRODDTA.F76B011 AB ON (AB.TDBNNF = A.FDBNNF AND AB.TDBSER = A.FDBSER AND AB.TDDCT = A.FDDCT AND AB.TDN001 = A.FDN001 AND AB.TDUKID = A.FDUKID AND AB.TDBRTX = '05')
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE AA.FHISSU>=121000
AND A.FDNXTR IN ('615','610','617','620','999')
AND AB.tdbrtx = '05'
AND A.fdpdct IN ('VR','VX')
AND B.dpbrnop NOT IN (1949)
)

UNION ALL   --- DEVOLUÇÕES COFINS  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (AB.TDBRTXA/100)*(-1) AS VALOR_TRANSACAO,

                TRIM(TO_CHAR('100.311220.005'))   AS CONTA_II,
				TRIM(TO_CHAR('311220005'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('COFINS')) AS DESCRICAO_CONTA_II,
				NULL AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Devoluções'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311220005 COFINS DEV.VENDA M.INTERNO')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                16 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN PRODDTA.F76B011 AB ON (AB.TDBNNF = A.FDBNNF AND AB.TDBSER = A.FDBSER AND AB.TDDCT = A.FDDCT AND AB.TDN001 = A.FDN001 AND AB.TDUKID = A.FDUKID AND AB.TDBRTX = '06')
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE AA.FHISSU>=121000
--and AA.FHISSU<=116031
AND A.FDNXTR IN ('615','610','617','620','999')
AND AB.tdbrtx = '06'
AND A.fdpdct IN ('VR','VX')
AND B.dpbrnop NOT IN (1949)
--and A.fdbnnf = 194685
)

UNION ALL   --- PIS  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (AB.TDBRTXA/100) AS VALOR_TRANSACAO,
                TRIM(TO_CHAR('100.311210.003'))   AS CONTA_II,
				TRIM(TO_CHAR('311210003'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('PIS S/ RECEITA BRUTA')) AS DESCRICAO_CONTA_II,
				CAST('PIS NF' || A.fdbnnf || a.fdglc AS VARCHAR2(30)) AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Impostos s/ Vendas'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311210003      PIS S/ RECEITA BRUTA          ')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                15 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN PRODDTA.F76B011 AB ON (AB.TDBNNF = A.FDBNNF AND AB.TDBSER = A.FDBSER AND AB.TDDCT = A.FDDCT AND AB.TDN001 = A.FDN001 AND AB.TDUKID = A.FDUKID AND AB.TDBRTX = '05')
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE AA.FHISSU>=121000
AND A.FDNXTR IN ('615','610','617','620','999')
AND AB.tdbrtx = '05'
AND A.fdpdct IN  ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
AND B.dpbrnop NOT IN (1949)
)

UNION ALL   --- COFINS  MERCADO INTERNO

(SELECT         TO_DATE(SUBSTR(AA.FHISSU,2,5),'YYDDD') AS DATA_LANCAMENTO,
                A.FDPDCT AS TIPO_DOCUMENTO,
                TO_CHAR(A.fddct) AS NUM_DOCUMENTO,
                (AB.TDBRTXA/100) AS VALOR_TRANSACAO,
                TRIM(TO_CHAR('100.311210.004'))   AS CONTA_II,
				TRIM(TO_CHAR('311210004'))  AS CONTA_ESTRUTURA,
				TRIM(TO_CHAR('COFINS')) AS DESCRICAO_CONTA_II,
				CAST('COFINS NF' || A.fdbnnf || a.fdglc AS VARCHAR2(30)) AS EXPLICACAO,
				NULL AS CHAVE_CONTA,
				TO_CHAR('(-) ABATIMENTOS DA RECEITA    ') AS CONTA,
                TRIM(TO_CHAR('Impostos s/ Vendas'))  AS CONTA_I,
				NULL AS  ORDEM_CONTA,
                TO_CHAR('311210004      COFINS                        ')  AS CONTA_COMPLETA,
                D.MCMCU || ' ' || D.MCDL01 AS CENTRO_CUSTO,
                0 as percentual,
				A.FDCO || ' - ' || E.CCNAME AS EMPRESA,
                TRIM(CASE WHEN C.imsrp1='3' THEN '200 LATEX SAO ROQUE - FABRICA II' ELSE '100 LATEX SAO ROQUE - 3 MAIO' END) AS FILIAL,
				--D.MCMCU || ' ' || D.MCDL01 AS FILIAL,
                B.dpbrnop CFOP,
                A.fdbnnf NOTA,
                CAST(C.IMLITM AS VARCHAR2(25)) as ITEM,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S1' and trim(c.imsrp1) = trim(drky)))) AS VARCHAR2(30)) as Linha,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S2' and trim(c.imsrp2) = trim(drky)))) AS VARCHAR2(30)) as Tamanho,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S3' and trim(c.imsrp3) = trim(drky)))) AS VARCHAR2(30)) as Tipo,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S4' and trim(c.imsrp4) = trim(drky)))) AS VARCHAR2(30)) as Cor,
CAST(TRIM(TO_CHAR((select drdl01 from prodctl.F0005 where drsy = '41' and drrt = 'S5' and trim(c.imsrp5) = trim(drky)))) AS VARCHAR2(30)) as Embalagem,
                16 QUERY_INFO
--C.imsrp1 Linha_Prod,
--A.FDLOTN LOTE,

FROM PRODDTA.F7601B AA
JOIN proddta.f7611B A ON (AA.FHFCO = A.FDFCO AND AA.FHbNNF = A.fdbNNF AND A.FDDCT = AA.FHDCT AND A.FDN001 = AA.FHN001)
JOIN PRODDTA.F76B011 AB ON (AB.TDBNNF = A.FDBNNF AND AB.TDBSER = A.FDBSER AND AB.TDDCT = A.FDDCT AND AB.TDN001 = A.FDN001 AND AB.TDUKID = A.FDUKID AND AB.TDBRTX = '06')
JOIN proddta.f76B200 B ON (B.dpbnop = A.fdbnop AND B.dpbsop = A.fdbsop AND B.dpfco = A.fdfco)
JOIN PRODDTA.F4101 C ON (C.IMLITM = A.FDLITM AND C.imsrp1 IN ('0','1','2','3','4','L'))
LEFT JOIN PRODDTA.F0006 D ON (D.MCMCU = A.FDMCU)
JOIN PRODDTA.F0010 E ON  (E.CCCO = A.FDCO)
WHERE AA.FHISSU>=121000
--and AA.FHISSU<=116031
AND A.FDNXTR IN ('615','610','617','620','999')
AND AB.tdbrtx = '06'
AND A.fdpdct IN  ('AV','S1','S6','S7','SA','SJ','SM','SO','SX')
AND B.dpbrnop NOT IN (1949)
--and A.fdbnnf = 194685
)