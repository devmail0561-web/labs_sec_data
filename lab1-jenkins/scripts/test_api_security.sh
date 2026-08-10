#!/usr/bin/env bash
# =============================================================
# TEST 05 — Exposition de données via les APIs
# Référence OWASP : A01:2021, A02:2021
# Code retour : 0 = OK | 1 = FAIL
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://juiceshop:3000}"
REPORT="${REPORT_DIR:-/tmp}/test_api_security_report.txt"
TIMEOUT=10
FAILED=0

test_endpoint() {
    local endpoint="$1" label="$2" pattern="$3"
    local code resp
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        "$TARGET$endpoint" 2>/dev/null || echo "000")
    resp=$(curl -s --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        "$TARGET$endpoint" 2>/dev/null)
    echo "[TEST] $label — $endpoint — HTTP $code"
    if [ "$code" = "200" ] && [ -n "$pattern" ] && echo "$resp" | grep -qi "$pattern"; then
        echo "  [CRITICAL] Données sensibles exposées sans authentification"
        FAILED=1
    elif [ "$code" = "401" ] || [ "$code" = "403" ]; then
        echo "  [OK] Endpoint protégé"
    else
        echo "  [INFO] Extrait : $(echo "$resp" | head -c 120 | tr -d '\n')..."
    fi
    echo ""
}

{
echo "============================================================"
echo " TEST 05 — Exposition APIs"
echo " Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Cible : $TARGET"
echo "============================================================"
echo ""
test_endpoint "/api/Users"                              "Liste utilisateurs"         "email"
test_endpoint "/api/Feedbacks"                          "Feedbacks"                  "UserId"
test_endpoint "/rest/admin/application-configuration"   "Config admin"               "secret\|key\|pass"
test_endpoint "/ftp/"                                   "Répertoire FTP"             "href"

[ "$FAILED" -eq 0 ] && echo " RÉSULTAT : SUCCESS" || echo " RÉSULTAT : FAILURE"
echo " RÉFÉRENCE : A01:2021 / A02:2021"
echo "============================================================"
} | tee "$REPORT"

exit "$FAILED"
