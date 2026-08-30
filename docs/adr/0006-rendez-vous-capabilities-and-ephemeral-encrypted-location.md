# 0006 — Capacités et position chiffrée éphémère pour les Rendez-vous

- Statut : accepté
- Date : 2026-08-30

## Contexte

Un Rendez-vous doit accueillir une personne sans compte tout en lui donnant les
mêmes fonctions qu’à un ami invité. Il échange aussi une donnée plus sensible
que le plan lui-même : une position précise et temporaire. Un simple identifiant
dans une URL donnerait trop d’autorité, tandis qu’un chiffrement uniquement au
repos laisserait le serveur capable de suivre les Participants.

Le service doit néanmoins connaître la progression minimale — service canonique,
station ou section, statut et horaires — pour reconnaître une Jonction ratée et
recalculer le Plan de convergence.

## Décision

1. Une invitation par lien est une **capacité limitée à un Participant et à un
   Rendez-vous**. Le jeton brut sert uniquement à l’échange initial. La base ne
   conserve que son empreinte ; après acceptation, l’app reçoit une capacité de
   Participant et la présente dans un en-tête protégé, jamais dans une URL.
2. Le lien anonyme a la forme `/meet/{token}#k=…`. Le fragment contient la clé
   nécessaire au groupe et n’est pas envoyé au serveur par le navigateur. La
   projection publique écrite à la main ne contient que la station d’arrivée,
   la date, le prénom affiché de l’organisateur et la disponibilité du lien.
3. Pour un ami authentifié, chaque installation enregistre une clé publique
   Curve25519. La clé de groupe est enveloppée séparément pour chaque clé
   d’installation avec Curve25519, HKDF et ChaChaPoly. La clé privée et la clé de
   groupe restent dans le Trousseau de l’appareil.
4. Les coordonnées précises sont chiffrées sur l’appareil avec cette clé de
   groupe. Le serveur route seulement le ciphertext, la précision, la révision
   cryptographique et l’instant nécessaires à la fraîcheur ; il ne possède
   aucune clé capable de retrouver les coordonnées.
5. Tout changement de membres incrémente la révision cryptographique, invalide
   l’ancienne clé et suspend la position précise jusqu’à la distribution des
   nouvelles enveloppes. La progression en clair reste disponible pendant cette
   rotation.
6. L’origine privée et le trajet individuel complet suivent un régime différent :
   ils sont chiffrés au repos par le serveur avec une clé versionnée. Seuls leur
   propriétaire et le planificateur peuvent les utiliser. Les autres Participants
   reçoivent uniquement le premier embarquement et la partie déjà commune.
7. Redis conserve au plus la dernière présence chiffrée et son heartbeat avec
   une expiration de 120 secondes. Aucun échantillon précédent, aucune
   extrapolation et aucune coordonnée déchiffrée ne sont journalisés, envoyés par
   APNs ou inclus dans une Live Activity.
8. Les invitations expirent deux heures après l’arrivée cible. Le Rendez-vous et
   ses plans sont supprimés sept jours après l’événement ; les relations d’amitié
   persistent. L’arrêt, le départ du groupe, l’annulation et l’arrivée coupent
   immédiatement la publication live.

## Conséquences

- Une personne qui perd le fragment du lien ne peut pas récupérer la clé précise
  auprès du serveur ; elle doit recevoir un nouveau lien ou une nouvelle
  enveloppe. C’est la conséquence recherchée de l’incapacité du serveur à lire
  les positions.
- Un changement de membres crée volontairement une courte période en mode
  progression seule. L’interface doit la présenter comme une rotation de clé,
  pas fabriquer un point GPS.
- La capacité permet une participation anonyme sans ouvrir d’annuaire, de compte
  implicite ou d’accès à un autre Rendez-vous.
- Le serveur peut recalculer un rendez-vous sans connaître les coordonnées live,
  mais la progression nécessaire au recalcul n’est pas chiffrée de bout en bout.
- La page d’installation ne peut garantir aucune reprise différée native : elle
  conserve l’URL complète dans le navigateur et demande de rouvrir le lien après
  installation.
