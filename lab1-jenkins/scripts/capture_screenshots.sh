#!/usr/bin/env bash
# =============================================================
# Captures d'écran automatisées — LAB 1 Jenkins
# Usage : ./capture_screenshots.sh [--user admin] [--pass admin123]
#         [--out /chemin/captures]
# =============================================================
set -euo pipefail

# ── Paramètres ───────────────────────────────────────────────
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JUICE_URL="${JUICE_SHOP_URL:-http://localhost:3000}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin123}"
OUT_DIR="${CAPTURE_DIR:-/home/virus-one/cours_simac_l3/Semestre_6/Sec_data/projet/labs_v2/lab1-jenkins/captures}"
JOB_NAME="${JOB_NAME:-juice-shop-security}"
NO_BUILD=0

# Analyse des arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)     JENKINS_USER="$2";  shift 2 ;;
        --pass)     JENKINS_PASS="$2";  shift 2 ;;
        --out)      OUT_DIR="$2";       shift 2 ;;
        --job)      JOB_NAME="$2";      shift 2 ;;
        --no-build) NO_BUILD=1;         shift   ;;
        *) echo "Option inconnue : $1"; exit 1 ;;
    esac
done

mkdir -p "$OUT_DIR"
LOG="$OUT_DIR/capture.log"

# ── Helpers ───────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
ok()   { log "[OK]   $*"; }
fail() { log "[FAIL] $*"; }

# Screenshot Chrome headless avec authentification Basic (cookie de session Jenkins)
# $1 = URL  $2 = nom fichier (sans extension)  $3 = hauteur optionnelle
screenshot() {
    local url="$1" name="$2" height="${3:-900}"
    local out="$OUT_DIR/${name}.png"
    log "Capture : $name  →  $url"
    google-chrome \
        --headless=new \
        --disable-gpu \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-software-rasterizer \
        --disable-extensions \
        --window-size=1280,${height} \
        --screenshot="$out" \
        "$url" 2>/dev/null
    if [[ -f "$out" && $(stat -c%s "$out") -gt 5000 ]]; then
        ok "$out ($(stat -c%s "$out") octets)"
    else
        fail "Screenshot vide ou absent : $out"
    fi
}

# Screenshot avec cookie de session Jenkins (auth)
# Récupère d'abord un cookie de session via le formulaire de login
JENKINS_COOKIE_JAR="/tmp/jenkins_cookies_$$.txt"

authenticate_jenkins() {
    log "Authentification Jenkins ($JENKINS_USER)..."
    # Récupérer le crumb + cookie de session
    local crumb_json
    crumb_json=$(curl -s -c "$JENKINS_COOKIE_JAR" \
        -u "${JENKINS_USER}:${JENKINS_PASS}" \
        "${JENKINS_URL}/crumbIssuer/api/json" 2>/dev/null || echo "{}")
    JENKINS_CRUMB=$(echo "$crumb_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('crumb',''))" 2>/dev/null || echo "")
    if [[ -n "$JENKINS_CRUMB" ]]; then
        ok "Cookie de session Jenkins obtenu"
    else
        fail "Impossible d'obtenir le crumb Jenkins — vérifier user/pass"
    fi
}

screenshot_jenkins() {
    local path="$1" name="$2" height="${3:-900}"
    # Construire l'URL avec les credentials en Basic Auth dans l'URL
    # (Chrome headless accepte http://user:pass@host)
    local auth_url="${JENKINS_URL/http:\/\//http://${JENKINS_USER}:${JENKINS_PASS}@}"
    screenshot "${auth_url}${path}" "$name" "$height"
}

# ── API Jenkins : attendre que le job existe ──────────────────
wait_for_job() {
    local attempts=0
    while [[ $attempts -lt 10 ]]; do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" \
            -u "${JENKINS_USER}:${JENKINS_PASS}" \
            "${JENKINS_URL}/job/${JOB_NAME}/api/json" 2>/dev/null || echo "000")
        [[ "$code" == "200" ]] && return 0
        log "Job '$JOB_NAME' pas encore trouvé (HTTP $code) — attente 5s..."
        sleep 5
        attempts=$((attempts + 1))
    done
    return 1
}

# ── Déclencher un build et attendre sa fin ────────────────────
trigger_and_wait_build() {
    log "Déclenchement du build Jenkins..."
    local crumb_json
    crumb_json=$(curl -s -c "$JENKINS_COOKIE_JAR" -b "$JENKINS_COOKIE_JAR" \
        -u "${JENKINS_USER}:${JENKINS_PASS}" \
        "${JENKINS_URL}/crumbIssuer/api/json" 2>/dev/null)
    local crumb_field crumb_val
    crumb_field=$(echo "$crumb_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('crumbRequestField','Jenkins-Crumb'))" 2>/dev/null)
    crumb_val=$(echo "$crumb_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('crumb',''))" 2>/dev/null)

    curl -s -o /dev/null -X POST \
        -c "$JENKINS_COOKIE_JAR" -b "$JENKINS_COOKIE_JAR" \
        -u "${JENKINS_USER}:${JENKINS_PASS}" \
        -H "${crumb_field}: ${crumb_val}" \
        "${JENKINS_URL}/job/${JOB_NAME}/build" 2>/dev/null
    ok "Build déclenché"

    log "Attente de la fin du build (max 10 min)..."
    local attempts=0
    local build_num=""
    while [[ $attempts -lt 30 ]]; do
        sleep 5
        build_num=$(curl -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
            "${JENKINS_URL}/job/${JOB_NAME}/api/json" 2>/dev/null \
            | python3 -c "
import sys, json
d = json.load(sys.stdin)
b = d.get('lastBuild') or d.get('lastCompletedBuild') or d.get('lastUnsuccessfulBuild')
print(b['number'] if b else '')
" 2>/dev/null || echo "")
        [[ -n "$build_num" ]] && break
        log "  Attente numéro de build... ($((attempts * 5))s)"
        attempts=$((attempts + 1))
    done

    if [[ -z "$build_num" ]]; then
        fail "Impossible de récupérer le numéro de build — utilisation du numéro 1 par défaut"
        build_num=1
    fi
    export LAST_BUILD_NUM="$build_num"
    log "Build #${build_num} détecté — attente de la fin..."

    attempts=0
    while [[ $attempts -lt 120 ]]; do
        sleep 5
        local result
        result=$(curl -s -u "${JENKINS_USER}:${JENKINS_PASS}" \
            "${JENKINS_URL}/job/${JOB_NAME}/${build_num}/api/json" 2>/dev/null \
            | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result') or 'null')" 2>/dev/null || echo "null")
        if [[ "$result" != "null" && -n "$result" ]]; then
            ok "Build #${build_num} terminé — résultat : $result"
            export LAST_BUILD_RESULT="$result"
            return 0
        fi
        log "  Build en cours... ($((attempts * 5))s)"
        attempts=$((attempts + 1))
    done
    fail "Timeout — build trop long"
    export LAST_BUILD_RESULT="TIMEOUT"
    return 1
}

# ═══════════════════════════════════════════════════════════════
# DÉBUT DES CAPTURES
# ═══════════════════════════════════════════════════════════════
log "============================================================"
log " Captures LAB 1 — démarrage"
log " Sortie : $OUT_DIR"
log "============================================================"

authenticate_jenkins

# ── 1. Page d'accueil Juice Shop ──────────────────────────────
log "--- Juice Shop ---"
screenshot "${JUICE_URL}" "01_juiceshop_accueil"
screenshot "${JUICE_URL}/#/login" "02_juiceshop_login" 700

# ── 2. Interface Jenkins ──────────────────────────────────────
log "--- Jenkins ---"
screenshot_jenkins "/" "03_jenkins_dashboard"
screenshot_jenkins "/manage" "04_jenkins_manage" 1100

# ── 3. Vérifier/créer le job si absent ───────────────────────
log "--- Vérification du job '$JOB_NAME' ---"
JOB_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/job/${JOB_NAME}/api/json" 2>/dev/null || echo "000")

if [[ "$JOB_EXISTS" == "404" ]]; then
    log "Job absent — création via Groovy console..."
    CRUMB_JSON=$(curl -s -c "$JENKINS_COOKIE_JAR" -b "$JENKINS_COOKIE_JAR" \
        -u "${JENKINS_USER}:${JENKINS_PASS}" \
        "${JENKINS_URL}/crumbIssuer/api/json" 2>/dev/null)
    CF=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('crumbRequestField','Jenkins-Crumb'))" 2>/dev/null)
    CV=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('crumb',''))" 2>/dev/null)

    # Encoder le Jenkinsfile en base64 pour l'injecter sans problème d'échappement
    JENKINSFILE_LOCAL="$(dirname "$(dirname "$0")")/Jenkinsfile"
    [[ ! -f "$JENKINSFILE_LOCAL" ]] && JENKINSFILE_LOCAL="/home/virus-one/cours_simac_l3/Semestre_6/Sec_data/projet/labs_v2/lab1-jenkins/Jenkinsfile"
    B64_SCRIPT=$(base64 -w0 "$JENKINSFILE_LOCAL")

    GROOVY_RESULT=$(curl -s -c "$JENKINS_COOKIE_JAR" -b "$JENKINS_COOKIE_JAR" \
        -X POST "${JENKINS_URL}/scriptText" \
        -u "${JENKINS_USER}:${JENKINS_PASS}" \
        -H "${CF}: ${CV}" \
        --data-urlencode "script=
import jenkins.model.*
import org.jenkinsci.plugins.workflow.cps.*
import org.jenkinsci.plugins.workflow.job.*
def b64 = '${B64_SCRIPT}'
def scriptContent = new String(b64.decodeBase64())
def flowDef = new CpsFlowDefinition(scriptContent, true)
def job = Jenkins.instance.createProject(WorkflowJob, '${JOB_NAME}')
job.setDefinition(flowDef)
job.save()
Jenkins.instance.save()
println 'created'
" 2>/dev/null)

    if echo "$GROOVY_RESULT" | grep -q "created"; then
        ok "Job '$JOB_NAME' créé"
    else
        fail "Création du job échouée : $GROOVY_RESULT"
    fi
fi

# ── 4. Page du job ────────────────────────────────────────────
screenshot_jenkins "/job/${JOB_NAME}/" "05_jenkins_job_page"

# ── 5. Déclencher un build ───────────────────────────────────
if [[ "$NO_BUILD" -eq 0 ]]; then
    trigger_and_wait_build || true
    BUILD_NUM="${LAST_BUILD_NUM:-1}"
    screenshot_jenkins "/job/${JOB_NAME}/${BUILD_NUM}/console" "06_jenkins_build_console" 2000
    screenshot_jenkins "/job/${JOB_NAME}/${BUILD_NUM}/" "07_jenkins_build_detail"
    # Stage view (plugin Blue Ocean ou Stage View)
    screenshot_jenkins "/job/${JOB_NAME}/" "08_jenkins_job_apres_build" 1000
fi

# ── 6. Preuves d'exploitation (scripts bash en local) ────────
log "--- Exécution des scripts de détection en local ---"
export JUICE_SHOP_URL="$JUICE_URL"
export REPORT_DIR="$OUT_DIR/reports"
export BUILD_NUMBER="local"
mkdir -p "$OUT_DIR/reports/evidence"

for script in test_http test_headers test_methods test_auth test_api_security test_exploitation; do
    SCRIPT_PATH="/home/virus-one/cours_simac_l3/Semestre_6/Sec_data/projet/labs_v2/lab1-jenkins/scripts/${script}.sh"
    if [[ -x "$SCRIPT_PATH" ]]; then
        log "Exécution : ${script}.sh"
        bash "$SCRIPT_PATH" > "$OUT_DIR/reports/${script}_output.txt" 2>&1 || true
        ok "Sortie : $OUT_DIR/reports/${script}_output.txt"
    fi
done

# Générer le rapport final
SCRIPT_PATH="/home/virus-one/cours_simac_l3/Semestre_6/Sec_data/projet/labs_v2/lab1-jenkins/scripts/generate_report.sh"
[[ -x "$SCRIPT_PATH" ]] && bash "$SCRIPT_PATH" > "$OUT_DIR/reports/rapport_final.txt" 2>&1 || true

# ── 7. Captures des endpoints vulnérables ────────────────────
log "--- Captures endpoints Juice Shop ---"
screenshot "${JUICE_URL}/ftp/" "09_juiceshop_ftp_directory"
screenshot "${JUICE_URL}/#/score-board" "10_juiceshop_scoreboard" 1200

# ── 8. Récapitulatif ─────────────────────────────────────────
log "============================================================"
log " TERMINÉ"
log " Captures : $(ls "$OUT_DIR"/*.png 2>/dev/null | wc -l) fichiers PNG"
log " Rapports : $(ls "$OUT_DIR/reports"/*.txt 2>/dev/null | wc -l) fichiers TXT"
log " Répertoire : $OUT_DIR"
log "============================================================"
ls -lh "$OUT_DIR"/*.png 2>/dev/null | awk '{print "  "$NF, $5}'
echo ""
log "Rapport final : $OUT_DIR/reports/rapport_final.txt"

# Nettoyage cookie jar
rm -f "$JENKINS_COOKIE_JAR"
