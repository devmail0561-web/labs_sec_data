---
title: "LAB 1 — Pipeline CI/CD de sécurité Jenkins"
author: "Michel TENDENG · Mouhamed El Hadj Malick DIOP"
date: "10 août 2026"
---

<div align="center">

# UNIVERSITÉ NUMÉRIQUE CHEIKH HAMIDOU KANE
## Licence Cybersécurité — Groupe 14

---

## RAPPORT DE TRAVAUX PRATIQUES
# LAB 1 — Pipeline CI/CD de sécurité
### Jenkins × Bash × OWASP Juice Shop

---

**Module :** Sécurité des données  
**Année académique :** 2024–2025  
**Date :** 10/08/2026  
**Groupe :** 14

---

### Auteurs

| Auteur | Email |
|--------|-------|
| Michel TENDENG | michel.tendeng@unchk.edu.sn |
| Mouhamed El Hadj Malick DIOP | mouhamedelmalickidrissa.diop@unchk.edu.sn |

---

> **Avertissement :** Ce rapport est réalisé dans un cadre pédagogique strictement contrôlé.  
> L'environnement cible est local et isolé. Toute reproduction sur un système réel est illégale.

</div>

---

## Table des matières

1. [Contexte et objectifs](#1-contexte-et-objectifs)
2. [Architecture du laboratoire](#2-architecture-du-laboratoire)
3. [Pipeline Jenkins — Vue d'ensemble](#3-pipeline-jenkins--vue-densemble)
4. [Phase 1 — Tests de détection (TEST 01–05)](#4-phase-1--tests-de-détection-test-0105)
5. [Phase 2 — Exploitation automatisée (TEST 06)](#5-phase-2--exploitation-automatisée-test-06)
6. [Synthèse des vulnérabilités](#6-synthèse-des-vulnérabilités)
7. [Recommandations](#7-recommandations)
8. [Conclusion](#8-conclusion)
9. [Annexes — Références aux preuves](#9-annexes--références-aux-preuves)

---

## 1. Contexte et objectifs

Ce travail pratique s'inscrit dans le module **Sécurité des données** de la Licence Cybersécurité (UNCHK). L'objectif est de mettre en place un **pipeline CI/CD de sécurité automatisé** orchestré par Jenkins, capable de détecter et exploiter des vulnérabilités sur l'application **OWASP Juice Shop**.

### Objectifs pédagogiques

- Concevoir un pipeline Jenkins de sécurité automatisé à partir de zéro
- Implémenter des scripts Bash couvrant les 6 phases de test (détection + exploitation)
- Intégrer les tests OWASP Top 10 dans un workflow CI/CD
- Analyser et documenter les vulnérabilités détectées avec preuves techniques

### Cible

- **Application :** OWASP Juice Shop (Node.js / Express)
- **URL locale :** `http://juiceshop:3000` (interne Docker) / `http://localhost:3000` (hôte)
- **Environnement :** Conteneurs Docker isolés (réseau `172.20.0.0/24`)

---

## 2. Architecture du laboratoire

```
Machine Linux (172.20.0.0/24)
│
├── Jenkins :8080  (172.20.0.20)
│     │  Pipeline 8 étapes, scripts montés en lecture seule
│     │
│     ├── TEST 01 — Disponibilité HTTP        (Baseline)
│     ├── TEST 02 — En-têtes de sécurité      (A05:2021)
│     ├── TEST 03 — Méthodes HTTP             (A05:2021)
│     ├── TEST 04 — Authentification + SQLi   (A03, A07:2021)
│     ├── TEST 05 — Exposition APIs           (A01, A02:2021)
│     ├── TEST 06 — Exploitation              (SQLi/IDOR/FTP/XSS)
│     └── Rapport consolidé + Archivage artefacts
│
└── Juice Shop :3000  (172.20.0.10)
      Application web cible (intentionnellement vulnérable)
```

Les conteneurs sont démarrés via `docker compose up -d` depuis le répertoire `lab1-jenkins/`. Le volume `/var/run/docker.sock` est monté dans Jenkins pour permettre l'exécution de commandes Docker si nécessaire. Les scripts Bash sont montés en lecture seule dans `/lab/scripts/`.

---

## 3. Pipeline Jenkins — Vue d'ensemble

Le Jenkinsfile définit **8 étapes** avec gestion fine des statuts de build :

| Étape | Type | Résultat attendu |
|-------|------|-----------------|
| Préparation | Setup | SUCCESS |
| Vérification cible | Health check | SUCCESS |
| TEST 01 — Disponibilité HTTP | Baseline | SUCCESS |
| TEST 02 — En-têtes de sécurité | `catchError` → UNSTABLE | UNSTABLE |
| TEST 03 — Méthodes HTTP | `catchError` → UNSTABLE | UNSTABLE |
| TEST 04 — Authentification | `catchError` → UNSTABLE | UNSTABLE |
| TEST 05 — Exposition APIs | `catchError` → UNSTABLE | UNSTABLE |
| TEST 06 — Exploitation | `catchError` → UNSTABLE | UNSTABLE |
| Rapport consolidé | Agrégation | SUCCESS |
| Archivage | `archiveArtifacts` | SUCCESS |

**Statut global obtenu : UNSTABLE** — comportement attendu, Juice Shop étant intentionnellement vulnérable.

### Options de pipeline

```groovy
options {
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timestamps()
    disableConcurrentBuilds()
}
```

La directive `catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE')` permet aux étapes de détection d'échouer sans bloquer le pipeline, conservant la traçabilité de chaque vulnérabilité.

---

## 4. Phase 1 — Tests de détection (TEST 01–05)

### Vue d'ensemble

| ID | Test | Référence OWASP | Résultat | Vulnérabilités |
|----|------|-----------------|----------|----------------|
| TEST 01 | Disponibilité HTTP | Baseline | ⚠️ FAILURE | `/api/Users` → 401 ; 404 non conforme |
| TEST 02 | En-têtes de sécurité | A05:2021 | ❌ FAILURE | HSTS et CSP absents |
| TEST 03 | Méthodes HTTP | A05:2021 | ❌ FAILURE | TRACE, PUT, DELETE actifs |
| TEST 04 | Authentification | A03, A07:2021 | ❌ FAILURE | SQLi bypass ; pas de rate limiting |
| TEST 05 | Exposition APIs | A01, A02:2021 | ❌ FAILURE | Feedbacks et config admin exposés |

---

### TEST 01 — Disponibilité HTTP (Baseline)

**Objectif :** Vérifier que les endpoints critiques répondent avec les codes HTTP attendus.

**Résultats :**

| Endpoint | HTTP obtenu | Attendu | Statut |
|----------|-------------|---------|--------|
| `/` | 200 | 200 | ✅ PASS |
| `/api/Challenges` | 200 | 200 | ✅ PASS |
| `/api/Users` | 401 | 200 | ❌ FAIL |
| `/rest/user/whoami` | 200 | 200 | ✅ PASS |
| `/page-inexistante-xyz` | 200 | 404 | ❌ FAIL |

**Observations :**
- `/api/Users` retourne maintenant 401 après la mise à jour de Juice Shop — l'endpoint est désormais protégé (correction positive). Le script de test devra être adapté pour refléter ce comportement attendu.
- L'application retourne HTTP 200 sur toutes les routes inexistantes (Angular SPA routing), ce qui peut masquer des erreurs serveur réelles.

**Résultat TEST 01 :** FAILURE (2 endpoints non conformes aux attentes du script)

---

### TEST 02 — En-têtes HTTP de sécurité (A05:2021)

**Objectif :** Vérifier la présence des en-têtes de sécurité HTTP essentiels.

**En-têtes bruts reçus :**
```http
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Feature-Policy: payment 'self'
X-Recruiting: /#/jobs
```

**Analyse :**

| En-tête | Sévérité | Présent ? | Valeur |
|---------|----------|-----------|--------|
| `Strict-Transport-Security` | CRITICAL | ❌ Absent | — |
| `Content-Security-Policy` | CRITICAL | ❌ Absent | — |
| `X-Content-Type-Options` | CRITICAL | ✅ Présent | `nosniff` |
| `X-Frame-Options` | WARNING | ✅ Présent | `SAMEORIGIN` |
| `Referrer-Policy` | WARNING | ❌ Absent | — |
| `X-Powered-By` | WARNING | ✅ Correct | Absent (bien) |
| `Server` | WARNING | ✅ Correct | Absent (bien) |

**Observation notable :** `Access-Control-Allow-Origin: *` autorise les requêtes cross-origin depuis n'importe quelle origine, exposant les APIs à des attaques CSRF et à des fuites de données.

**Impact :** Sans CSP, un attaquant peut injecter du contenu malveillant (XSS). Sans HSTS, les communications peuvent être interceptées en clair (downgrade HTTP).

**Référence :** A05:2021 — Security Misconfiguration | CVSS 5.3

**Résultat TEST 02 :** FAILURE (2 en-têtes critiques absents)

---

### TEST 03 — Méthodes HTTP (A05:2021)

**Objectif :** Identifier les méthodes HTTP dangereuses actives sur le serveur.

**Résultats :**

| Méthode | Dangereuse | HTTP obtenu | Statut |
|---------|-----------|-------------|--------|
| GET | Non | 200 | ℹ️ Normal |
| POST | Non | 200 | ℹ️ Normal |
| HEAD | Non | 200 | ℹ️ Normal |
| OPTIONS | Non | 204 | ℹ️ Normal |
| **TRACE** | **Oui** | **200** | ⚠️ WARN — CRITIQUE |
| **PUT** | **Oui** | **200** | ⚠️ WARN |
| **DELETE** | **Oui** | **200** | ⚠️ WARN |
| CONNECT | Oui | 000 | ℹ️ Bloqué |

**Impact TRACE actif :** La méthode TRACE permet une attaque **Cross-Site Tracing (XST)** qui peut exfiltrer des cookies HttpOnly lorsqu'elle est combinée avec XSS, contournant ainsi la protection HttpOnly.

**Impact PUT/DELETE actifs :** Ces méthodes peuvent permettre la modification ou la suppression de ressources si les contrôles d'accès sont insuffisants.

**Référence :** A05:2021 / OTG-CONFIG-006 | CVSS 5.8

**Résultat TEST 03 :** FAILURE (TRACE actif → déclenchement du FAIL)

---

### TEST 04 — Sécurité de l'authentification (A03, A07:2021)

**Objectif :** Tester la résistance du formulaire de connexion aux attaques courantes.

#### SQL Injection sur `/rest/user/login`

**Payload utilisé :**
```json
{"email":"' OR '1'='1'--","password":"x"}
```

**Résultat :** HTTP 200 — JWT valide retourné sans credentials légitimes.

```
[CRITICAL] SQLi réussie — JWT retourné sans credentials valides
```

L'injection SQL contourne totalement le mécanisme d'authentification. La requête backend non paramétrée évalue `' OR '1'='1'--` comme toujours vraie et retourne le premier utilisateur (admin, ID=1).

#### Verbosité des messages d'erreur

```
Réponse : Invalid email or password.
```

Message générique — pas d'énumération de comptes. Point positif.

#### Rate Limiting

```
[WARN] Pas de rate limiting détecté après 5 tentatives
```

Aucun mécanisme de protection contre les attaques par force brute n'est en place. Un attaquant peut tenter un nombre illimité de combinaisons email/mot de passe.

**Référence :** A03:2021 (Injection) / A07:2021 (Identification Failures) | CVSS SQLi : 9.8

**Résultat TEST 04 :** FAILURE (SQLi réussie)

---

### TEST 05 — Exposition des APIs (A01, A02:2021)

**Objectif :** Identifier les endpoints API qui exposent des données sensibles sans authentification.

**Résultats :**

| Endpoint | HTTP | Exposition | Statut |
|----------|------|-----------|--------|
| `/api/Users` | 401 | Protégé | ✅ OK |
| `/api/Feedbacks` | 200 | `UserId` exposé | ❌ CRITICAL |
| `/rest/admin/application-configuration` | 200 | Config complète | ❌ CRITICAL |
| `/ftp/` | 200 | Listing de fichiers | ⚠️ INFO |

**`/api/Feedbacks` sans auth :**  
Retourne tous les feedbacks utilisateurs avec les champs `UserId`, `comment`, `rating` — permettant l'énumération des utilisateurs actifs.

**`/rest/admin/application-configuration` sans auth :**  
Expose la configuration complète de l'application : clés OAuth Google, paramètres internes, métadonnées des challenges. Endpoint critique accessible sans aucune authentification.

**Référence :** A01:2021 (Broken Access Control) / A02:2021 (Cryptographic Failures) | CVSS 7.5

**Résultat TEST 05 :** FAILURE (2 endpoints critiques exposés)

---

## 5. Phase 2 — Exploitation automatisée (TEST 06)

### Vue d'ensemble

| ID | Exploit | Catégorie OWASP | CVSS | Résultat |
|----|---------|-----------------|------|----------|
| EXP-01 | SQLi → JWT admin | A03:2021 | **9.8** | ✅ JWT admin obtenu |
| EXP-02 | IDOR — Paniers | A01:2021 | **8.1** | ✅ Panier victime lu |
| EXP-03 | Path Traversal `/ftp/` + Null byte | A01:2021 | **7.5** | ✅ Fichiers téléchargés + bypass |
| EXP-04 | XSS Stocké — Feedbacks | A03:2021 | **7.2** | ⚠️ HTTP 500 (payload envoyé) |

---

### EXP-01 — SQL Injection → JWT admin (A03:2021 | CVSS 9.8)

**Objectif :** Obtenir un JWT administrateur sans connaître le mot de passe.

**Requête :**
```http
POST /rest/user/login HTTP/1.1
Content-Type: application/json

{"email":"' OR '1'='1'--","password":"x"}
```

**Résultat :** HTTP 200 — JWT valide retourné.

**JWT admin décodé :**
```json
{
  "data": {
    "id": 1,
    "email": "admin@juice-sh.op",
    "password": "0192023a7bbd73250516f069df18b500",
    "role": "admin",
    "isActive": true
  },
  "bid": 1,
  "iat": 1786388813
}
```

**Observations critiques :**
- Accès administrateur complet obtenu sans credential valide
- Le hash MD5 du mot de passe admin (`0192023a7bbd73250516f069df18b500`) est exposé directement dans le payload JWT
- Ce hash correspond au mot de passe `admin123` (MD5 cassable en quelques secondes)
- L'identité confirmée via `/rest/user/whoami` : `admin@juice-sh.op`

**Preuves :** `captures/reports/evidence/EXP01_request.json` · `EXP01_response.json` · `EXP01_jwt_admin.txt` · `EXP01_whoami.json`

---

### EXP-02 — IDOR : Accès aux paniers (A01:2021 | CVSS 8.1)

**Objectif :** Accéder au panier d'un autre utilisateur en manipulant l'identifiant de ressource.

**Principe :** L'API `/rest/basket/{id}` ne vérifie pas que l'utilisateur authentifié est propriétaire du panier demandé.

**Déroulement :**
1. Création d'un compte attaquant (`attacker_23568@lab.local`)
2. Connexion et obtention du JWT attaquant
3. Requête `GET /rest/basket/1` avec le JWT attaquant → **HTTP 200**
4. Lecture complète du panier de la victime (ID=1)

**Contenu du panier victime consulté :**
```
- Apple Juice (1000ml)   × 2   — 1.99 €
- Orange Juice (1000ml)  × 3   — 2.99 €
- Eggfruit Juice (500ml) × 1   — 8.99 €
```

**Impact démontré :** Un attaquant authentifié peut lire (et potentiellement modifier) le panier de n'importe quel utilisateur en incrémentant l'ID de 1 à N.

**Preuves :** `captures/reports/evidence/EXP02_basket_1.json`

---

### EXP-03 — Path Traversal `/ftp/` + Bypass Null Byte (A01:2021 | CVSS 7.5)

**Objectif :** Accéder à des fichiers sensibles exposés via le répertoire `/ftp/`.

**Résultats :**

| Fichier | Méthode | HTTP | Résultat |
|---------|---------|------|----------|
| `/ftp/acquisitions.md` | GET direct | 200 | ✅ Téléchargé |
| `/ftp/legal.md` | GET direct | 200 | ✅ Téléchargé |
| `/ftp/eastere.gg` | GET direct | 403 | ❌ Bloqué |
| `/ftp/package.json.bak` | GET direct | 403 | ❌ Bloqué |
| `/ftp/package.json.bak%2500.md` | Null byte bypass | 200 | ✅ Filtre contourné |

**Contenu de `acquisitions.md` (confidentiel) :**
```
# Planned Acquisitions
> This document is confidential! Do not distribute!
Our company plans to acquire several competitors within the next year.
This will have a significant stock market impact...
```

**Technique null byte :** Le filtre d'extension côté serveur bloque les fichiers `.bak`. En encodant un null byte (`%00` → `%2500` en double URL-encoding), l'application traite le chemin comme se terminant par `.md` et sert le fichier `.bak` réel.

**Contenu de `package.json.bak` (métadonnées sensibles) :**
```json
{
  "name": "juice-shop",
  "version": "6.2.0-SNAPSHOT",
  "description": "An intentionally insecure JavaScript Web Application",
  "author": "Björn Kimminich <bjoern.kimminich@owasp.org>"
}
```

**Impact :** Documents d'acquisition confidentiels lisibles, version exacte du logiciel exposée (facilite la recherche de CVE spécifiques).

**Preuves :** `captures/reports/evidence/EXP03_acquisitions.md.txt` · `EXP03_legal.md.txt` · `EXP03_nullbyte_package.json.bak.txt`

---

### EXP-04 — XSS Stocké dans les feedbacks (A03:2021 | CVSS 7.2)

**Objectif :** Injecter un payload JavaScript persistant dans les feedbacks de l'application.

**Payload injecté :**
```html
<iframe src="javascript:alert(`Jenkins-XSS-EXP04`)"></iframe>
```

**Requête :**
```http
POST /api/Feedbacks HTTP/1.1
Content-Type: application/json

{
  "comment": "Lab test <iframe src=\"javascript:alert(`Jenkins-XSS-EXP04`)\"></iframe>",
  "rating": 1,
  "captchaId": 0,
  "captcha": ""
}
```

**Résultat :** HTTP 500 — Le serveur a retourné une erreur interne lors du traitement. Le payload a probablement déclenché une erreur de validation ou de sérialisation. Une validation complémentaire via navigateur (page `/#/about`) est nécessaire pour confirmer l'exécution côté client.

**Impact attendu :** Exécution de JavaScript arbitraire dans le navigateur de tout utilisateur consultant la page des avis clients.

**Preuve :** `captures/reports/evidence/EXP04_xss_request.json`

---

## 6. Synthèse des vulnérabilités

### Tableau de bord global

| ID | Vulnérabilité | OWASP Top 10 | CVSS | Criticité | Exploitée |
|----|---------------|--------------|------|-----------|-----------|
| EXP-01 | SQL Injection — Auth | A03:2021 | **9.8** | 🔴 Critique | ✅ Oui |
| EXP-02 | IDOR — Paniers | A01:2021 | **8.1** | 🔴 Critique | ✅ Oui |
| TEST 05 | Config admin sans auth | A01:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| EXP-03 | Path Traversal + Null Byte | A01:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| EXP-04 | XSS Stocké — Feedbacks | A03:2021 | **7.2** | 🟠 Élevé | ⚠️ Partiel |
| TEST 03 | Méthodes dangereuses (TRACE) | A05:2021 | **5.8** | 🟡 Moyen | — |
| TEST 02 | En-têtes sécurité manquants | A05:2021 | **5.3** | 🟡 Moyen | — |
| TEST 04 | Absence de rate limiting | A07:2021 | **5.3** | 🟡 Moyen | — |

### Répartition par catégorie OWASP

| Catégorie | Vulnérabilités identifiées |
|-----------|---------------------------|
| A01 — Broken Access Control | EXP-02 (IDOR), TEST 05 (config admin), EXP-03 (FTP) |
| A03 — Injection | EXP-01 (SQLi), EXP-04 (XSS) |
| A05 — Security Misconfiguration | TEST 02 (en-têtes), TEST 03 (méthodes HTTP) |
| A07 — Identification Failures | TEST 04 (rate limiting) |

### Résumé des tests Jenkins

| Test Jenkins | Statut script | Statut build | Vulnérabilités |
|---|---|---|---|
| TEST 01 — HTTP | FAILURE | FAILURE | 2 endpoints non conformes |
| TEST 02 — En-têtes | FAILURE | UNSTABLE | HSTS, CSP absents |
| TEST 03 — Méthodes | FAILURE | UNSTABLE | TRACE actif |
| TEST 04 — Auth | FAILURE | UNSTABLE | SQLi, no rate limiting |
| TEST 05 — APIs | FAILURE | UNSTABLE | Feedbacks, config exposés |
| TEST 06 — Exploitation | FAILURE | UNSTABLE | 3 exploits réussis / 4 |

---

## 7. Recommandations

### Corrections prioritaires (Critique)

**R01 — Prévenir les injections SQL**
- Utiliser des requêtes préparées (parameterized queries) ou un ORM avec protection intégrée (Sequelize avec `where: { email: req.body.email }` au lieu d'interpolation)
- Valider et assainir toutes les entrées utilisateur côté serveur
- Implémenter un WAF (Web Application Firewall) en amont

**R02 — Corriger les IDOR**
- Vérifier systématiquement que l'utilisateur authentifié est propriétaire de la ressource (`basket.UserId === req.user.id`)
- Remplacer les identifiants séquentiels par des UUIDs aléatoires (v4) non prédictibles

### Corrections élevées

**R03 — Restreindre l'accès aux fichiers sensibles**
- Déplacer les fichiers confidentiels hors de la racine web publique
- Valider strictement les chemins côté serveur (whitelist d'extensions, blocage des null bytes)
- Supprimer ou protéger par authentification le répertoire `/ftp/`

**R04 — Corriger le XSS**
- Encoder toutes les sorties HTML (output encoding avec une bibliothèque dédiée)
- Implémenter une `Content-Security-Policy` stricte bloquant `javascript:` dans les `src`
- Assainir les entrées utilisateur (strip tags, encoding HTML)

### Améliorations de configuration

**R05 — Ajouter les en-têtes de sécurité**
```http
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'
Referrer-Policy: strict-origin-when-cross-origin
Access-Control-Allow-Origin: https://[domaine-specifique]
```

**R06 — Désactiver les méthodes HTTP dangereuses**
```javascript
// Express.js
app.use((req, res, next) => {
  const forbidden = ['TRACE', 'TRACK'];
  if (forbidden.includes(req.method)) return res.status(405).end();
  next();
});
```

**R07 — Implémenter le rate limiting**
```javascript
const rateLimit = require('express-rate-limit');
app.use('/rest/user/login', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: 'Too many login attempts'
}));
```

**R08 — Protéger les endpoints sensibles**
- `/rest/admin/application-configuration` : restreindre aux administrateurs authentifiés
- `/api/Feedbacks` : masquer le champ `UserId` dans les réponses publiques

---

## 8. Conclusion

Ce laboratoire a permis de concevoir et d'exécuter un **pipeline CI/CD de sécurité complet** orchestré par Jenkins, couvrant **8 vulnérabilités** réparties sur 4 catégories du Top 10 OWASP 2021.

Les vulnérabilités les plus critiques — l'injection SQL (CVSS 9.8) et l'IDOR (CVSS 8.1) — permettent respectivement d'obtenir un accès administrateur complet et de lire les données privées de tous les utilisateurs. L'exploitation enchaînée démontre le principe de **pivot** : l'injection SQL (EXP-01) fournit le JWT admin nécessaire pour accéder aux endpoints protégés (TEST 05), révélant à leur tour la configuration interne qui facilite d'autres attaques.

L'approche CI/CD présente un avantage majeur : **l'automatisation de la régression de sécurité**. Chaque commit déclenchant le pipeline garantit qu'une correction introduite ne disparaît pas silencieusement lors d'une refonte. Le statut UNSTABLE signale immédiatement la présence de vulnérabilités sans bloquer les déploiements légitimes, permettant une gestion fine du risque accepté.

Ce laboratoire illustre concrètement l'intégration du concept **DevSecOps** : la sécurité n'est plus un audit ponctuel mais un contrôle continu intégré dans le cycle de développement.

---

## 9. Annexes — Références aux preuves

### Arborescence des preuves

```
lab1-jenkins/captures/
├── reports/
│   ├── evidence/
│   │   ├── EXP01_request.json           ← Payload SQLi envoyé
│   │   ├── EXP01_response.json          ← JWT admin dans la réponse
│   │   ├── EXP01_jwt_admin.txt          ← JWT admin complet
│   │   ├── EXP01_whoami.json            ← Identité admin confirmée
│   │   ├── EXP02_basket_1.json          ← Panier victime lu
│   │   ├── EXP03_acquisitions.md.txt    ← Document confidentiel récupéré
│   │   ├── EXP03_legal.md.txt           ← Fichier légal récupéré
│   │   ├── EXP03_nullbyte_package.json.bak.txt  ← Bypass null byte
│   │   └── EXP04_xss_request.json       ← Payload XSS envoyé
│   ├── test_http_output.txt
│   ├── test_headers_output.txt
│   ├── test_methods_output.txt
│   ├── test_auth_output.txt
│   ├── test_api_security_output.txt
│   ├── test_exploitation_output.txt
│   └── rapport_final_lab1.txt           ← Rapport consolidé Jenkins
└── *.png                                ← Captures d'écran (10 fichiers)
```

### Captures d'écran

| Fichier | Contenu |
|---------|---------|
| `01_juiceshop_accueil.png` | Page d'accueil OWASP Juice Shop |
| `02_juiceshop_login.png` | Formulaire de connexion |
| `03_jenkins_dashboard.png` | Dashboard Jenkins authentifié |
| `04_jenkins_manage.png` | Page d'administration Jenkins |
| `05_jenkins_job_page.png` | Pipeline `juice-shop-security` |
| `06_jenkins_build_console.png` | Console de build Jenkins (sortie complète) |
| `07_jenkins_build_detail.png` | Détail du build |
| `08_jenkins_job_apres_build.png` | Historique des builds |
| `09_juiceshop_ftp_directory.png` | Répertoire `/ftp/` exposé |
| `10_juiceshop_scoreboard.png` | Score board Juice Shop |

### Références

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Testing Guide v4.2](https://owasp.org/www-project-web-security-testing-guide/)
- [CVSS v3.1 Calculator](https://www.first.org/cvss/calculator/3.1)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)

---

*Rapport généré le 10 août 2026 — UNCHK Licence Cybersécurité Groupe 14*
