#!/usr/bin/env bash
# =============================================================
# LAB 2 — Scan OWASP ZAP automatisé
# Usage : ./zap_scan.sh
# =============================================================
set -uo pipefail

TARGET="${JUICE_SHOP_URL:-http://localhost:3001}"
ZAP="${ZAP_URL:-http://localhost:8091}"
KEY="${ZAP_API_KEY:-changeme}"
OUT="$(dirname "$0")/../reports"
DATE=$(date '+%Y%m%d_%H%M%S')
T=15

mkdir -p "$OUT"

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "Vérification ZAP..."
curl -s "$ZAP/JSON/core/view/version/?apikey=$KEY" > /dev/null 2>&1 \
    || { echo "[ERREUR] ZAP non disponible sur $ZAP"; exit 1; }
log "ZAP disponible"

log "Spider en cours..."
SPIDER_RESP=$(curl -s "$ZAP/JSON/spider/action/scan/?apikey=$KEY&url=$TARGET&maxChildren=10&recurse=true")
SPIDER_ID=$(echo "$SPIDER_RESP" | grep -o '"scan":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
PROG=0
while [ "$PROG" -lt 100 ]; do
    sleep 3
    PROG=$(curl -s "$ZAP/JSON/spider/view/status/?apikey=$KEY&scanId=$SPIDER_ID" \
        | grep -o '"status":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
    log "Spider : ${PROG}%"
done
log "Spider terminé"

log "Scan actif en cours (5-15 min)..."
SCAN_RESP=$(curl -s "$ZAP/JSON/ascan/action/scan/?apikey=$KEY&url=$TARGET&recurse=true")
SCAN_ID=$(echo "$SCAN_RESP" | grep -o '"scan":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
PROG=0
while [ "$PROG" -lt 100 ]; do
    sleep 10
    PROG=$(curl -s "$ZAP/JSON/ascan/view/status/?apikey=$KEY&scanId=$SCAN_ID" \
        | grep -o '"status":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
    log "Scan actif : ${PROG}%"
done
log "Scan actif terminé"

log "Génération des rapports..."
curl -s "$ZAP/OTHER/core/other/htmlreport/?apikey=$KEY" \
    -o "$OUT/zap_rapport_${DATE}.html"
curl -s "$ZAP/OTHER/core/other/xmlreport/?apikey=$KEY" \
    -o "$OUT/zap_rapport_${DATE}.xml"
curl -s "$ZAP/JSON/core/view/alerts/?apikey=$KEY&baseurl=$TARGET" \
    -o "$OUT/zap_alertes_${DATE}.json"

log "Résumé des alertes :"
ALERTS=$(curl -s "$ZAP/JSON/core/view/alerts/?apikey=$KEY&baseurl=$TARGET")
for risk in "High" "Medium" "Low" "Informational"; do
    count=$(echo "$ALERTS" | grep -o "\"risk\":\"$risk\"" | wc -l)
    echo "  $risk : $count"
done

curl -s "$ZAP/JSON/core/action/newSession/?apikey=$KEY" > /dev/null
log "Rapports dans : $OUT"
