#!/usr/bin/env bash
# Nettoie et vérifie la configuration Supabase lue dans les variables du dépôt GitHub.
#
# Entrée  : RAW_URL, RAW_KEY (vides = mode démo)
# Sortie  : SUPABASE_URL et SUPABASE_ANON_KEY propres, ajoutées à $GITHUB_ENV
#           (ou affichées si GITHUB_ENV n'existe pas, pour un test local)
#
# Un copier-coller ajoute souvent un espace ou un retour à la ligne invisible :
# on les retire, puis on refuse les erreurs fréquentes avec un message clair.
set -euo pipefail

error() { echo "::error title=Configuration Supabase::$1"; exit 1; }

# Contenu décodé d'une ancienne clé Supabase (JWT) : on y lit le rôle (anon ou service_role).
jwt_role() {
  local p
  p="$(cut -d. -f2 <<<"$1" | tr '_-' '/+')"
  while (( ${#p} % 4 )); do p+="="; done
  base64 -d <<<"$p" 2>/dev/null || true
}

url="$(printf '%s' "${RAW_URL:-}" | tr -d '[:space:]')"
key="$(printf '%s' "${RAW_KEY:-}" | tr -d '[:space:]')"
url="${url%/}"                 # https://xxx.supabase.co/ → https://xxx.supabase.co
url="${url%/rest/v1}"          # adresse de l'API collée à la place de l'adresse du projet

if [[ -z "$url" && -z "$key" ]]; then
  echo "Aucune variable Supabase : le jeu sera publié en mode démo."
elif [[ -z "$url" ]]; then
  error "La variable SUPABASE_URL est vide alors que SUPABASE_ANON_KEY est remplie."
elif [[ -z "$key" ]]; then
  error "La variable SUPABASE_ANON_KEY est vide alors que SUPABASE_URL est remplie."
elif [[ "$url" == *"supabase.com/dashboard"* ]]; then
  error "SUPABASE_URL contient l'adresse du tableau de bord. Il faut la « Project URL » (https://xxxx.supabase.co), visible via le bouton Connect du projet."
elif [[ ! "$url" =~ ^https://[^/]+$ ]]; then
  error "SUPABASE_URL doit ressembler à https://xxxx.supabase.co (valeur reçue : « $url »)."
elif [[ "$key" == sb_secret_* ]]; then
  error "SUPABASE_ANON_KEY contient la clé SECRÈTE. Utilisez la clé publique (sb_publishable_… ou anon), et régénérez la clé secrète dans Supabase car elle a été exposée."
elif [[ "$key" == eyJ* ]] && jwt_role "$key" | grep -q 'service_role'; then
  error "SUPABASE_ANON_KEY contient la clé « service_role » (secrète). Utilisez la clé « anon public », et régénérez la clé service_role dans Supabase car elle a été exposée."
elif [[ ! "$key" =~ ^(sb_publishable_|eyJ) ]]; then
  error "SUPABASE_ANON_KEY ne ressemble pas à une clé publique Supabase (attendu : sb_publishable_… ou eyJ…)."
else
  echo "Supabase configuré : $url (clé publique de ${#key} caractères)."
fi

out="${GITHUB_ENV:-/dev/stdout}"
{
  echo "SUPABASE_URL=$url"
  echo "SUPABASE_ANON_KEY=$key"
} >>"$out"
