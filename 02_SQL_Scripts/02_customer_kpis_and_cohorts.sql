/* ============================================================================
   PROJET  : Analyse du comportement d'achat des clients (Maroc)
   SCRIPT  : 02_customer_kpis_and_cohorts.sql
   OBJET   : KPIs de panier moyen, récurrence et analyse de cohortes mensuelles
   MOTEUR  : Microsoft SQL Server (T-SQL)
   ============================================================================ */

USE RetailClientDB;
GO

-- 1. PANIER MOYEN GLOBAL & PAR CATÉGORIE / VILLE
SELECT
    ROUND(AVG(Total_Amount), 2)   AS Panier_Moyen_Global,
    ROUND(SUM(Total_Amount), 2)   AS Chiffre_Affaires_MAD,
    COUNT(*)                      AS Nb_Transactions
FROM dbo.Fact_Transactions;
GO

SELECT
    c.City,
    COUNT(*)                        AS Nb_Transactions,
    ROUND(AVG(f.Total_Amount), 2)   AS Panier_Moyen,
    ROUND(SUM(f.Total_Amount), 2)   AS Chiffre_Affaires_MAD
FROM dbo.Fact_Transactions f
JOIN dbo.Dim_Customers c ON c.Customer_ID = f.Customer_ID
GROUP BY c.City
ORDER BY Chiffre_Affaires_MAD DESC;
GO

-- 2. FRÉQUENCE ET INTERVALLE MOYEN ENTRE ACHATS
WITH Achats_Ordonnes AS (
    SELECT
        Customer_ID,
        Transaction_Date,
        LAG(Transaction_Date) OVER (PARTITION BY Customer_ID ORDER BY Transaction_Date) AS Date_Achat_Precedent
    FROM dbo.Fact_Transactions
)
SELECT
    Customer_ID,
    COUNT(*) AS Nb_Achats,
    ROUND(AVG(CAST(DATEDIFF(DAY, Date_Achat_Precedent, Transaction_Date) AS FLOAT)), 1) AS Intervalle_Moyen_Jours
FROM Achats_Ordonnes
GROUP BY Customer_ID
ORDER BY Nb_Achats DESC;
GO

-- 3. ANALYSE DE COHORTES MENSUELLES (Rétention)
WITH Premiere_Commande AS (
    SELECT
        Customer_ID,
        DATEFROMPARTS(YEAR(MIN(Transaction_Date)), MONTH(MIN(Transaction_Date)), 1) AS Mois_Cohorte
    FROM dbo.Fact_Transactions
    GROUP BY Customer_ID
),
Activite_Mensuelle AS (
    SELECT DISTINCT
        Customer_ID,
        DATEFROMPARTS(YEAR(Transaction_Date), MONTH(Transaction_Date), 1) AS Mois_Activite
    FROM dbo.Fact_Transactions
),
Cohorte_Activite AS (
    SELECT
        p.Mois_Cohorte,
        DATEDIFF(MONTH, p.Mois_Cohorte, a.Mois_Activite) AS Mois_Ecoule,
        a.Customer_ID
    FROM Premiere_Commande p
    JOIN Activite_Mensuelle a ON a.Customer_ID = p.Customer_ID
),
Taille_Cohorte AS (
    SELECT Mois_Cohorte, COUNT(*) AS Taille_Initiale
    FROM Premiere_Commande
    GROUP BY Mois_Cohorte
)
SELECT
    ca.Mois_Cohorte,
    ca.Mois_Ecoule,
    COUNT(DISTINCT ca.Customer_ID)                                        AS Nb_Clients_Actifs,
    tc.Taille_Initiale,
    ROUND(100.0 * COUNT(DISTINCT ca.Customer_ID) / tc.Taille_Initiale, 1) AS Taux_Retention_Pct
FROM Cohorte_Activite ca
JOIN Taille_Cohorte tc ON tc.Mois_Cohorte = ca.Mois_Cohorte
GROUP BY ca.Mois_Cohorte, ca.Mois_Ecoule, tc.Taille_Initiale
ORDER BY ca.Mois_Cohorte, ca.Mois_Ecoule;
GO