-- =========================================================
-- Covoiturage — Données de référence (entreprise, services, postes)
-- Adresse de l'entreprise : valeur par défaut, à modifier si besoin
-- =========================================================

INSERT INTO entreprise (nom, adresse, latitude, longitude)
VALUES ('Entreprise Démo (fictive)', 'Rue Alfred Kastler, 14000 Caen', 49.211900, -0.366800);

INSERT INTO service (nom) VALUES
    ('Comptabilité'),
    ('Production'),
    ('Entretien');

INSERT INTO poste (service_id, libelle, heure_debut, heure_fin) VALUES
    ((SELECT id FROM service WHERE nom = 'Comptabilité'), 'Comptabilité — journée',         '09:00:00', '17:00:00'),
    ((SELECT id FROM service WHERE nom = 'Production'),   'Production — équipe matin',      '05:00:00', '13:00:00'),
    ((SELECT id FROM service WHERE nom = 'Production'),   'Production — équipe après-midi', '13:00:00', '21:00:00'),
    ((SELECT id FROM service WHERE nom = 'Entretien'),    'Entretien — après-midi',         '13:00:00', '21:00:00');
