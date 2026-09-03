/* ============================================================================
   PROJET  : Analyse du comportement d'achat des clients (Maroc)
   SCRIPT  : 03_rfm_customer_segmentation.sql
   OBJET   : Scoring RFM (Récence, Fréquence, Montant) et segmentation marketing
   MOTEUR  : Microsoft SQL Server (T-SQL)
   ============================================================================ */

USE RetailClientDB;
GO

-- 1. Vue des métriques RFM brutes
CREATE OR ALTER VIEW dbo.vw_RFM_Base AS
SELECT
    f.Customer_ID,
    DATEDIFF(
        DAY,
        MAX(f.Transaction_Date),
        (SELECT DATEADD(DAY, 1, MAX(Transaction_Date)) FROM dbo.Fact_Transactions)
    )                                       AS Recence_Jours,
    COUNT(*)                                AS Frequence,
    ROUND(SUM(f.Total_Amount), 2)           AS Montant
FROM dbo.Fact_Transactions f
GROUP BY f.Customer_ID;
GO

-- 2. Vue d'attribution des scores (Quintiles 1 à 5)
CREATE OR ALTER VIEW dbo.vw_RFM_Scores AS
SELECT
    Customer_ID,
    Recence_Jours,
    Frequence,
    Montant,
    (6 - NTILE(5) OVER (ORDER BY Recence_Jours))   AS R_Score,
    NTILE(5) OVER (ORDER BY Frequence)              AS F_Score,
    NTILE(5) OVER (ORDER BY Montant)                AS M_Score
FROM dbo.vw_RFM_Base;
GO

-- 3. Vue de segmentation marketing finale
CREATE OR ALTER VIEW dbo.vw_RFM_Segments AS
SELECT
    s.Customer_ID,
    c.City,
    c.Gender,
    c.Age_Group,
    s.Recence_Jours,
    s.Frequence,
    s.Montant,
    s.R_Score,
    s.F_Score,
    s.M_Score,
    CONCAT(s.R_Score, s.F_Score, s.M_Score) AS RFM_Code,
    (s.R_Score + s.F_Score + s.M_Score)     AS RFM_Score_Total,
    CASE
        WHEN s.R_Score >= 4 AND s.F_Score >= 4 AND s.M_Score >= 4 THEN 'Champions'
        WHEN s.R_Score >= 3 AND s.F_Score >= 3 AND s.M_Score >= 3 THEN 'Clients fidèles'
        WHEN s.R_Score >= 4 AND s.F_Score <= 2                     THEN 'Nouveaux clients'
        WHEN s.R_Score >= 3 AND s.F_Score <= 2 AND s.M_Score >= 3 THEN 'Fort potentiel'
        WHEN s.R_Score <= 2 AND s.F_Score >= 4 AND s.M_Score >= 4 THEN 'À risque (ex-gros clients)'
        WHEN s.R_Score <= 2 AND s.F_Score BETWEEN 2 AND 3         THEN 'En hibernation'
        WHEN s.R_Score <= 2 AND s.F_Score <= 2 AND s.M_Score <= 2 THEN 'Clients perdus'
        ELSE 'Clients standards'
    END AS Segment_RFM
FROM dbo.vw_RFM_Scores s
JOIN dbo.Dim_Customers c ON c.Customer_ID = s.Customer_ID;
GO

-- 4. Synthèse par segment (Test de la vue)
SELECT
    Segment_RFM,
    COUNT(*)                                                        AS Nb_Clients,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)              AS Pct_Clients,
    ROUND(SUM(Montant), 2)                                          AS Chiffre_Affaires_MAD,
    ROUND(AVG(Montant), 2)                                          AS Panier_Moyen_Client
FROM dbo.vw_RFM_Segments
GROUP BY Segment_RFM
ORDER BY Chiffre_Affaires_MAD DESC;
GO