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

-- Application des recommandations

-- mise en place clôture journalière des ventes
CREATE TABLE controle_completude_ventes (
id_controle SERIAL PRIMARY KEY,
date_vente DATE NOT NULL,
nb_ventes_base INTEGER,
nb_ventes_logs INTEGER,
ca_base NUMERIC(12,2),
ca_logs NUMERIC(12,2),
ecart_ca NUMERIC(12,2),
statut VARCHAR(10) NOT NULL 
	CHECK(statut IN('ANOMALIE', 'CONFORME')),
date_controle TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
id_controleur VARCHAR,
commentaires TEXT
);

DROP TABLE controle_completude_ventes;
SELECT * FROM controle_completude_ventes;

CREATE OR REPLACE PROCEDURE ca_ventes_chargees(p_date_vente TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
	v_nb_ventes_base INTEGER;
	v_nb_ventes_logs INTEGER;
	v_ca_base NUMERIC(12,2);
	v_ca_logs NUMERIC(12,2);
	v_statut VARCHAR(10);
	v_commentaires TEXT;
	
	--v_ pour indiquer qu'il s'agit de variables. p_ pour paramètre
BEGIN
	-- Nombre de ventes et CA réellement présents dans la table vente
	SELECT
	COUNT(*),
	SUM(ROUND(p.prix::numeric, 2))
INTO
	v_nb_ventes_base,
	v_ca_base
FROM vente v
JOIN produit p ON v.ean = p.ean
JOIN calendrier c ON c.date = v.date
WHERE CONCAT(c.jour,'/',c.mois,'/',c.annee) = p_date_vente;

	-- Nombre de ventes et CA présents dans logs_ventes
	SELECT
	COUNT(DISTINCT lv.id_ligne),
	SUM(ROUND(p.prix::numeric, 2))
INTO
	v_nb_ventes_logs,
	v_ca_logs
FROM (
	-- on reconstitue une ligne ean en faisant pivoter toutes les données grâce à MAX (CASE WHEN)
	SELECT
		id_ligne,
		"date",
		MAX(CASE WHEN champs = 'EAN' THEN detail END) AS ean
	FROM logs
	WHERE table_insert = 'Ventes'
	GROUP BY id_ligne,"date"
) lv
JOIN produit p ON lv.ean = p.ean
JOIN calendrier c ON c.date = lv."date"
WHERE CONCAT(c.jour,'/',c.mois,'/',c.annee) = p_date_vente;

-- attribution du statut
IF v_nb_ventes_base = v_nb_ventes_logs
	AND v_ca_base = v_ca_logs THEN
	v_statut := 'CONFORME';
	v_commentaires := 'Les ventes présentes en base correspondent aux insertions dans les logs';
ELSE
	v_statut := 'ANOMALIE';
	v_commentaires := 'Un écart a été détecté entre les logs et la table vente.';
END IF;

-- Enregistrer les résultats dans la table de contrôle
INSERT INTO controle_completude_ventes(
	date_vente,
	nb_ventes_base,
	nb_ventes_logs,
	ca_base,
	ca_logs,
	ecart_ca,
	statut,
	date_controle,
	id_controleur,
	commentaires 
)
VALUES (
	p_date_vente::DATE,
	v_nb_ventes_base,
	v_nb_ventes_logs,
	v_ca_base,
	v_ca_logs,
	v_ca_base - v_ca_logs,
	v_statut,
	CURRENT_TIMESTAMP,
	CURRENT_USER,
	v_commentaires
);
END;
$$;
DROP PROCEDURE ca_ventes_chargees(text);

CALL ca_ventes_chargees('14/8/2024','jkuiueozbzk');
CALL ca_ventes_chargees('15/8/2024','jkuiueozbzk');
CALL ca_ventes_chargees('14/8/2024','postgres');
CALL ca_ventes_chargees('14/8/2024');
CALL ca_ventes_chargees('15/8/2024');

SELECT * FROM controle_completude_ventes;

-- Séparer la date des ventes et la date d'insertion

ALTER TABLE logs_ventes
ADD COLUMN date_vente TEXT;

UPDATE logs_ventes
SET date_vente = (
    CASE 
        WHEN champs = 'Date' THEN detail
    END
);

-- statistiques de la base de données 
SELECT 
	* 
FROM pg_stat_database
WHERE datname = 'smartmarket'; 

-- statistiques des tables 
SELECT * FROM pg_stat_user_tables; 
-- Identifier les tables les plus modifiées
SELECT
    relname AS table_name,
    n_tup_ins AS insertions,
    n_tup_upd AS updates,
    n_tup_del AS suppressions,
    n_live_tup AS lignes_estimees
FROM pg_stat_user_tables
ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC;

-- afficher les activités en cours 
SELECT * FROM pg_stat_activity;
-- identifier les requetes en cours
SELECT
    pid,
    usename,
    datname,
    state,
    query_start,
    query
FROM pg_stat_activity
WHERE state <> 'idle';


-- statistique des index
SELECT * FROM pg_stat_user_indexes;

-- Identifier les index peu ou pas utilisés
SELECT
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS nombre_utilisations
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC;


DROP VIEW ca_arrondi;
DROP VIEW ca_per_employe;

ALTER TABLE produit
ALTER COLUMN prix TYPE NUMERIC(12,2),
ADD CONSTRAINT prix_positif CHECK (prix > 0);

-- afficher les contraintes
SELECT
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'produit';

-- Restreindre les données personnes dans la couche BI
CREATE OR REPLACE VIEW employe_bi AS(
SELECT 
id_employe,
employe,
date_debut
FROM employe
);

CREATE OR REPLACE VIEW employe_bi_2 AS(
SELECT 
id_employe,
employe,
date_debut, 
SUBSTRING(mail FROM 1 FOR 3) || '****' AS obscured_mail, 
SUBSTRING(hash_mdp FROM 1 FOR 3) || '****' AS obscured_hash_mdp 
FROM employe
);

SELECT * FROM employe_bi;

CREATE TABLE logs(
id_user VARCHAR NOT NULL,
date INTEGER NOT NULL,
action VARCHAR(10) NOT NULL,
table_insert VARCHAR(10) NOT NULL,
id_ligne VARCHAR NOT NULL,
champs VARCHAR(20),
detail VARCHAR
);

SELECT * FROM logs;

CREATE TABLE employe_test AS(
SELECT * FROM employe
);

SELECT * FROM employe_test;
SELECT * FROM logs_employe;

CREATE TABLE logs_employe_test AS(
SELECT
id_user,
date,
action,
id_ligne,
champs,
detail
FROM logs_employe
);

SELECT * FROM logs_employe_test;

ALTER TABLE logs_employe_test
DROP COLUMN champs,
DROP COLUMN detail;

ALTER TABLE logs_employe_test
ADD COLUMN commentaire TEXT ; -- ajout d’une colonne commentaire


-- Automatisme pour compléter les tables logs
-- Création de la fonction trigger pour logs_employer
CREATE OR REPLACE FUNCTION logs_employe_trigger_function()
RETURNS TRIGGER AS $$
	BEGIN
		IF TG_OP ='INSERT' THEN -- operation for which the trigger was fired: INSERT, UPDATE, DELETE, or TRUNCATE
			INSERT INTO logs_employe_test (
				id_user,
				date,
				action,
				id_ligne,				
				commentaire
			)
			VALUES (
				CURRENT_USER, -- utilisateur PostgreSQL connecté
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				NEW.id_employe,
				'Nouvel employé'
			);
	
			RETURN NEW;
			
		ELSIF TG_OP = 'UPDATE' THEN
			INSERT INTO logs_employe_test (
				id_user,
				date,
				action,
				id_ligne,
				commentaire
			)
			VALUES (
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				OLD.id_employe, -- En cas d'update, l'id ne doit pas changer
				'Modification mot de passe'
			);
	
			RETURN NEW;
			
		ELSIF TG_OP = 'DELETE' THEN
			INSERT INTO logs_employe_test (
				id_user,
				date,
				action,
				id_ligne,
				commentaire
			)
			VALUES (
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30', -- Par exemple, pour le 14/8/2024 on a 45518
				TG_OP,
				OLD.id_employe,
				'Départ employé'
			);
	
			RETURN OLD;
		END IF;
		RETURN NULL;
	END;
$$ LANGUAGE plpgsql;
		
-- Création du trigger

CREATE OR REPLACE TRIGGER logs_employe_trigger_test
BEFORE INSERT OR UPDATE OR DELETE ON employe_test
	FOR EACH ROW
	EXECUTE FUNCTION logs_employe_trigger_function();

SELECT * FROM employe_test;	
SELECT * FROM logs_employe;
SELECT * 
FROM employe
WHERE id_employe = 'f6cd8ba3485769b3ad9bab5b7725858e';
INSERT INTO employe_test 
	VALUES ('36hgdg561sklsll36s','sules','Seb','Ules',CURRENT_DATE - DATE '1899-12-30','lkjoib25skkh563slkhkjlk');

UPDATE employe_test
SET hash_mdp = '1211113565lklkj'
WHERE id_employe = '6fa61d0ecae0b563fef18d36b2039c8e';

INSERT INTO employe_test 
	VALUES ('36hgdg561sklsll36UUKs','salesis','Seb','Alesis',CURRENT_DATE - DATE '1899-12-30','lkjoib25skkh563slkhkjlk');

DELETE 
FROM employe_test
WHERE id_employe = '36hgdg561sklsll36UUKs';

DELETE 
FROM employe_test
WHERE id_employe = '36hgdg561sklsll36s';

ALTER TABLE employe_test
ADD PRIMARY KEY (id_employe);

INSERT INTO employe_test 
	VALUES ('36hgdg561sklsll36s','sules','Seb','Ules',CURRENT_DATE - DATE '1899-12-30','lkjoib25skkh563slkhkjlk');

INSERT INTO employe_test 
	VALUES ('36hgdg561sklsll38s','mjouty','Marc','jouty',CURRENT_DATE - DATE '1899-12-30','lkjoib25skkh563slkhkjlk');

UPDATE employe_test
SET hash_mdp = '1211113565lklkj'
WHERE id_employe = '36hgdg561sklsll38s';

DELETE 
FROM employe_test
WHERE id_employe = '36hgdg561sklsll38s';

SELECT * FROM logs_employe_test;

-- Création de la table logs_ventes
CREATE TABLE vente_test AS(SELECT * FROM vente);
SELECT * FROM vente_test;

ALTER TABLE vente_test
ADD PRIMARY KEY (id_bdd);

CREATE TABLE logs_ventes_test AS(SELECT * FROM logs_ventes);
SELECT * FROM logs_ventes_test;

ALTER TABLE logs_ventes_test
ADD COLUMN customer_id VARCHAR(200),
ADD COLUMN id_employe VARCHAR(200),
ADD COLUMN ean VARCHAR(50),
ADD COLUMN date_achat DATE;

ALTER TABLE logs_ventes_test
ADD COLUMN id_ticket VARCHAR(10);

ALTER TABLE logs_ventes_test
ALTER COLUMN date_achat TYPE VARCHAR
USING date_achat::VARCHAR;

ALTER TABLE logs_ventes_test
DROP COLUMN date_vente;

-- transposer des lignes en colonnes
UPDATE logs_ventes_test
SET customer_id =(
	CASE 
		WHEN champs = 'CUSTUMER_ID' THEN detail
	END),
	id_employe = (
	CASE
		WHEN champs = 'id_employe' THEN detail
	END),
	ean = (
	CASE 
		WHEN champs = 'EAN' THEN detail
	END),
	date_achat = (
	CASE
		WHEN champs = 'Date' THEN detail
	END),
	id_ticket = (
	CASE
		WHEN champs = 'ID ticket' THEN detail
	END);

ALTER TABLE logs_ventes_test
DROP COLUMN table_insert,
DROP COLUMN champs,
DROP COLUMN detail
;

SELECT * FROM logs_ventes_test;

CREATE TABLE logs_ventes_test_clean AS
SELECT
    MAX(id_user) AS id_user,
	MAX(date) AS date_insertion,
	MAX(action) AS action,
	id_ligne,
    MAX(customer_id) AS customer_id,
    MAX(id_employe) AS id_employe,
    MAX(ean) AS ean,
    MAX(date_achat) AS date_achat,
    MAX(id_ticket) AS id_ticket
FROM logs_ventes_test
GROUP BY id_ligne;

DROP TABLE logs_ventes_test;

ALTER TABLE logs_ventes_test_clean
RENAME TO logs_ventes_test;

ALTER TABLE logs_ventes_test
ADD PRIMARY KEY (id_ligne);

SELECT constraint_name
FROM information_schema.table_constraints
WHERE table_name = 'logs_ventes_test'
AND constraint_type = 'PRIMARY KEY';

ALTER TABLE logs_ventes_test
DROP CONSTRAINT logs_ventes_test_pkey;

-- Ajout de la clé étrangère ean de produit afin de s'assurer que le produit est bien connu
/*
ALTER TABLE logs_ventes_test
ADD CONSTRAINT fk_logs_ventes_test_produit
FOREIGN KEY (ean)
REFERENCES produit(ean);
*/

SELECT * FROM vente;

-- Création de la fonction trigger pour les logs vente

CREATE OR REPLACE FUNCTION logs_ventes_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
	IF TG_OP = 'INSERT' THEN
		INSERT INTO logs_ventes_test(
			id_user,
			date_insertion,
			action,
			id_ligne,
			customer_id,
			id_employe,
			ean,
			date_achat,
			id_ticket
		)
		VALUES(
			CURRENT_USER,
			CURRENT_DATE - DATE '1899-12-30',
			TG_OP,
			NEW.id_bdd,
			NEW.customer_id,
			NEW.id_employe,
			NEW.ean,
			NEW.date,
			NEW.id_ticket				
		);
		RETURN NEW;
		
	ELSIF TG_OP = 'DELETE' THEN
		INSERT INTO logs_ventes_test(
			id_user,
			date_insertion,
			action,
			id_ligne,
			customer_id,
			id_employe,
			ean,
			date_achat,
			id_ticket
		)
		VALUES(
			CURRENT_USER,
			CURRENT_DATE - DATE '1899-12-30',
			TG_OP,
			OLD.id_bdd,
			OLD.customer_id,
			OLD.id_employe,
			OLD.ean,
			OLD.date,
			OLD.id_ticket				
		);
		RETURN OLD;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER logs_ventes_trigger
BEFORE INSERT OR  DELETE ON vente_test
	FOR EACH ROW
	EXECUTE FUNCTION logs_ventes_trigger_function();

SELECT * FROM vente_test;

ALTER TABLE vente_test
ADD CONSTRAINT vente_test_produit_fk
FOREIGN KEY (ean)
REFERENCES produit(ean);

ALTER TABLE vente_test
ADD CONSTRAINT vente_test_employe_fk
FOREIGN KEY (id_employe)
REFERENCES employe(id_employe);

ALTER TABLE vente_test
ADD CONSTRAINT vente_test_client_fk
FOREIGN KEY (customer_id)
REFERENCES client(customer_id);

INSERT INTO vente_test
	VALUES('TESTXXXXX','CUST-G42Z6WE8QLWJ','a7ada0770091e838e3dcd45265282820','1857802002765',CURRENT_DATE-DATE '1899-12-30','t_test');

SELECT * FROM vente_test
WHERE id_bdd = 'TESTXXXXX';

SELECT * FROM logs_ventes_test
WHERE date_insertion = 46160;

SELECT * FROM logs;


-- Vérifions les dates insertion des données de ventes qui sont indiqués dans le log
SELECT 
l.table_insert,
CONCAT(c.jour,'/',c.mois,'/',c.annee) AS date_insertion
FROM 
logs l
JOIN calendrier c
	ON l.date = c.date
WHERE l.table_insert = 'Ventes'
GROUP BY date_insertion,l.table_insert
;
 -- Vérification de l'écart de chiffre d'affaires
WITH ventes_log_15 AS (
SELECT
l.id_ligne AS vente,
CONCAT(c.jour,'/',c.mois,'/',c.annee) AS date_log,
v.ean
FROM logs l
JOIN vente v ON l.id_ligne = v.id_bdd
JOIN calendrier c ON l.date = c.date
WHERE l.date = '45519' AND l.table_insert = 'Ventes'
GROUP BY l.id_ligne,v.ean, date_log
)

SELECT
vl.date_log,
ROUND(SUM(p.prix::numeric),2) AS CA_update_15_aout
FROM ventes_log_15 vl
JOIN produit p
ON vl.ean = p.ean
GROUP BY vl.date_log
;

-- Création de la fonction trigger pour les logs clients
CREATE TABLE logs_client_test AS ( SELECT * FROM logs_client);

SELECT * FROM logs_client_test;

ALTER TABLE logs_client_test
DROP COLUMN table_insert;

ALTER TABLE logs_client_test
RENAME COLUMN date TO date_insertion;

CREATE TABLE client_test AS ( SELECT * FROM client);
SELECT * FROM client_test;

CREATE OR REPLACE FUNCTION logs_client_trigger_function()
RETURNS TRIGGER AS $$
	BEGIN
		IF TG_OP = 'INSERT' THEN
			INSERT INTO logs_client_test(
				id_user,
				date_insertion,
				action,
				id_ligne,
				champs,
				detail
			)
			VALUES (
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				NEW.customer_id,
				'date_inscription',
				CURRENT_DATE
			);
			RETURN NEW;
		ELSIF TG_OP = 'DELETE' THEN
			INSERT INTO logs_client_test(
				id_user,
				date_insertion,
				action,
				id_ligne,
				champs,
				detail
			)
			VALUES (
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				OLD.customer_id,
				'date_desinscription',
				CURRENT_DATE
			);
			RETURN OLD;
		END IF;
		RETURN NULL;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER logs_client_trigger
BEFORE INSERT OR  DELETE ON client_test
	FOR EACH ROW
	EXECUTE FUNCTION logs_client_trigger_function();

SELECT * FROM client_test;

INSERT INTO client_test
	VALUES('CUST-test',CURRENT_DATE);
INSERT INTO client_test
	VALUES('CUST-test2',CURRENT_DATE);

SELECT * FROM logs_client_test;

DELETE FROM client_test
WHERE customer_id = 'CUST-test2';

CREATE TABLE logs_produits_test AS(
SELECT * FROM logs_produits);

ALTER TABLE logs_produits_test
RENAME COLUMN date TO date_insertion;

ALTER TABLE logs_produits_test
DROP COLUMN table_insert;

ALTER TABLE logs_produits_test
ALTER COLUMN champs TYPE TEXT,
ALTER COLUMN detail TYPE TEXT;

CREATE TABLE produit_test AS(
SELECT * FROM produit);

ALTER TABLE produit_test
ADD PRIMARY KEY (ean);

SELECT * FROM logs_produits_test;

SELECT * FROM produit_test;

-- Création de la fonction trigger pour les logs produits
CREATE OR REPLACE FUNCTION logs_produits_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
	v_champs TEXT;
	v_detail TEXT;
	BEGIN
		IF TG_OP = 'INSERT' THEN
			INSERT INTO logs_produits_test(
				id_user,
				date_insertion,
				action,
				id_ligne,
				champs,
				detail				
			)
			VALUES(
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				NEW.ean,
				'new',
				CONCAT(NEW.libelle_produit, '-', NEW.prix)			
			);
			RETURN NEW;
			
		ELSIF TG_OP = 'UPDATE' THEN
			v_champs:= CONCAT_WS(',',
				CASE
					WHEN OLD.libelle_produit IS DISTINCT FROM NEW.libelle_produit
					THEN 'libelle produit'
				END,
				CASE
					WHEN OLD.prix IS DISTINCT FROM NEW.prix
					THEN 'prix'
				END
			);

			v_detail := CONCAT_WS(',',
				CASE
					WHEN OLD.libelle_produit IS DISTINCT FROM NEW.libelle_produit
					THEN NEW.libelle_produit
				END,
				CASE
					WHEN OLD.prix IS DISTINCT FROM NEW.prix
					THEN NEW.prix::TEXT
				END
			);
			INSERT INTO logs_produits_test(
				id_user,
				date_insertion,
				action,
				id_ligne,
				champs,
				detail				
			)
			VALUES(
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				OLD.ean,
				v_champs,
				v_detail			
			);
			RETURN OLD;
		ELSIF TG_OP = 'DELETE' THEN
			INSERT INTO logs_produits_test(
				id_user,
				date_insertion,
				action,
				id_ligne,
				champs,
				detail				
			)
			VALUES(
				CURRENT_USER,
				CURRENT_DATE - DATE '1899-12-30',
				TG_OP,
				OLD.ean,
				NULL,
				NULL			
			);
			RETURN OLD;
		END IF;
		RETURN NULL;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER logs_produits_trigger
BEFORE INSERT OR UPDATE OR DELETE ON produit_test
	FOR EACH ROW
	EXECUTE FUNCTION logs_produits_trigger_function();

SELECT * FROM produit_test;
SELECT * FROM logs_produits_test;
INSERT INTO produit_test
	VALUES
		('0000000','Produit test', 'test','500g de test',12.50),
		('0000002','Produit test2', 'test2','500g de test2',122.50);

UPDATE produit_test
SET libelle_produit='Produit test update'
WHERE ean='0000000';

UPDATE produit_test
SET prix= 12.00
WHERE ean='0000002';

UPDATE produit_test
SET libelle_produit='50g de test',
	prix = 2.50
WHERE ean='0000000';

DELETE FROM produit_test
WHERE ean = '0000002';


