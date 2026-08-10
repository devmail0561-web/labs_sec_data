# Projet de sécurité — OWASP Juice Shop
## Module : Sécurité des données — Polytech Diamniadio — Groupe 14

---

## Organisation

Ce projet contient **deux labs indépendants**. Chacun a son propre
`docker-compose.yml`, son propre réseau Docker et son propre Juice Shop.

```
projet/
├── README.md            ← Ce fichier
├── lab1-jenkins/        ← LAB 1 autonome (Jenkins + Bash)
│   ├── README.md
│   ├── docker-compose.yml
│   ├── Jenkinsfile
│   └── scripts/
└── lab2-owasp/          ← LAB 2 autonome (ZAP + Exploitation)
    ├── README.md
    ├── docker-compose.yml
    ├── evidence/
    └── scans/
```

---

## Différences entre les labs

| Élément | LAB 1 | LAB 2 |
|---|---|---|
| Objectif | Automatisation CI/CD | Tests OWASP manuels |
| Outil principal | Jenkins | OWASP ZAP + curl |
| Port Juice Shop | :3000 | :3001 |
| Réseau Docker | 172.20.0.0/24 | 172.21.0.0/24 |
| CI/CD | Oui | Non |
| Phase détection | TEST 01–05 (Bash) | ZAP + scripts manuels |
| Phase exploitation | TEST 06 (automatisé) | exploit_vulnerabilities.sh |

---

## Démarrage rapide

### LAB 1
```bash
cd lab1-jenkins
chmod +x scripts/*.sh
docker compose up -d
# Mot de passe Jenkins :
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
# Ouvrir : http://localhost:8080
```

### LAB 2
```bash
cd lab2-owasp
docker compose up -d
JUICE_SHOP_URL=http://localhost:3001 ./scans/test_vulnerabilities_manuels.sh
JUICE_SHOP_URL=http://localhost:3001 ./scans/exploit_vulnerabilities.sh
# ZAP : http://localhost:8090
```

---

> ⚠️ Tous les tests sont strictement limités aux instances Docker locales.
