
CREATE TABLE calendrier (
                date_achat DATE NOT NULL,
                annee INTEGER NOT NULL,
                mois_nom VARCHAR(10) NOT NULL,
                mois INTEGER NOT NULL,
                annee_mois DATE NOT NULL,
                jour_semaine INTEGER NOT NULL,
                jour INTEGER NOT NULL,
                trimestre VARCHAR(2) NOT NULL,
                CONSTRAINT calendrier_pk PRIMARY KEY (date_achat)
);
COMMENT ON COLUMN calendrier.annee IS 'EXTRACT(YEAR FROM date_achat)';
COMMENT ON COLUMN calendrier.mois IS 'EXTRACT(MONTH FROM date_achat)
';
COMMENT ON COLUMN calendrier.annee_mois IS 'DATE_TRUNC(''month'',date_achat)';
COMMENT ON COLUMN calendrier.jour_semaine IS ' EXTRACT(ISODOW FROM date_achat)
The day of the week as Monday (1) to Sunday (7)';
COMMENT ON COLUMN calendrier.jour IS 'EXTRACT(DAY FROM date_achat)';
COMMENT ON COLUMN calendrier.trimestre IS 'Q1, Q2, Q3, Q4';


CREATE TABLE employe (
                id_employe VARCHAR NOT NULL,
                employe VARCHAR NOT NULL,
                date_debut DATE NOT NULL,
                mail VARCHAR(100) NOT NULL,
                CONSTRAINT employe_pk PRIMARY KEY (id_employe)
);
COMMENT ON COLUMN employe.mail IS 'rajouter dans le script 
mail VARCHAR(100) GENERATED ALWAYS AS (CONCAT(employe,''@supersmartmarket.fr'')) STORED';


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
                date_achat DATE NOT NULL,
                id_ticket VARCHAR NOT NULL,
                CONSTRAINT vente_pk PRIMARY KEY (id_bdd)
);


ALTER TABLE vente ADD CONSTRAINT calendrier_vente_fk
FOREIGN KEY (date_achat)
REFERENCES calendrier (date_achat)
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
