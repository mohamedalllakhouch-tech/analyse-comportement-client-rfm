/* ============================================================================
   PROJET  : Analyse du comportement d'achat des clients (Maroc)
   SCRIPT  : 01_schema_transactions.sql
   OBJET   : Création du schéma relationnel en étoile (Dimension & Faits)
   MOTEUR  : Microsoft SQL Server (T-SQL)
   BASE    : RetailClientDB
   ============================================================================ */

USE RetailClientDB;
GO

-- 1. Nettoyage sécurisé
IF OBJECT_ID('dbo.Fact_Transactions', 'U') IS NOT NULL 
    ALTER TABLE dbo.Fact_Transactions DROP CONSTRAINT IF EXISTS FK_Fact_Customer;
DROP TABLE IF EXISTS dbo.Fact_Transactions;
DROP TABLE IF EXISTS dbo.Dim_Customers;
GO

-- 2. Création de la Dimension Client (Dim_Customers)
CREATE TABLE dbo.Dim_Customers (
    Customer_ID     VARCHAR(50)   NOT NULL PRIMARY KEY,
    Gender          CHAR(1)       NULL CHECK (Gender IN ('F','M')),
    Age             SMALLINT      NULL CHECK (Age BETWEEN 0 AND 120),
    City            NVARCHAR(50)  NOT NULL,
    Age_Group       VARCHAR(10)   NULL
);
GO

INSERT INTO dbo.Dim_Customers (Customer_ID, Gender, Age, City, Age_Group)
SELECT DISTINCT
    Customer_ID,
    Gender,
    Age,
    City,
    CASE
        WHEN Age < 25 THEN '18-24'
        WHEN Age < 35 THEN '25-34'
        WHEN Age < 45 THEN '35-44'
        WHEN Age < 55 THEN '45-54'
        WHEN Age < 65 THEN '55-64'
        ELSE '65+'
    END AS Age_Group
FROM dbo.transactions_clients_maroc;
GO

-- 3. Création de la Table de Faits (Fact_Transactions)
CREATE TABLE dbo.Fact_Transactions (
    Transaction_ID     VARCHAR(50)     NOT NULL PRIMARY KEY,
    Customer_ID        VARCHAR(50)     NOT NULL,
    Transaction_Date   DATE            NOT NULL,
    Category           NVARCHAR(50)    NOT NULL,
    Unit_Price         DECIMAL(10,2)   NOT NULL CHECK (Unit_Price >= 0),
    Quantity           INT             NOT NULL CHECK (Quantity > 0),
    Total_Amount       DECIMAL(12,2)   NOT NULL CHECK (Total_Amount >= 0),
    Payment_Method     NVARCHAR(50)    NOT NULL,
    CONSTRAINT FK_Fact_Customer FOREIGN KEY (Customer_ID) REFERENCES dbo.Dim_Customers(Customer_ID)
);
GO

INSERT INTO dbo.Fact_Transactions (Transaction_ID, Customer_ID, Transaction_Date, Category, Unit_Price, Quantity, Total_Amount, Payment_Method)
SELECT Transaction_ID, Customer_ID, Transaction_Date, Category, Unit_Price, Quantity, Total_Amount, Payment_Method
FROM dbo.transactions_clients_maroc;
GO

-- 4. Création des Index pour optimiser les performances
CREATE INDEX IX_Fact_CustomerID ON dbo.Fact_Transactions (Customer_ID);
CREATE INDEX IX_Fact_TransDate  ON dbo.Fact_Transactions (Transaction_Date);
CREATE INDEX IX_Fact_Category   ON dbo.Fact_Transactions (Category);
CREATE INDEX IX_Dim_City        ON dbo.Dim_Customers (City);
GO

-- 5. Contrôles de validation
SELECT COUNT(*) AS Nb_Transactions FROM dbo.Fact_Transactions; -- Attendu : 800
SELECT COUNT(*) AS Nb_Clients FROM dbo.Dim_Customers;          -- Attendu : 178
GO