#!/usr/bin/env bash
# =============================================================
# TEST 04 — Sécurité de l'authentification
# Référence OWASP : A03:2021, A07:2021
# Code retour : 0 = OK | 1 = FAIL
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://juiceshop:3000}"
REPORT="${REPORT_DIR:-/tmp}/test_auth_report.txt"
TIMEOUT=10
FAILED=0

post_login() {
    curl -s --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        -X POST -H "Content-Type: application/json" \
        -d "$1" "$TARGET/rest/user/login" 2>/dev/null
}

code_login() {
    curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
        -X POST -H "Content-Type: application/json" \
        -d "$1" "$TARGET/rest/user/login" 2>/dev/null || echo "000"
}

{
echo "============================================================"
echo " TEST 04 — Authentification"
echo " Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Cible : $TARGET"
echo "============================================================"
echo ""

# --- Test SQLi ---
echo "[TEST] SQL Injection sur /rest/user/login"
SQLI_PAYLOAD='{"email":"'"'"' OR '"'"'1'"'"'='"'"'1'"'"'--","password":"x"}'
SQLI_CODE=$(code_login "$SQLI_PAYLOAD")
SQLI_RESP=$(post_login "$SQLI_PAYLOAD")
echo "  Payload : ' OR '1'='1'--"
echo "  HTTP    : $SQLI_CODE"
if [ "$SQLI_CODE" = "200" ] && echo "$SQLI_RESP" | grep -q "token"; then
    echo "  [CRITICAL] SQLi réussie — JWT retourné sans credentials valides"
    FAILED=1
else
    echo "  [OK] SQLi rejetée"
fi
echo ""

# --- Test message d'erreur ---
echo "[TEST] Verbosité des messages d'erreur"
ERR_RESP=$(post_login '{"email":"nobody@nowhere.xyz","password":"wrong"}')
echo "  Réponse : $(echo "$ERR_RESP" | head -c 200)"
echo ""

# --- Test rate limiting (5 tentatives rapides) ---
echo "[TEST] Rate limiting (5 tentatives rapides)"
BLOCKED=0
for i in $(seq 1 5); do
    CODE=$(code_login "{\"email\":\"brute${i}@test.local\",\"password\":\"wrong${i}\"}")
    if [ "$CODE" = "429" ]; then
        echo "  [OK] Rate limiting actif après $i tentatives (HTTP 429)"
        BLOCKED=1; break
    fi
done
[ "$BLOCKED" -eq 0 ] && echo "  [WARN] Pas de rate limiting détecté après 5 tentatives"
echo ""

[ "$FAILED" -eq 0 ] && echo " RÉSULTAT : SUCCESS" || echo " RÉSULTAT : FAILURE"
echo " RÉFÉRENCE : A03:2021 / A07:2021"
echo "============================================================"
} | tee "$REPORT"

exit "$FAILED"
