// Gera web/public/config.js a partir do .env (não versionado).
// Use FIREBASE_WEB_API_KEY (chave restrita ao domínio do site); se faltar, usa FIREBASE_API_KEY.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
const env = {};
if (existsSync(".env")) for (const l of readFileSync(".env", "utf8").split(/\r?\n/)) {
  const m = l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, "");
}
const get = (k) => process.env[k] || env[k];
const key = get("FIREBASE_WEB_API_KEY") || get("FIREBASE_API_KEY");
const project = get("FIREBASE_PROJECT_ID");
if (!key || !project) { console.error("Defina FIREBASE_WEB_API_KEY (ou FIREBASE_API_KEY) e FIREBASE_PROJECT_ID no .env"); process.exit(1); }
writeFileSync("web/public/config.js", `// Gerado por scripts/gen-web-config.mjs — não versionar.
export const firebaseConfig = {
  apiKey: ${JSON.stringify(key)},
  authDomain: ${JSON.stringify(project + ".web.app")},
  projectId: ${JSON.stringify(project)},
};
`);
console.log("web/public/config.js gerado para", project);
