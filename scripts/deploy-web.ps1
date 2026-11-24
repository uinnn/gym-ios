# Publica o site no Firebase Hosting.
# Uso (na pasta do projeto):  powershell -ExecutionPolicy Bypass -File scripts/deploy-web.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
node scripts/gen-web-config.mjs
$project = (Select-String -Path .env -Pattern '^FIREBASE_PROJECT_ID=(.+)$').Matches[0].Groups[1].Value.Trim()
npx --yes firebase-tools@latest deploy --only hosting --project $project
