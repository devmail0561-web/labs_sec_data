#!/usr/bin/env bash
# =============================================================
# TEST 02 — En-têtes HTTP de sécurité
# Référence OWASP : A05:2021 / OTG-CONFIG-007
# Code retour : 0 = OK | 1 = FAIL (en-tête critique manquant)
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://juiceshop:3000}"
REPORT="${REPORT_DIR:-/tmp}/test_headers_report.txt"
TIMEOUT=10
FAILED=0

HEADERS=$(curl -sI --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$TARGET" 2>/dev/null)

check_present() {
    local h="$1" sev="$2"
    if echo "$HEADERS" | grep -qi "^${h}:"; then
        local val; val=$(echo "$HEADERS" | grep -i "^${h}:" | head -1 | sed 's/\r//')
        echo "[PRÉSENT]  [$sev] $val"
    else
        echo "[MANQUANT] [$sev] $h"
        [ "$sev" = "CRITICAL" ] && FAILED=1
    fi
}

check_absent() {
    local h="$1" reason="$2"
    if echo "$HEADERS" | grep -qi "^${h}:"; then
        local val; val=$(echo "$HEADERS" | grep -i "^${h}:" | head -1 | sed 's/\r//')
        echo "[EXPOSÉ]   [WARNING] $val — $reason"
        FAILED=1
    else
        echo "[OK]       $h — correctement absent"
    fi
}

{
echo "============================================================"
echo " TEST 02 — En-têtes HTTP de sécurité"
echo " Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Cible : $TARGET"
echo "============================================================"
echo ""
echo "--- En-têtes bruts ---"
echo "$HEADERS"
echo ""
echo "--- Analyse ---"
check_present "Strict-Transport-Security" "CRITICAL"
check_present "Content-Security-Policy"   "CRITICAL"
check_present "X-Content-Type-Options"    "CRITICAL"
check_present "X-Frame-Options"           "WARNING"
check_present "Referrer-Policy"           "WARNING"
echo ""
echo "--- En-têtes indésirables ---"
check_absent "X-Powered-By" "révèle la technologie backend"
check_absent "Server"       "révèle le serveur web"
echo ""
[ "$FAILED" -eq 0 ] && echo " RÉSULTAT : SUCCESS" || echo " RÉSULTAT : FAILURE"
echo " RÉFÉRENCE : A05:2021 — Security Misconfiguration"
echo "============================================================"
} | tee "$REPORT"

exit "$FAILED"
