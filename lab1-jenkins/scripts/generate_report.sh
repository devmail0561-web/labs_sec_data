#!/usr/bin/env bash
# =============================================================
# Agrégateur — Rapport consolidé LAB 1
# =============================================================
set -euo pipefail

REPORT_DIR="${REPORT_DIR:-/tmp}"
FINAL="$REPORT_DIR/rapport_final_lab1.txt"
TOTAL=0; FAILS=0

{
echo "================================================================"
echo "  RAPPORT FINAL — LAB 1 : Tests de sécurité automatisés"
echo "  Date  : $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Cible : ${JUICE_SHOP_URL:-http://juiceshop:3000}"
echo "  Build : #${BUILD_NUMBER:-local}"
echo "================================================================"
echo ""
for f in "$REPORT_DIR"/test_*_report.txt; do
    [ -f "$f" ] || continue
    echo "━━━━ $(basename "$f") ━━━━"
    cat "$f"
    echo ""
    TOTAL=$((TOTAL+1))
    grep -q "RÉSULTAT : FAILURE" "$f" && FAILS=$((FAILS+1)) || true
done
echo "================================================================"
echo "  Tests exécutés : $TOTAL"
echo "  En échec       : $FAILS"
echo "  En succès      : $((TOTAL-FAILS))"
echo "================================================================"
} | tee "$FINAL"

echo "[OK] Rapport : $FINAL"
