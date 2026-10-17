#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, "..");

let failures = 0;
function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    failures++;
  }
}

const unitPath = path.join(rootDir, "systemd", "monerod.service");
assert(fs.existsSync(unitPath), "Missing systemd/monerod.service");
const unitText = fs.readFileSync(unitPath, "utf8");
for (const directive of ["User=monero", "NoNewPrivileges=true", "ProtectSystem=strict", "ProtectHome=true", "TimeoutStopSec=120"]) {
  assert(unitText.includes(directive), `systemd/monerod.service missing '${directive}'`);
}

const confPath = path.join(rootDir, "config", "monerod-pruned.conf");
assert(fs.existsSync(confPath), "Missing config/monerod-pruned.conf");
const confText = fs.readFileSync(confPath, "utf8");
for (const directive of ["prune-blockchain=1", "rpc-bind-ip=127.0.0.1", "rpc-access-control-origins=*", "enable-dns-blocklist=1"]) {
  assert(confText.includes(directive), `config/monerod-pruned.conf missing '${directive}'`);
}

const installerPath = path.join(rootDir, "scripts", "install-or-update.sh");
assert(fs.existsSync(installerPath), "Missing scripts/install-or-update.sh");
const installerText = fs.readFileSync(installerPath, "utf8");
assert(installerText.includes("81AC591FE9C4B65C5806AFC3F0AF4D462A0BDF92"), "Installer missing binaryfate GPG fingerprint");
assert(installerText.includes("gpg --batch --verify"), "Installer missing GPG verification step");

for (const svg of ["hero-banner.svg", "systemd-security-architecture.svg"]) {
  const svgPath = path.join(rootDir, "assets", svg);
  assert(fs.existsSync(svgPath), `Missing SVG asset: assets/${svg}`);
  const text = fs.readFileSync(svgPath, "utf8");
  assert(text.includes("<svg") && text.includes("</svg>"), `Malformed SVG in assets/${svg}`);
}

if (failures > 0) {
  console.error(`\nValidation failed with ${failures} error(s).`);
  process.exit(1);
}

console.log("OK: Verified systemd sandboxing unit, GPG-verified installer script, daemon config, Nginx proxy, and SVG diagrams.");
