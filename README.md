# Projet 4 — Auditez un environnement de données
### SuperSmartMarket — Audit du cube OLAP et des incohérences de chiffre d'affaires

🇫🇷 [Français](#-français) · 🇬🇧 [English](#-english)

---

## 🇫🇷 Français

### 1. Contexte et mission

**SuperSmartMarket** est une chaîne de supermarchés française en plein développement, qui mise sur l'hyper-personnalisation de l'expérience client (coupons personnalisés, recommandations, recettes basées sur l'historique d'achat). L'entreprise s'appuie sur un environnement de données composé d'une base opérationnelle **SQL Server**, d'un entrepôt **OLAP** (Microsoft Azure Analysis Services), de l'outil de restitution **Power BI**, et d'un site internet / ERP.

Le pôle Business Intelligence constate une **instabilité du chiffre d'affaires historique** : un montant déjà calculé peut évoluer après coup. L'exemple déclencheur concerne le **14 août 2024** : un chiffre d'affaires de **275 186,59 €** observé initialement, puis réévalué à **284 243,88 €** deux jours plus tard, alors que les magasins étaient fermés le 15 août.

En tant que Data Engineer intégré à l'équipe Data Support, la mission consiste à :
- produire un **dictionnaire de données** et un **schéma relationnel** à partir de l'extraction plate du cube OLAP,
- créer un **prototype de base de données** (POC) pour vérifier les chiffres affichés dans Power BI,
- **analyser les logs** pour comprendre l'origine des écarts,
- formuler des **recommandations** pour fiabiliser durablement les données.

### 2. Architecture auditée

```
SQL Server (base en live) ──► Cube OLAP (Azure Analysis Services) ──► Power BI (dataviz)
        │
        └────────────────────► Site internet / ERP
```

- **SQL Server** : source de vérité, alimentée en temps réel (transactions, ventes, clients...)
- **Cube OLAP** : extrait et organise les données pour l'analyse multidimensionnelle (temps, produit, rayon...)
- **Power BI** : restitution des tableaux de bord aux utilisateurs métier

Le périmètre de l'audit porte sur l'extraction OLAP (fichier plat) et les logs applicatifs de la journée du 14 août 2024. Les traitements ETL entre SQL Server et le cube ne sont **pas** dans le périmètre (aucun accès fourni).

### 3. Modèle de données

À partir du fichier Excel extrait du cube OLAP (5 tables : ventes, produits, clients, calendrier, employés), un **schéma en étoile** a été reconstitué avec **SQL Power Architect** :

- **`vente`** (table de faits) : `id_bdd`, `customer_id` (FK), `id_employe` (FK), `ean` (FK), `date` (FK vers calendrier), `id_ticket`
- **`produit`** (dimension) : `ean` (PK), `categorie`, `rayon`, `libelle_produit`, `prix`
- **`client`** (dimension) : `customer_id` (PK), `date_inscription`
- **`calendrier`** (dimension) : `date` (PK), `annee`, `mois`, `jour`, `mois_nom`, `annee_mois`, `jour_semaine`, `trimestre`
- **`employe`** (dimension) : `id_employe` (PK), `employe`, `prenom`, `nom`, `date_debut`, `hash_mdp`, `mail`

Un **dictionnaire de données complet** (table par table, log par log) est fourni dans le fichier `dictionnaire_donnees.xlsx`, ainsi qu'un lexique des termes métier et techniques.

⚠️ La table `employe` contient des données personnelles/sensibles (`hash_mdp`, `nom`, `prenom`, `mail`) dont la présence en environnement analytique est questionnée dans les constats de l'audit.

### 4. Prototype (POC)

Une base **PostgreSQL locale** a été créée pour reproduire les analyses en SQL :
- création des tables à partir des scripts générés par SQL Power Architect,
- chargement des données extraites du fichier Excel,
- écriture de requêtes SQL pour vérifier les indicateurs demandés par Hugo (responsable BI).

Les scripts fournis sont des **prototypes PostgreSQL** ; ils devront être adaptés syntaxiquement pour être exécutés sur SQL Server / Azure Analysis Services.

### 5. Résultats des vérifications

| Indicateur | Résultat |
|---|---|
| Chiffre d'affaires du 14 août 2024 | **284 243,88 €** (confirmé) |
| Écart avec le 1er montant observé (275 186,59 €) | **9 057,29 €** |
| Top 10 clients par chiffre d'affaires | Calculé via jointure `vente` / `produit`, groupé par `customer_id` |
| Part du chiffre d'affaires par employé | Calculée via vues SQL (`ca_per_employe`, `ca_arrondi`) |

### 6. Analyse des logs

Quatre tables de logs (`logs_client`, `logs_employe`, `logs_produits`, `logs_ventes`) ont été reconstruites à partir de la table `logs` brute, avec des **fonctions trigger PostgreSQL** simulant leur alimentation automatique (INSERT / UPDATE / DELETE selon les tables).

**Constat clé** : l'analyse des logs montre que des ventes rattachées à la date commerciale du **14 août** ont été insérées en base **le 15 août 2024**. Cela indique un **retard d'intégration / de synchronisation** entre la source SQL Server et le cube OLAP, qui explique l'écart de chiffre d'affaires observé.

### 7. Constats de l'audit et évaluation des risques

| ID | Constat | Probabilité | Impact | Niveau de risque |
|---|---|---|---|---|
| VUL001 | Désynchronisation SQL Server / cube OLAP | Élevée | Élevé | **CRITIQUE** |
| VUL002 | Absence de supervision technique de la base | Élevée | Élevé | **CRITIQUE** |
| VUL003 | Données personnelles/sensibles dans le cube OLAP | Moyenne | Élevé | **ÉLEVÉ** |
| VUL004 | Documentation insuffisante du modèle de données | Élevée | Moyen | **ÉLEVÉ** |
| VUL005 | Qualité, nommage et typage des données perfectibles | Moyenne | Moyen | **MOYEN** |

*(Méthode qualitative risque = probabilité × impact, référentiels ISO/IEC 27005, NIST SP 800-30, ANSSI EBIOS)*

### 8. Recommandations

1. **Réconciliation SQL Server / cube OLAP** : mise en place d'une procédure PostgreSQL (`reconcilier_source_cube`) comparant, pour une date donnée, le nombre de ventes/produits/tickets et le chiffre d'affaires entre la source et le cube (via une vue matérialisée simulant le cube).
2. **Supervision technique de la base de données** : requêtes de monitoring (tables les plus modifiées, requêtes actives, requêtes bloquées) via `pg_stat_user_tables` / `pg_stat_activity` côté PostgreSQL, avec leurs équivalents SQL Server (DMV : `sys.dm_db_index_operational_stats`, `sys.dm_exec_requests`), extensible au cube OLAP (DMV `$System`) et à Power BI (journal d'activité, API REST).
3. **Restriction des données personnelles en couche BI** : création d'une vue `employe_bi` exposant uniquement les colonnes nécessaires à l'analyse (sans `hash_mdp`, `nom`, `prenom`, `mail`).
4. **Formalisation du dictionnaire de données et documentation** du modèle relationnel, des cardinalités et des règles de calcul du chiffre d'affaires.
5. **Amélioration du typage, du nommage et de la qualité des données** : contraintes `NOT NULL`, `UNIQUE`, `CHECK`, `FOREIGN KEY`, conversion des colonnes numériques de date en type `DATE`, homogénéisation du nommage des colonnes et des libellés produits.

### 9. Conclusion

L'audit confirme que le chiffre d'affaires correct du 14 août 2024 est de **284 243,88 €**. L'écart observé (9 057,29 €) est cohérent avec une **intégration tardive de ventes** ou un **retard de synchronisation** entre la source SQL Server et le cube OLAP — sans qu'il soit possible, faute d'accès aux logs ETL et aux historiques de rafraîchissement, d'en établir la cause technique exacte avec certitude. Le problème n'est donc pas un problème de calcul, mais un **problème de fiabilité du processus d'intégration et de publication des données**. Les recommandations visent à restaurer la confiance dans les indicateurs BI, sécuriser les données personnelles et documenter durablement le modèle de données.

### 10. Contenu du dépôt

| Fichier | Description |
|---|---|
| `Ulesie_Sebastien_1_presentation_052026.pptx` | Support de présentation de la mission (architecture, dictionnaire, schéma relationnel, résultats SQL, analyse des logs, recommandations) |
| `Ulesie_Sebastien_2_rapport-audit_052026.pdf` | Rapport d'audit complet (constats, preuves, évaluation des risques, recommandations, scripts SQL en annexe) |
| `Ulesie_Sebastien_3_dictionnaire_donnees_052026.xlsx` | Dictionnaire de données détaillé (tables `vente`, `produit`, `client`, `calendrier`, `employe` et leurs logs, + lexique) |
| `Projet4-Sebastien.ipynb` | Notebook d'audit : exploration des données, création du POC PostgreSQL, requêtes SQL, chargement et analyse des logs, correction dynamique de la base |

### 11. Reproduire le POC en local

```bash
# 1. Créer une base PostgreSQL locale (ou SQLite/MySQL)
createdb supersmartmarket

# 2. Installer les dépendances Python utilisées dans le notebook
pip install pandas numpy unidecode sqlalchemy python-dotenv psycopg2-binary

# 3. Configurer les identifiants de connexion dans un fichier .env
#    (lu via python-dotenv / sqlalchemy dans le notebook)

# 4. Exécuter le notebook Projet4-Sebastien.ipynb pour :
#    - explorer le fichier Excel extrait du cube OLAP
#    - créer les tables (vente, produit, client, calendrier, employe)
#    - charger les données
#    - exécuter les requêtes de vérification (CA du 14 août, top 10 clients, part par employé)
#    - charger et analyser les tables de logs
#    - tester les fonctions trigger de correction dynamique
```

---

## 🇬🇧 English

### 1. Context and mission

**SuperSmartMarket** is a growing French supermarket chain focused on hyper-personalizing the in-store customer experience (personalized coupons, purchase-history-based recommendations, tailored recipes). The company relies on a data environment made up of an operational **SQL Server** database, an **OLAP** warehouse (Microsoft Azure Analysis Services), the **Power BI** reporting tool, and a website/ERP.

The Business Intelligence team noticed that **historical revenue figures are unstable**: an already-computed amount can change afterwards. The triggering example concerns **August 14, 2024**: revenue was first reported at **€275,186.59**, then revised to **€284,243.88** two days later, even though all stores were closed on August 15.

As the Data Engineer joining the Data Support team, the mission is to:
- produce a **data dictionary** and a **relational schema** from the flat OLAP cube extract,
- build a **database prototype** (POC) to verify the figures shown in Power BI,
- **analyze the logs** to understand the root cause of the discrepancies,
- formulate **recommendations** to durably improve data reliability.

### 2. Audited architecture

```
SQL Server (live database) ──► OLAP Cube (Azure Analysis Services) ──► Power BI (dataviz)
        │
        └───────────────────────► Website / ERP
```

- **SQL Server**: source of truth, updated in real time (transactions, sales, customers...)
- **OLAP cube**: extracts and organizes data for multidimensional analysis (time, product, aisle...)
- **Power BI**: renders dashboards for business users

The audit scope covers the flat OLAP extract and the application logs for August 14, 2024. The ETL processes between SQL Server and the cube are **out of scope** (no access provided).

### 3. Data model

From the Excel file extracted from the OLAP cube (5 tables: sales, products, customers, calendar, employees), a **star schema** was rebuilt using **SQL Power Architect**:

- **`vente`** (fact table): `id_bdd`, `customer_id` (FK), `id_employe` (FK), `ean` (FK), `date` (FK to calendar), `id_ticket`
- **`produit`** (dimension): `ean` (PK), `categorie`, `rayon`, `libelle_produit`, `prix`
- **`client`** (dimension): `customer_id` (PK), `date_inscription`
- **`calendrier`** (dimension): `date` (PK), `annee`, `mois`, `jour`, `mois_nom`, `annee_mois`, `jour_semaine`, `trimestre`
- **`employe`** (dimension): `id_employe` (PK), `employe`, `prenom`, `nom`, `date_debut`, `hash_mdp`, `mail`

A **full data dictionary** (table by table, log by log) is provided in `dictionnaire_donnees.xlsx`, along with a glossary of business and technical terms.

⚠️ The `employe` table contains personal/sensitive data (`hash_mdp`, `nom`, `prenom`, `mail`), whose presence in an analytical environment is flagged as a finding in the audit.

### 4. Prototype (POC)

A **local PostgreSQL** database was created to reproduce the analyses in SQL:
- tables created from scripts generated by SQL Power Architect,
- data loaded from the extracted Excel file,
- SQL queries written to verify the indicators requested by Hugo (BI manager).

The provided scripts are **PostgreSQL prototypes**; they will need syntactic adaptation to run on SQL Server / Azure Analysis Services.

### 5. Verification results

| Indicator | Result |
|---|---|
| Revenue for August 14, 2024 | **€284,243.88** (confirmed) |
| Gap vs. first observed amount (€275,186.59) | **€9,057.29** |
| Top 10 customers by revenue | Computed via a `vente` / `produit` join, grouped by `customer_id` |
| Revenue share per employee | Computed via SQL views (`ca_per_employe`, `ca_arrondi`) |

### 6. Log analysis

Four log tables (`logs_client`, `logs_employe`, `logs_produits`, `logs_ventes`) were rebuilt from the raw `logs` table, with **PostgreSQL trigger functions** simulating their automatic population (INSERT / UPDATE / DELETE depending on the table).

**Key finding**: log analysis shows that sales tied to the commercial date of **August 14** were inserted into the database **on August 15, 2024**. This points to an **integration/synchronization delay** between the SQL Server source and the OLAP cube, which explains the observed revenue discrepancy.

### 7. Audit findings and risk assessment

| ID | Finding | Likelihood | Impact | Risk level |
|---|---|---|---|---|
| VUL001 | SQL Server / OLAP cube desynchronization | High | High | **CRITICAL** |
| VUL002 | No technical monitoring of the database | High | High | **CRITICAL** |
| VUL003 | Personal/sensitive data in the OLAP cube | Medium | High | **HIGH** |
| VUL004 | Insufficient documentation of the data model | High | Medium | **HIGH** |
| VUL005 | Data quality, naming, and typing could be improved | Medium | Medium | **MEDIUM** |

*(Qualitative method: risk = likelihood × impact, based on ISO/IEC 27005, NIST SP 800-30, ANSSI EBIOS)*

### 8. Recommendations

1. **SQL Server / OLAP cube reconciliation**: a PostgreSQL procedure (`reconcilier_source_cube`) comparing, for a given date, the number of sales/products/tickets and the revenue between the source and the cube (using a materialized view to simulate the cube).
2. **Technical database monitoring**: monitoring queries (most-modified tables, active queries, blocked queries) via `pg_stat_user_tables` / `pg_stat_activity` on PostgreSQL, with SQL Server equivalents (DMVs: `sys.dm_db_index_operational_stats`, `sys.dm_exec_requests`), extendable to the OLAP cube (`$System` DMVs) and to Power BI (activity log, REST API).
3. **Restrict personal data in the BI layer**: create an `employe_bi` view exposing only the columns needed for analysis (excluding `hash_mdp`, `nom`, `prenom`, `mail`).
4. **Formalize the data dictionary and document** the relational model, cardinalities, and revenue calculation rules.
5. **Improve typing, naming, and data quality**: `NOT NULL`, `UNIQUE`, `CHECK`, and `FOREIGN KEY` constraints, converting numeric date columns to a proper `DATE` type, and standardizing column naming and product labels.

### 9. Conclusion

The audit confirms that the correct revenue for August 14, 2024 is **€284,243.88**. The observed discrepancy (€9,057.29) is consistent with **late sales integration** or a **synchronization delay** between the SQL Server source and the OLAP cube — though, without access to ETL logs and cube refresh history, the exact technical cause cannot be established with certainty. The issue is therefore not a calculation error, but a **reliability problem in the data integration and publication process**. The recommendations aim to restore trust in BI indicators, secure personal data, and durably document the data model.

### 10. Repository contents

| File | Description |
|---|---|
| `Ulesie_Sebastien_1_presentation_052026.pptx` | Presentation deck covering the mission (architecture, data dictionary, relational schema, SQL results, log analysis, recommendations) |
| `Ulesie_Sebastien_2_rapport-audit_052026.pdf` | Full audit report (findings, evidence, risk assessment, recommendations, SQL scripts in appendix) |
| `Ulesie_Sebastien_3_dictionnaire_donnees_052026.xlsx` | Detailed data dictionary (`vente`, `produit`, `client`, `calendrier`, `employe` tables and their logs, plus a glossary) |
| `Projet4-Sebastien.ipynb` | Audit notebook: data exploration, PostgreSQL POC creation, SQL queries, log loading and analysis, dynamic database correction |

### 11. Reproducing the POC locally

```bash
# 1. Create a local PostgreSQL database (or SQLite/MySQL)
createdb supersmartmarket

# 2. Install the Python dependencies used in the notebook
pip install pandas numpy unidecode sqlalchemy python-dotenv psycopg2-binary

# 3. Configure connection credentials in a .env file
#    (read via python-dotenv / sqlalchemy in the notebook)

# 4. Run the Projet4-Sebastien.ipynb notebook to:
#    - explore the Excel file extracted from the OLAP cube
#    - create the tables (vente, produit, client, calendrier, employe)
#    - load the data
#    - run the verification queries (Aug 14 revenue, top 10 customers, employee share)
#    - load and analyze the log tables
#    - test the dynamic-correction trigger functions
```
