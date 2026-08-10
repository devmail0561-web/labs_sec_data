# LAB 2 — Tests de sécurité OWASP
## ZAP × Tests manuels × Exploitation × Juice Shop
### Groupe 14 — UNCHK — 2024-2025

---

## Description

Tests de sécurité complets sur OWASP Juice Shop selon la méthodologie
OWASP Testing Guide. Deux phases : détection/validation manuelle (V01–V04)
puis exploitation complète (EXP-01–EXP-05). Indépendant du LAB 1.

---

## Architecture

```
Machine Linux (172.21.0.0/24)
│
├── OWASP ZAP :8090  (172.21.0.30)
│     Spider + Scan actif → rapports HTML/XML/JSON
│
├── Scripts manuels
│     ├── test_vulnerabilities_manuels.sh → Détection V01–V04
│     └── exploit_vulnerabilities.sh      → Exploitation EXP-01–05
│
└── Juice Shop :3001  (172.21.0.10)
```

---

## Prérequis

```bash
docker --version        # >= 24.0
docker compose version  # >= 2.20
curl --version
```

---

## Démarrage

```bash
# 1. Démarrer les conteneurs
docker compose up -d

# 2. Vérifier
docker compose ps

# 3. Attendre ~30s que Juice Shop soit prêt
```

**Juice Shop** → http://localhost:3001  
**OWASP ZAP**  → http://localhost:8090

---

## Exécution

### Étape 1 — Détection et validation (V01–V04)

```bash
chmod +x scans/test_vulnerabilities_manuels.sh
JUICE_SHOP_URL=http://localhost:3001 ./scans/test_vulnerabilities_manuels.sh
```

### Étape 2 — Exploitation complète (EXP-01–EXP-05)

```bash
chmod +x scans/exploit_vulnerabilities.sh
JUICE_SHOP_URL=http://localhost:3001 ./scans/exploit_vulnerabilities.sh
```

### Étape 3 — Scan ZAP automatisé (optionnel)

```bash
chmod +x scans/zap_scan.sh
./scans/zap_scan.sh
```

---

## Arborescence

```
lab2-owasp/
├── docker-compose.yml
├── README.md
├── evidence/                       ← Preuves (générées à l'exécution)
│   ├── http/                       ← En-têtes HTTP, fichiers /ftp/
│   ├── requests/                   ← Requêtes curl
│   ├── responses/                  ← Réponses HTTP
│   ├── tokens/                     ← JWT extraits
│   └── notes/                      ← Fiches de vulnérabilités
├── reports/                        ← Rapports finaux
│   ├── rapport_lab2_owasp.html     ← Rapport complet (HTML, page de garde colorée)
│   └── rapport_lab2_owasp.md       ← Rapport complet (Markdown)
└── scans/
    ├── zap_scan.sh                 ← Scan automatisé ZAP
    ├── test_vulnerabilities_manuels.sh  ← Détection V01–V04
    └── exploit_vulnerabilities.sh       ← Exploitation EXP-01–05
```

---

## Vulnérabilités couvertes

### Phase détection

| ID | Vulnérabilité | OWASP | CVSS |
|---|---|---|---|
| V01 | Security Misconfiguration — Headers | A05:2021 | 5.3 |
| V02 | Sensitive Data Exposure — /api/Users | A02:2021 | 7.5 |
| V03 | Broken Access Control — Admin API | A01:2021 | 7.5 |
| V04 | SQL Injection — Authentification | A03:2021 | 9.8 |

### Phase exploitation

| ID | Exploit | OWASP | CVSS | Preuve |
|---|---|---|---|---|
| EXP-01 | SQLi → JWT admin | A03:2021 | 9.8 | tokens/EXP01_jwt_admin.txt |
| EXP-02 | IDOR paniers | A01:2021 | 8.1 | responses/EXP02_basket_N.json |
| EXP-03 | Path Traversal /ftp/ + null byte | A01:2021 | 7.5 | http/EXP03_*.txt |
| EXP-04 | XSS stocké feedbacks | A03:2021 | 7.2 | responses/EXP04_feedbacks.json |
| EXP-05 | Mass Assignment → admin | A08:2021 | 8.8 | responses/EXP05_escalation.json |

---

## Arrêt

```bash
docker compose down        # arrêter
docker compose down -v     # arrêter + supprimer volumes
```

---

> ⚠️ Environnement strictement local — ne jamais utiliser ces techniques sur une cible réelle.
