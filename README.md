# Server Admin Menu

Un script interactif en Bash conçu pour l'administration rapide et centralisée de serveurs Linux (Debian, Ubuntu). 

Le menu s'adapte dynamiquement aux outils installés sur la machine hôte (**Docker**, **Apache2**, **Certbot**) et intègre un système d'auto-mise à jour transparent depuis GitHub.

---

## Fonctionnalités

- **Détection dynamique :** n'affiche que les options correspondant aux binaires réellement présents sur le serveur.
- **Gestion Docker :** consultation rapide du statut des conteneurs (`docker ps -a`) et suivi des logs en direct (`tail -f`).
- **Gestion Apache2 :**
  - Édition directe du VirtualHost SSL principal (`000-default-le-ssl.conf`).
  - Suivi en temps réel des journaux d'accès (`/var/log/apache2/*access*.log`).
  - Purge manuelle sécurisée des logs âgés de plus de 30 jours (fichiers bruts et `.gz`).
  - Rechargement sécurisé du service avec validation préalable de la syntaxe (`apache2ctl configtest`).
- **Certificats SSL :** assistant interactif Let's Encrypt via `certbot --apache`.
- **Auto-update intégré :** vérifie la présence d'une nouvelle version sur GitHub à chaque démarrage et se met à jour automatiquement.
- **Sécurisation :** verrouillage strict exigeant les privilèges superutilisateur (`root`).

---

## Installation rapide

Exécute la commande suivante sur ton serveur pour installer le script dans `/usr/local/bin` :

```bash
sudo curl -fsSL [https://raw.githubusercontent.com/](https://raw.githubusercontent.com/)<ton-pseudo-github>/<nom-du-repo>/main/admin-menu.sh -o /usr/local/bin/admin-menu && sudo chmod 755 /usr/local/bin/admin-menu && sudo chown root:root /usr/local/bin/admin-menu
