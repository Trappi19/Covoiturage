-- =========================================================
-- Covoiturage — Schéma initial (MariaDB, InnoDB, utf8mb4)
-- Appliqué automatiquement par Flyway au démarrage de l'API
-- =========================================================

-- Entreprise (une seule ligne : adresse fixe = destination de tous les trajets)
CREATE TABLE entreprise (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    nom         VARCHAR(100)  NOT NULL,
    adresse     VARCHAR(255)  NOT NULL,
    latitude    DECIMAL(9, 6) NOT NULL,
    longitude   DECIMAL(9, 6) NOT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Service (Comptabilité, Production, Entretien…)
CREATE TABLE service (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    nom  VARCHAR(50) NOT NULL,
    CONSTRAINT uq_service_nom UNIQUE (nom)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Poste = créneau horaire d'un service (un service peut avoir plusieurs équipes)
CREATE TABLE poste (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    service_id        INT          NOT NULL,
    libelle           VARCHAR(100) NOT NULL,
    heure_debut       TIME         NOT NULL,
    heure_fin         TIME         NOT NULL,
    jours_travailles  VARCHAR(27)  NOT NULL DEFAULT 'LUN,MAR,MER,JEU,VEN',
    CONSTRAINT fk_poste_service FOREIGN KEY (service_id) REFERENCES service (id),
    CONSTRAINT uq_poste_libelle UNIQUE (libelle),
    INDEX idx_poste_heure_debut (heure_debut),
    INDEX idx_poste_heure_fin (heure_fin)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Salarié
CREATE TABLE salarie (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    nom                VARCHAR(80)   NOT NULL,
    prenom             VARCHAR(80)   NOT NULL,
    email              VARCHAR(150)  NOT NULL,
    mot_de_passe_hash  VARCHAR(100)  NOT NULL,
    telephone          VARCHAR(20)   NULL,
    poste_id           INT           NOT NULL,
    adresse            VARCHAR(255)  NOT NULL,
    latitude           DECIMAL(9, 6) NOT NULL,
    longitude          DECIMAL(9, 6) NOT NULL,
    date_inscription   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_salarie_email UNIQUE (email),
    CONSTRAINT fk_salarie_poste FOREIGN KEY (poste_id) REFERENCES poste (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Véhicule (0 ou 1 par salarié)
CREATE TABLE vehicule (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    salarie_id       INT         NOT NULL,
    marque           VARCHAR(50) NOT NULL,
    modele           VARCHAR(50) NOT NULL,
    couleur          VARCHAR(30) NOT NULL,
    immatriculation  VARCHAR(9)  NOT NULL,          -- format AA-123-AA
    nb_places        TINYINT     NOT NULL,          -- places totales, conducteur inclus
    CONSTRAINT uq_vehicule_salarie UNIQUE (salarie_id),
    CONSTRAINT uq_vehicule_immat UNIQUE (immatriculation),
    CONSTRAINT ck_vehicule_places CHECK (nb_places BETWEEN 2 AND 9),
    CONSTRAINT fk_vehicule_salarie FOREIGN KEY (salarie_id) REFERENCES salarie (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Trajet (covoiturage proposé par un conducteur)
CREATE TABLE trajet (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    conducteur_id     INT          NOT NULL,
    vehicule_id       INT          NOT NULL,
    date_trajet       DATE         NOT NULL,
    sens              VARCHAR(10)  NOT NULL,                       -- ALLER / RETOUR
    heure             TIME         NOT NULL,                       -- début (aller) ou fin (retour) du poste
    places_proposees  TINYINT      NOT NULL,
    statut            VARCHAR(10)  NOT NULL DEFAULT 'PLANIFIE',    -- PLANIFIE / TERMINE / ANNULE
    commentaire       VARCHAR(255) NULL,
    date_creation     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_trajet_sens CHECK (sens IN ('ALLER', 'RETOUR')),
    CONSTRAINT ck_trajet_statut CHECK (statut IN ('PLANIFIE', 'TERMINE', 'ANNULE')),
    CONSTRAINT ck_trajet_places CHECK (places_proposees >= 1),
    -- un conducteur ne propose qu'un trajet par jour et par sens
    CONSTRAINT uq_trajet_conducteur_jour UNIQUE (conducteur_id, date_trajet, sens),
    CONSTRAINT fk_trajet_conducteur FOREIGN KEY (conducteur_id) REFERENCES salarie (id) ON DELETE CASCADE,
    CONSTRAINT fk_trajet_vehicule FOREIGN KEY (vehicule_id) REFERENCES vehicule (id),
    INDEX idx_trajet_recherche (date_trajet, sens, heure)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Réservation (demande d'un passager sur un trajet)
CREATE TABLE reservation (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    trajet_id     INT          NOT NULL,
    passager_id   INT          NOT NULL,
    statut        VARCHAR(12)  NOT NULL DEFAULT 'EN_ATTENTE',  -- EN_ATTENTE / ACCEPTEE / REFUSEE / ANNULEE
    message       VARCHAR(255) NULL,
    date_demande  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_reservation_statut CHECK (statut IN ('EN_ATTENTE', 'ACCEPTEE', 'REFUSEE', 'ANNULEE')),
    CONSTRAINT uq_reservation_trajet_passager UNIQUE (trajet_id, passager_id),
    CONSTRAINT fk_reservation_trajet FOREIGN KEY (trajet_id) REFERENCES trajet (id) ON DELETE CASCADE,
    CONSTRAINT fk_reservation_passager FOREIGN KEY (passager_id) REFERENCES salarie (id) ON DELETE CASCADE,
    INDEX idx_reservation_passager (passager_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- Évaluation (validation du trajet par un passager → points au conducteur)
CREATE TABLE evaluation (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    trajet_id         INT          NOT NULL,
    passager_id       INT          NOT NULL,
    conducteur_id     INT          NOT NULL,     -- dénormalisé pour accélérer le classement
    trajet_effectue   BOOLEAN      NOT NULL,
    note              TINYINT      NULL,         -- 1 à 5, NULL si trajet non effectué
    commentaire       VARCHAR(255) NULL,
    date_evaluation   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    points_attribues  INT          NOT NULL DEFAULT 0,
    CONSTRAINT ck_evaluation_note CHECK (note IS NULL OR note BETWEEN 1 AND 5),
    -- une seule évaluation par passager et par trajet
    CONSTRAINT uq_evaluation_trajet_passager UNIQUE (trajet_id, passager_id),
    CONSTRAINT fk_evaluation_trajet FOREIGN KEY (trajet_id) REFERENCES trajet (id) ON DELETE CASCADE,
    CONSTRAINT fk_evaluation_passager FOREIGN KEY (passager_id) REFERENCES salarie (id) ON DELETE CASCADE,
    CONSTRAINT fk_evaluation_conducteur FOREIGN KEY (conducteur_id) REFERENCES salarie (id) ON DELETE CASCADE,
    INDEX idx_evaluation_classement (conducteur_id, date_evaluation)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
