-- Création des tables pour smartmarket à partir du script tiré de SQL Power Architect
CREATE TABLE calendrier (
                date INTEGER NOT NULL,
                annee INTEGER NOT NULL,
                mois INTEGER NOT NULL,
                jour INTEGER NOT NULL,
                mois_nom VARCHAR(10) NOT NULL,
                annee_mois INTEGER NOT NULL,
                jour_semaine INTEGER NOT NULL,
                trimestre VARCHAR(2) NOT NULL,
                CONSTRAINT calendrier_pk PRIMARY KEY (date)
);
COMMENT ON COLUMN calendrier.trimestre IS 'Q1, Q2, Q3, Q4';


CREATE TABLE employe (
                id_employe VARCHAR NOT NULL,
                employe VARCHAR NOT NULL,
                prenom VARCHAR NOT NULL,
                nom VARCHAR NOT NULL,
                date_debut INTEGER NOT NULL,
                hash_mdp VARCHAR NOT NULL,
                mail VARCHAR(100) NOT NULL,
                CONSTRAINT employe_pk PRIMARY KEY (id_employe)
);


CREATE TABLE client (
                customer_id VARCHAR NOT NULL,
                date_inscription DATE NOT NULL,
                CONSTRAINT client_pk PRIMARY KEY (customer_id)
);


CREATE TABLE produit (
                ean VARCHAR NOT NULL,
                categorie VARCHAR NOT NULL,
                rayon VARCHAR NOT NULL,
                libelle_produit VARCHAR NOT NULL,
                prix REAL NOT NULL,
                CONSTRAINT produit_pk PRIMARY KEY (ean)
);


CREATE TABLE vente (
                id_bdd VARCHAR NOT NULL,
                customer_id VARCHAR NOT NULL,
                id_employe VARCHAR NOT NULL,
                ean VARCHAR NOT NULL,
                date INTEGER NOT NULL,
                id_ticket VARCHAR NOT NULL,
                CONSTRAINT vente_pk PRIMARY KEY (id_bdd)
);

-- Rajout des contraintes de clés étrangères sur les tables
ALTER TABLE vente ADD CONSTRAINT calendrier_vente_fk
FOREIGN KEY (date)
REFERENCES calendrier (date)
ON DELETE NO ACTION
ON UPDATE NO ACTION
NOT DEFERRABLE;

ALTER TABLE vente ADD CONSTRAINT employe_vente_fk
FOREIGN KEY (id_employe)
REFERENCES employe (id_employe)
ON DELETE NO ACTION
ON UPDATE NO ACTION
NOT DEFERRABLE;

ALTER TABLE vente ADD CONSTRAINT client_vente_fk
FOREIGN KEY (customer_id)
REFERENCES client (customer_id)
ON DELETE NO ACTION
ON UPDATE NO ACTION
NOT DEFERRABLE;

ALTER TABLE vente ADD CONSTRAINT produit_vente_fk
FOREIGN KEY (ean)
REFERENCES produit (ean)
ON DELETE NO ACTION
ON UPDATE NO ACTION
NOT DEFERRABLE;

-- Import des .csv par table

SELECT * FROM calendrier;
SELECT * FROM client;
SELECT * FROM employe;
SELECT * FROM produit; -- pour ne pas avoir d'erreur d'import avec les prix, remplacer dans VSCode des , par des . pour les prix ((\d),(\d) $1.$2) dans le fichier .csv.
SELECT * FROM vente;

-- Récupérer des informations sur toutes les tables
SELECT
*
FROM
information_schema.tables
WHERE
table_catalog = 'smartmarket'
AND table_schema = 'public';
-- Récupérer des informations associées aux colonnes de la table `smartmarket`
SELECT
*
FROM
information_schema.columns
WHERE
table_catalog = 'smartmarket'
AND table_schema = 'public'


-- Chiffre d'affaires du 14 août

SELECT
SUM(p.prix) AS chiffre_affaires
FROM vente v 
JOIN produit p
	ON v.ean = p.ean;

/*
Le montant est très proche de 284243,88. La différence est légère.
Vérifions si ce n'est pas un problème d'arrondi.
*/
SELECT 
  SUM(p.prix) AS ca_brute,
  SUM(ROUND(p.prix::numeric, 2)) AS ca_arrondie
FROM vente v
JOIN produit p
	ON v.ean = p.ean;
--On a bien le 14 août 284243,88 € de chiffre d'affaires

-- chiffre d’affaires par client pour le top 10 des clients
SELECT 
  v.customer_id AS client,
  SUM(ROUND(p.prix::numeric, 2)) AS ca_arrondie
FROM vente v
JOIN produit p
	ON v.ean = p.ean
GROUP BY v.customer_id
ORDER BY ca_arrondie DESC
LIMIT 10;

--la part de chiffre d’affaires encaissé par employé
-- Créons une vue pour le chiffre d'affaires par employé
CREATE or REPLACE VIEW ca_per_employe AS(
SELECT
v.id_employe,
SUM(ROUND(p.prix::numeric, 2)) AS ca_arrondie_par_employe
FROM vente v
JOIN produit p
	ON v.ean = p.ean
GROUP BY v.id_employe
ORDER BY ca_arrondie_par_employe DESC
);

SELECT * FROM ca_per_employe;
-- créons une vue pour avoir le chiffre d'affaires total sur chaque ligne qui représente un employé.
CREATE or REPLACE VIEW ca_arrondi AS(
SELECT
id_employe,
SUM(ca_arrondie_par_employe) OVER() AS ca_arrondi
FROM ca_per_employe
);


SELECT * FROM ca_arrondi;

SELECT
e.employe,
CONCAT(c.jour,'/',c.mois,'/',c.annee) AS date_de_début,
cap.ca_arrondie_par_employe,
CONCAT(ROUND(cap.ca_arrondie_par_employe*100.0/ca_arrondi,2),'%') AS part_ca_par_employe
FROM ca_per_employe cap
JOIN ca_arrondi ca ON cap.id_employe = ca.id_employe
JOIN employe e ON e.id_employe = ca.id_employe
JOIN calendrier c ON e.date_debut = c.date
ORDER BY part_ca_par_employe DESC
;

DROP VIEW ca_arrondi;
DROP VIEW ca_per_employe;

-- Analyse des logs: créations des tables
CREATE TABLE logs_client (
id_user VARCHAR NOT NULL,
date INTEGER NOT NULL,
action VARCHAR(10) NOT NULL,
table_insert VARCHAR(10) NOT NULL,
id_ligne VARCHAR(50) NOT NULL,
champs VARCHAR(20) NOT NULL,
detail DATE NOT NULL
);

SELECT * FROM logs_client;

CREATE TABLE logs_employe (
id_user VARCHAR NOT NULL,
date INTEGER NOT NULL,
action VARCHAR(10) NOT NULL,
table_insert VARCHAR(10) NOT NULL,
id_ligne VARCHAR NOT NULL,
champs VARCHAR(10) NOT NULL,
detail VARCHAR NOT NULL
);

ALTER TABLE logs_employe
ALTER COLUMN detail DROP NOT NULL;

ALTER TABLE logs_employe
ALTER COLUMN champs DROP NOT NULL;

SELECT * FROM logs_employe;


CREATE TABLE logs_produits (
id_user VARCHAR NOT NULL,
date INTEGER NOT NULL,
action VARCHAR(10) NOT NULL,
table_insert VARCHAR(10) NOT NULL,
id_ligne VARCHAR NOT NULL,
champs VARCHAR(5) NOT NULL,
detail FLOAT NOT NULL
);

SELECT * FROM logs_produits;

CREATE TABLE logs_ventes (
id_user VARCHAR NOT NULL,
date INTEGER NOT NULL,
action VARCHAR(10) NOT NULL,
table_insert VARCHAR(10) NOT NULL,
id_ligne VARCHAR NOT NULL,
champs VARCHAR(20) NOT NULL,
detail VARCHAR NOT NULL
);

SELECT * FROM logs_ventes;

-- Vérifions les dates insertion des données de ventes qui sont indiqués dans le log
SELECT 
lv.table_insert,
lv.date,
CONCAT(c.jour,'/',c.mois,'/',c.annee) AS date_insertion
FROM 
logs_ventes lv
JOIN calendrier c
	ON lv.date = c.date
GROUP BY lv.date,date_insertion,lv.table_insert
;
-- Les données ont été insérées le 14 et le 15 août. Vérifions le montant du CA pour ces dates

WITH ventes_log_15 AS (
SELECT
lv.id_ligne AS vente,
CONCAT(c.jour,'/',c.mois,'/',c.annee) AS date_log,
v.ean
FROM logs_ventes lv
JOIN vente v ON lv.id_ligne = v.id_bdd
JOIN calendrier c ON lv.date = c.date
WHERE lv.date = '45519'
GROUP BY lv.id_ligne,v.ean, date_log
)

SELECT
vl.date_log,
ROUND(SUM(p.prix::numeric),2) AS CA_update_15_aout
FROM ventes_log_15 vl
JOIN produit p
ON vl.ean = p.ean
GROUP BY vl.date_log
;

-- Le montant de 9057,29 correspond à la différence entre les 2 valeurs de chiffres d'affaires.
-- Vérifions si les dates des ventes sont bien au 14 août pour les dates de log au 15 août.

SELECT * FROM logs_ventes;

WITH logs_ventes_date AS (
SELECT
lv.date AS date_log,
lv.table_insert,
lv.champs,
lv.detail
FROM logs_ventes lv
WHERE lv.champs = 'Date'
GROUP BY date_log, lv.champs, lv.detail,lv.table_insert
)
SELECT
lvd.date_log,
lvd.table_insert,
lvd.champs,
lvd.detail,
CONCAT(c.jour,'/',c.mois,'/',c.annee) AS date_ventes
FROM logs_ventes_date lvd
JOIN calendrier c ON lvd.detail::numeric = c.date
;

-- Récupérer les paramètres de configuration du serveur
SELECT
name,
setting,
unit,
category,
short_desc,
extra_desc,
context,
vartype,
source,
min_val,
max_val,
enumvals,
boot_val,
reset_val,
sourcefile,
sourceline,
pending_restart
FROM pg_settings;

-- Afficher les statistiques de la base de données
SELECT * FROM pg_stat_database;
-- Afficher les statistiques des tables utilisateur
SELECT * FROM pg_stat_user_tables;
-- Afficher les statistiques des index
SELECT * FROM pg_stat_user_indexes;
-- Afficher les activités en cours
SELECT * FROM pg_stat_activity;