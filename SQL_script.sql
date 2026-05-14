
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
