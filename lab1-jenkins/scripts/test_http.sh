#!/usr/bin/env bash
# =============================================================
# TEST 01 — Vérification de disponibilité HTTP
# Référence OWASP : Baseline
# Code retour : 0 = OK | 1 = FAIL
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://juiceshop:3000}"
REPORT="${REPORT_DIR:-/tmp}/test_http_report.txt"
TIMEOUT=10
FAILED=0

check() {
    local url="$1" expected="$2" label="$3"
    local actual
    actual=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
    if [ "$actual" = "$expected" ]; then
        echo "[PASS] $label — HTTP $actual"
    else
        echo "[FAIL] $label — HTTP $actual (attendu $expected)"
        FAILED=1
    fi
}

{
echo "============================================================"
echo " TEST 01 — Disponibilité HTTP"
echo " Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Cible : $TARGET"
echo "============================================================"
check "$TARGET"                      "200" "Page d'accueil"
check "$TARGET/api/Challenges"       "200" "API Challenges"
check "$TARGET/api/Users"            "200" "API Users"
check "$TARGET/rest/user/whoami"     "200" "Endpoint whoami"
check "$TARGET/page-inexistante-xyz" "404" "Page inexistante (404 attendu)"
echo ""
[ "$FAILED" -eq 0 ] && echo " RÉSULTAT : SUCCESS" || echo " RÉSULTAT : FAILURE"
echo "============================================================"
} | tee "$REPORT"

exit "$FAILED"
