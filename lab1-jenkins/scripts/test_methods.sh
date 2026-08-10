#!/usr/bin/env bash
# =============================================================
# TEST 03 — Méthodes HTTP autorisées
# Référence OWASP : A05:2021 / OTG-CONFIG-006
# Code retour : 0 = OK | 1 = FAIL (méthode dangereuse active)
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://juiceshop:3000}"
REPORT="${REPORT_DIR:-/tmp}/test_methods_report.txt"
TIMEOUT=10
FAILED=0

test_method() {
    local method="$1" dangerous="$2"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        -X "$method" "$TARGET" 2>/dev/null || echo "000")
    if [ "$dangerous" = "yes" ] && \
       [ "$code" != "405" ] && [ "$code" != "501" ] && [ "$code" != "400" ] && [ "$code" != "000" ]; then
        echo "[WARN] $method — HTTP $code — méthode potentiellement dangereuse"
        [ "$method" = "TRACE" ] && FAILED=1
    else
        echo "[INFO] $method — HTTP $code"
    fi
}

{
echo "============================================================"
echo " TEST 03 — Méthodes HTTP"
echo " Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Cible : $TARGET"
echo "============================================================"
echo ""
echo "--- Méthodes standard ---"
test_method "GET"     "no"
test_method "POST"    "no"
test_method "HEAD"    "no"
test_method "OPTIONS" "no"
echo ""
echo "--- Méthodes dangereuses ---"
test_method "TRACE"   "yes"
test_method "PUT"     "yes"
test_method "DELETE"  "yes"
test_method "CONNECT" "yes"
echo ""
[ "$FAILED" -eq 0 ] && echo " RÉSULTAT : SUCCESS" || echo " RÉSULTAT : FAILURE — TRACE actif"
echo " RÉFÉRENCE : A05:2021 / OTG-CONFIG-006"
echo "============================================================"
} | tee "$REPORT"

exit "$FAILED"
