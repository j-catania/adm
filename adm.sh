#!/usr/bin/env bash

# ==========================================
# CONFIGURATION ET AUTO-UPDATE
# ==========================================
CURRENT_VERSION="1.0.0"
GITHUB_USER="j-catania"
GITHUB_REPO="adm"
BRANCH="main"
SCRIPT_PATH="/usr/local/bin/admin-menu"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}/admin-menu.sh"

# 1. Vérification des privilèges superutilisateur (root / sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Ce script d'administration nécessite les privilèges root." >&2
  echo "Usage : sudo $0" >&2
  exit 1
fi

# 2. Routine de mise à jour automatique
check_update() {
  # Requiert curl pour interroger GitHub
  if ! command -v curl >/dev/null 2>&1; then
    return 0
  fi

  # Récupération de la version distante (timeout court pour ne pas bloquer si pas de réseau)
  REMOTE_VERSION=$(curl -fsSL --connect-timeout 2 --max-time 3 "$RAW_URL" | grep -m1 '^CURRENT_VERSION=' | cut -d'"' -f2)

  if [ -n "$REMOTE_VERSION" ] && [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
    echo "Une nouvelle version ($REMOTE_VERSION) est disponible (actuelle : $CURRENT_VERSION)."
    echo "Mise à jour en cours..."
    
    TMP_FILE=$(mktemp)
    if curl -fsSL "$RAW_URL" -o "$TMP_FILE"; then
      chmod 755 "$TMP_FILE"
      chown root:root "$TMP_FILE"
      mv -f "$TMP_FILE" "$SCRIPT_PATH"
      echo "Mise à jour terminée vers la version $REMOTE_VERSION !"
      sleep 1
      # Relance immédiatement le nouveau script
      exec "$SCRIPT_PATH" "$@"
    else
      echo "Échec du téléchargement. Poursuite avec la version actuelle..."
      rm -f "$TMP_FILE"
      sleep 1
    fi
  fi
}

check_update

# 3. Gestion de l'interruption (Ctrl+C)
trap 'echo -e "\nFermeture du script d'\''administration."; exit 0' SIGINT SIGTERM

# 4. Détection des outils installés sur l'hôte
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

HAS_APACHE=false
HAS_CERTBOT=false
HAS_DOCKER=false

has_cmd apache2 && HAS_APACHE=true
has_cmd certbot && HAS_CERTBOT=true
has_cmd docker && HAS_DOCKER=true

# 5. Boucle principale du menu
while true; do
  clear
  echo "=========================================="
  echo "       CONSOLE D'ADMINISTRATION (v${CURRENT_VERSION})  "
  echo "=========================================="

  declare -A ACTIONS
  INDEX=1

  # Section Docker
  if [ "$HAS_DOCKER" = true ]; then
    echo "--- Docker ---"
    echo "  $INDEX) Suivre les logs d'un conteneur en direct"
    ACTIONS[$INDEX]="docker_logs"
    ((INDEX++))

    echo "  $INDEX) Lister l'état des conteneurs (docker ps)"
    ACTIONS[$INDEX]="docker_ps"
    ((INDEX++))
  fi

  # Section Apache2
  if [ "$HAS_APACHE" = true ]; then
    echo "--- Apache2 ---"
    echo "  $INDEX) Éditer la conf SSL (000-default-le-ssl.conf)"
    ACTIONS[$INDEX]="apache_edit_ssl"
    ((INDEX++))

    echo "  $INDEX) Suivre les logs d'accès en direct (/var/log/apache2)"
    ACTIONS[$INDEX]="apache_access_logs"
    ((INDEX++))

    echo "  $INDEX) Purger les logs Apache de plus d'un mois (> 30 jours)"
    ACTIONS[$INDEX]="apache_clean_logs"
    ((INDEX++))

    echo "  $INDEX) Tester et recharger Apache (systemctl reload)"
    ACTIONS[$INDEX]="apache_reload"
    ((INDEX++))
  fi

  # Section Certbot
  if [ "$HAS_APACHE" = true ] && [ "$HAS_CERTBOT" = true ]; then
    echo "--- Certificats SSL ---"
    echo "  $INDEX) Lancer Certbot pour Apache (certbot --apache)"
    ACTIONS[$INDEX]="certbot_apache"
    ((INDEX++))
  fi

  # Option de mise à jour forcée manuelle
  echo "--- Maintenance ---"
  echo "  u) Forcer la vérification de mise à jour"

  echo "------------------------------------------"
  echo "  q) Quitter"
  echo "=========================================="
  read -rp "Choix : " CHOIX

  case "$CHOIX" in
    q|Q)
      echo "Fermeture."
      exit 0
      ;;
    u|U)
      echo "Recherche de mise à jour forcée..."
      check_update
      echo "Le script est déjà à jour (v${CURRENT_VERSION})."
      sleep 1
      ;;
    *)
      ACTION="${ACTIONS[$CHOIX]}"
      case "$ACTION" in
        docker_logs)
          echo ""
          docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
          echo ""
          read -rp "Nom ou ID du conteneur à suivre : " CONTAINER_NAME
          if [ -n "$CONTAINER_NAME" ]; then
            echo "Affichage des 100 dernières lignes (Ctrl+C pour revenir au menu)..."
            (docker logs -f --tail 100 "$CONTAINER_NAME")
          fi
          read -rp "Appuie sur Entrée pour revenir au menu..."
          ;;
        docker_ps)
          echo ""
          docker ps -a
          echo ""
          read -rp "Appuie sur Entrée pour revenir au menu..."
          ;;
        apache_edit_ssl)
          CONF_FILE="/etc/apache2/sites-available/000-default-le-ssl.conf"
          if [ -f "$CONF_FILE" ]; then
            vi "$CONF_FILE"
          else
            echo "Fichier non trouvé : $CONF_FILE"
            read -rp "Appuie sur Entrée pour continuer..."
          fi
          ;;
        apache_access_logs)
          echo ""
          echo "Fichiers de logs d'accès trouvés dans /var/log/apache2/ :"
          mapfile -t LOG_FILES < <(find /var/log/apache2/ -maxdepth 1 -type f -name "*access*.log" 2>/dev/null)

          if [ ${#LOG_FILES[@]} -eq 0 ]; then
            echo "Aucun fichier de log d'accès (*access*.log) trouvé."
          else
            for i in "${!LOG_FILES[@]}"; do
              echo "  $((i+1))) ${LOG_FILES[$i]}"
            done
            echo "  t) Tous les logs d'accès en simultané"
            read -rp "Numéro du log ou 't' : " LOG_CHOICE

            echo "Affichage du flux en direct (Ctrl+C pour revenir au menu)..."
            if [ "$LOG_CHOICE" = "t" ] || [ "$LOG_CHOICE" = "T" ]; then
              (tail -f -n 50 "${LOG_FILES[@]}")
            elif [[ "$LOG_CHOICE" =~ ^[0-9]+$ ]] && [ "$LOG_CHOICE" -ge 1 ] && [ "$LOG_CHOICE" -le "${#LOG_FILES[@]}" ]; then
              TARGET_FILE="${LOG_FILES[$((LOG_CHOICE-1))]}"
              (tail -f -n 50 "$TARGET_FILE")
            else
              echo "Choix invalide."
            fi
          fi
          read -rp "Appuie sur Entrée pour revenir au menu..."
          ;;
        apache_clean_logs)
          echo ""
          echo "Recherche des logs Apache âgés de plus de 30 jours dans /var/log/apache2/..."
          mapfile -t OLD_LOGS < <(find /var/log/apache2/ -maxdepth 1 -type f \( -name "*.log*" -o -name "*.gz" \) -mtime +30 2>/dev/null)

          if [ ${#OLD_LOGS[@]} -eq 0 ]; then
            echo "Aucun log vieux de plus de 30 jours à supprimer."
          else
            echo "Fichiers concernés :"
            for f in "${OLD_LOGS[@]}"; do
              echo "  - $f"
            done
            echo ""
            read -rp "Confirmer la suppression définitive de ces fichiers ? (o/N) : " CONFIRM
            if [ "$CONFIRM" = "o" ] || [ "$CONFIRM" = "O" ]; then
              find /var/log/apache2/ -maxdepth 1 -type f \( -name "*.log*" -o -name "*.gz" \) -mtime +30 -delete
              echo "Nettoyage terminé."
            else
              echo "Action annulée."
            fi
          fi
          read -rp "Appuie sur Entrée pour revenir au menu..."
          ;;
        apache_reload)
          echo "Test de la configuration Apache..."
          if apache2ctl configtest; then
            systemctl reload apache2
            echo "Apache2 a été rechargé avec succès."
          else
            echo "Erreur détectée dans la configuration. Rechargement annulé."
          fi
          read -rp "Appuie sur Entrée pour revenir au menu..."
          ;;
        certbot_apache)
          certbot --apache
          read -rp "Appuie sur Entrée pour revenir au menu..."
          ;;
        *)
          echo "Option invalide."
          sleep 1
          ;;
      esac
      ;;
  esac
done
