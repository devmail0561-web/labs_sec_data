# LAB 1 — Automatisation des tests de sécurité
## Jenkins × Bash × OWASP Juice Shop
### Groupe 14 — UNCHK — 2024-2025

---

## Description

Pipeline CI/CD de sécurité automatisé. Jenkins orchestre six scripts Bash
couvrant la détection de vulnérabilités et leur exploitation contre
OWASP Juice Shop, dans un réseau Docker isolé.

---

## Architecture

```
Machine Linux (172.20.0.0/24)
│
├── Jenkins :8080  (172.20.0.20)
│     │
│     ├── TEST 01 — Disponibilité HTTP
│     ├── TEST 02 — En-têtes de sécurité    (A05:2021)
│     ├── TEST 03 — Méthodes HTTP            (A05:2021)
│     ├── TEST 04 — Authentification + SQLi  (A03, A07:2021)
│     ├── TEST 05 — Exposition APIs          (A01, A02:2021)
│     ├── TEST 06 — Exploitation             (SQLi/IDOR/FTP/XSS)
│     └── Rapport + Archivage artefacts
│
└── Juice Shop :3000  (172.20.0.10)
```

---

## Prérequis

```bash
docker --version        # >= 24.0
docker compose version  # >= 2.20
```

---

## Démarrage

```bash
# 1. Rendre les scripts exécutables
chmod +x scripts/*.sh

# 2. Démarrer les conteneurs
docker compose up -d

# 3. Vérifier
docker compose ps

# 4. Récupérer le mot de passe Jenkins initial (attendre ~60s)
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

**Juice Shop** → http://localhost:3000  
**Jenkins**    → http://localhost:8080

---

## Configuration Jenkins

1. Ouvrir http://localhost:8080
2. Saisir le mot de passe initial
3. Installer les plugins suggérés
4. Créer un compte administrateur
5. **New Item** → nom : `juice-shop-security` → type : **Pipeline**
6. Section **Pipeline** → **Pipeline script from SCM**
   - SCM : **Git**
   - Repository URL : chemin local ou URL Git du projet
   - Script Path : `lab1-jenkins/Jenkinsfile`
7. **Save** → **Build Now**

---

## Arborescence

```
lab1-jenkins/
├── docker-compose.yml          ← Juice Shop + Jenkins
├── Jenkinsfile                 ← Pipeline 8 étapes
├── README.md
├── reports/
│   ├── rapport_lab1_jenkins.html  ← Rapport complet (HTML)
│   └── rapport_lab1_jenkins.md   ← Rapport complet (Markdown)
├── captures/                   ← Captures d'écran (PNG) + sorties scripts
└── scripts/
    ├── test_http.sh            ← TEST 01 : Disponibilité HTTP
    ├── test_headers.sh         ← TEST 02 : En-têtes de sécurité
    ├── test_methods.sh         ← TEST 03 : Méthodes HTTP
    ├── test_auth.sh            ← TEST 04 : Authentification + SQLi
    ├── test_api_security.sh    ← TEST 05 : Exposition APIs
    ├── test_exploitation.sh    ← TEST 06 : Exploitation complète
    ├── generate_report.sh      ← Agrégateur rapport final
    └── capture_screenshots.sh  ← Captures d'écran automatisées
```

---

## Résultats attendus

| Test | Statut Jenkins | Raison |
|---|---|---|
| TEST 01 | SUCCESS | Endpoints répondent |
| TEST 02 | UNSTABLE | En-têtes manquants |
| TEST 03 | UNSTABLE | TRACE potentiellement actif |
| TEST 04 | UNSTABLE | SQLi bypass auth |
| TEST 05 | UNSTABLE | /api/Users sans auth |
| TEST 06 | UNSTABLE | 4 exploits réussis |

Statut global attendu : **UNSTABLE** (normal — Juice Shop est intentionnellement vulnérable)

---

## Arrêt

```bash
docker compose down        # arrêter sans supprimer les volumes
docker compose down -v     # arrêter et supprimer les volumes
```

---

> ⚠️ Environnement strictement local — ne jamais utiliser ces techniques sur une cible réelle.
