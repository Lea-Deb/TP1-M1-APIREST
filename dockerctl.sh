#!/usr/bin/env bash
set -euo pipefail

SOCK=${DOCKER_SOCK:-/var/run/docker.sock}
BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

api() {
  local method=$1 path=$2 data=${3:-}
  local args=(-sS --unix-socket "$SOCK" -X "$method" -o "$BODY" -w '%{http_code}')
  if [[ -n $data ]]; then
    args+=(-H 'Content-Type: application/json' --data "$data")
  fi
  curl "${args[@]}" "http://localhost$path"
}

die() { echo "erreur : $*" >&2; exit 1; }

# Si code obtenu est dans la liste des codes attendus, on continue
# Sinon on affiche le message de Docker sur stderr et quitte avec 1
check() {
  local obtenu=$1
  shift
  local attendu
  for attendu in "$@"; do
    if [[ $obtenu == "$attendu" ]]; then
      return 0
    fi
  done
  local message
  message=$(jq -r '.message // empty' "$BODY" 2>/dev/null || true)
  die "code HTTP $obtenu : $message"
}

# verif que le nom contient que: lettres, chiffres, _ . et -
valid_name() {
  if [[ ! $1 =~ ^[A-Za-z0-9_.-]+$ ]]; then
    die "nom invalide : '$1' (lettres, chiffres, _ . et - uniquement)"
  fi
}

liste_tp() {
  local filtre filtre_url code
  filtre='{"label":["tp=api-rest"]}'
  filtre_url=$(jq -rn --arg f "$filtre" '$f | @uri')
  code=$(api GET "/containers/json?all=true&filters=$filtre_url")
  check "$code" 200
}

cmd_ls() {
  liste_tp
  printf '%-20s %-10s %-25s %s\n' NOM ETAT IMAGE PORTS
  # chaque conteneur : nom, état, image, ports.
  jq -r '.[] | [
      (.Names[0] | ltrimstr("/")),
      .State,
      .Image,
      (.Ports | map(select(.PublicPort != null) | "\(.PublicPort)->\(.PrivatePort)") | unique | join(","))
    ] | @tsv' "$BODY" |
  while IFS=$'\t' read -r nom etat image ports; do
    printf '%-20s %-10s %-25s %s\n' "$nom" "$etat" "$image" "$ports"
  done
}

cmd_run() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    die "usage : $0 run NOM IMAGE [PORT_HÔTE:PORT_CONTENEUR]"
  fi
  local nom=$1 image=$2 ports=${3:-}
  local code corps image_url id port_hote port_cont

  valid_name "$nom"
  if [[ -n $ports && ! $ports =~ ^[0-9]+:[0-9]+$ ]]; then
    die "ports invalides : '$ports' (format PORT_HÔTE:PORT_CONTENEUR)"
  fi

  #on regarde si l'image existe : 200 = oui, 404 = non
  code=$(api GET "/images/$image/json")
  if [[ $code == 404 ]]; then
    image_url=$(jq -rn --arg i "$image" '$i | @uri')
    code=$(api POST "/images/create?fromImage=$image_url")
    check "$code" 200
  else
    check "$code" 200
  fi

  if [[ -z $ports ]]; then
    corps=$(jq -n --arg image "$image" \
      '{Image: $image, Labels: {tp: "api-rest"}}')
  else
    port_hote=${ports%%:*}  
    port_cont=${ports##*:}   
    corps=$(jq -n --arg image "$image" --arg hote "$port_hote" --arg cont "$port_cont" '{
      Image: $image,
      Labels: {tp: "api-rest"},
      ExposedPorts: {($cont + "/tcp"): {}},
      HostConfig: {PortBindings: {($cont + "/tcp"): [{HostPort: $hote}]}}
    }')
  fi

  code=$(api POST "/containers/create?name=$nom" "$corps")
  check "$code" 201
  id=$(jq -r '.Id' "$BODY")
  code=$(api POST "/containers/$id/start")
  check "$code" 204
  echo "${id:0:12}"
}

cmd_exec() {
  if [[ $# -lt 2 ]]; then
    die "usage : $0 exec NOM COMMANDE..."
  fi
  local nom=$1
  shift
  valid_name "$nom"
  local cmd_json corps code id exit_code

  cmd_json=$(printf '%s\0' "$@" | jq -Rs 'split("\u0000") | .[:-1]')
  corps=$(jq -n --argjson cmd "$cmd_json" \
    '{Cmd: $cmd, AttachStdout: true, AttachStderr: true, Tty: true}')
  code=$(api POST "/containers/$nom/exec" "$corps")
  check "$code" 201
  id=$(jq -r '.Id' "$BODY")
  corps=$(jq -n '{Detach: false, Tty: true}')
  code=$(api POST "/exec/$id/start" "$corps")
  check "$code" 200
  cat "$BODY"
  code=$(api GET "/exec/$id/json")
  check "$code" 200
  exit_code=$(jq -r '.ExitCode' "$BODY")
  exit "$exit_code"
}

cmd_rm() {
  if [[ $# -ne 1 ]]; then
    die "usage : $0 rm NOM"
  fi
  local nom=$1 code label
  valid_name "$nom"

  code=$(api GET "/containers/$nom/json")
  if [[ $code == 404 ]]; then
    echo "$nom : déjà absent"
    return 0
  fi
  check "$code" 200
  label=$(jq -r '.Config.Labels.tp // ""' "$BODY")
  if [[ $label != "api-rest" ]]; then
    die "$nom n'est pas un conteneur du TP (label tp=api-rest absent)"
  fi

  code=$(api POST "/containers/$nom/stop?t=5")
  check "$code" 204 304

  code=$(api DELETE "/containers/$nom")
  check "$code" 204

  echo "$nom : supprimé"
}

cmd_clean() {
  local noms nom
  liste_tp
  noms=$(jq -r '.[].Names[0] | ltrimstr("/")' "$BODY")

  if [[ -z $noms ]]; then
    echo "aucun conteneur du TP"
    return 0
  fi

  #supp chaque conteneur de la liste avec cmd_rm
  while read -r nom; do
    cmd_rm "$nom"
  done <<< "$noms"
}

case ${1:-} in
  ls|run|exec|rm|clean) cmd=$1; shift; "cmd_$cmd" "$@" ;;
  *) echo "usage : $0 {ls|run|exec|rm|clean} …" >&2; exit 2 ;;
esac