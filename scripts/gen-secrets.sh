#!/bin/sh
# Gera GymApp/Secrets.swift a partir do .env (local) ou de variáveis de ambiente (CI).
set -eu
cd "$(dirname "$0")/.."
[ -f .env ] && { set -a; . ./.env; set +a; }
: "${FIREBASE_API_KEY:?defina FIREBASE_API_KEY no .env ou nos Secrets do GitHub}"
: "${FIREBASE_PROJECT_ID:?defina FIREBASE_PROJECT_ID}"
cat > GymApp/Secrets.swift <<SWIFT
// Gerado por scripts/gen-secrets.sh — não editar nem versionar.
enum Secrets {
    static let firebaseAPIKey = "${FIREBASE_API_KEY}"
    static let firebaseProjectID = "${FIREBASE_PROJECT_ID}"
}
SWIFT
