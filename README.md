# Dent ta Maison

**Crédit : Clovis SFEIR**

Application mobile et backend pour un contrôle bucco-dentaire rapide : prise de photo guidée, contrôle qualité, pré-dépistage des caries et résultat en langage clair. Respect de la vie privée (pas de compte requis).

## Stack

| Partie | Techno |
|--------|--------|
| **App** | Flutter (iOS, macOS, Android) — caméra, étapes démo, formulaire, écran résultat |
| **API** | Node.js, Fastify — file d'analyse, jobs, soumission, admin |
| **ML** | Python, FastAPI — contrôle qualité, pipeline de dépistage |
| **Données** | Redis (BullMQ), stockage local (soumissions + photos) |

## Prérequis

- Node.js 18+, npm
- Python 3.10+
- Flutter 3.x
- Redis (Docker ou installation locale)
- [Optionnel] Clé API OpenAI pour le dépistage visuel et les explications

## Démarrage rapide

1. **Cloner et configurer l'environnement**
   ```bash
   git clone <url-du-repo>
   cd HACKINGHEALTH
   cp .env.example .env
   # Éditer .env et définir OPENAI_API_KEY si vous utilisez la vision.
   ```

2. **Redis**
   ```bash
   docker run -d -p 6379:6379 --name redis-oralscan redis:7-alpine
   ```
   Ou utiliser un Redis local sur le port 6379.

3. **Backend (API + ML)**
   ```bash
   ./scripts/run-api-dev.sh
   ```
   Démarre Redis (si Docker est disponible), le ML sur le port 8000 et l'API sur le port 3000. Sinon lancer le ML et l'API dans des terminaux séparés (voir ci-dessous).

4. **Application**
   ```bash
   cd apps/mobile && flutter run -d macos
   ```
   Ou choisir un appareil iOS/Android ou un simulateur.

- **Admin :** http://localhost:3000/admin  
- **API :** http://localhost:3000  

## Lancer le backend manuellement (sans script)

- **ML :** `cd services/ml && pip install -r requirements.txt && PYTHONPATH=. python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000`
- **API :** `cd services/api && npm install && npm run dev` (charge `.env` à la racine du repo)

## Lancer sur iPhone (même Wi‑Fi que le Mac)

1. Démarrer Redis, ML et API sur le Mac.
2. Dans `apps/mobile/lib/core/constants/api_config_io.dart`, définir `_kLanHost` sur l’IP locale du Mac (ex. `192.168.1.42`). Pour la trouver : `ipconfig getifaddr en0` ou Réglages système → Réseau → Wi‑Fi.
3. Connecter l’iPhone en USB : `cd apps/mobile && flutter run`, puis sélectionner l’iPhone. Première fois : faire confiance au certificat développeur dans Réglages → Général → Gestion des appareils.

## Structure du projet

```
apps/mobile/          # Application Flutter (Dent ta Maison)
services/api/         # API Fastify (analyse, jobs, soumission, admin)
services/ml/          # Service ML FastAPI (pipeline d'inférence)
packages/shared-types/# Types TypeScript/Zod partagés
scripts/              # run-api-dev.sh, run-on-iphone.sh, tests
```

## Production

- Définir `NODE_ENV=production` et, si besoin, `CORS_ORIGIN` (ex. origine de l’interface admin) dans `.env`.
- L’admin (`/admin`) n’a pas d’authentification intégrée : en production, le protéger (reverse-proxy, auth, ou réseau interne).
- Build API : `cd services/api && npm run build && npm start`.
- Build Flutter release : `cd apps/mobile && flutter build ios` ou `flutter build apk`.

## Tests

- **Flutter :** `cd apps/mobile && flutter test`
- **API :** `cd services/api && npm test`
- **ML :** `cd services/ml && PYTHONPATH=. pytest tests/ -v`
- **E2E :** `./scripts/test-e2e.sh` (nécessite Redis + API + ML)

## Licence

Voir le fichier de licence du dépôt.

---

© Clovis SFEIR
