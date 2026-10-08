#!/usr/bin/env node
// Validates the plugin at this repository root (single-plugin layout).
// Run: node scripts/validate.mjs

import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

const errors = [];
const kebab = /^[a-z0-9]+(-[a-z0-9]+)*$/;

function fail(msg) {
  errors.push(msg);
}

function parseJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    fail(`${label}: invalid JSON (${e.message})`);
    return null;
  }
}

function frontmatter(path) {
  const text = readFileSync(path, "utf8");
  const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!m) return null;
  const fields = {};
  for (const line of m[1].split(/\r?\n/)) {
    const idx = line.indexOf(":");
    if (idx > 0) fields[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
  }
  return fields;
}

function checkFrontmatter(md, expectedName, label) {
  const fm = frontmatter(md);
  if (!fm) {
    fail(`${label}: missing YAML frontmatter`);
    return;
  }
  if (!fm.name) fail(`${label}: frontmatter missing "name"`);
  if (!fm.description) fail(`${label}: frontmatter missing "description"`);
  if (fm.name && fm.name !== expectedName)
    fail(`${label}: frontmatter name "${fm.name}" should match "${expectedName}"`);
}

function checkSkills(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir)) {
    if (!statSync(join(dir, entry)).isDirectory()) continue;
    const md = join(dir, entry, "SKILL.md");
    const label = md.slice(root.length + 1);
    if (!existsSync(md)) {
      fail(`${label}: missing SKILL.md in ${entry}/`);
      continue;
    }
    checkFrontmatter(md, entry, label);
  }
}

function checkAgents(dir) {
  if (!existsSync(dir)) return;
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) {
      // agents/<name>/AGENT.md form
      const md = join(p, "AGENT.md");
      const label = md.slice(root.length + 1);
      if (!existsSync(md)) {
        fail(`${label}: missing AGENT.md in ${entry}/`);
        continue;
      }
      checkFrontmatter(md, entry, label);
    } else if (entry.endsWith(".md")) {
      // agents/<name>.md form
      const expected = entry.slice(0, -".md".length);
      checkFrontmatter(p, expected, p.slice(root.length + 1));
    }
  }
}

const manifestPath = join(root, ".devin-plugin", "plugin.json");
if (!existsSync(manifestPath)) {
  fail("missing .devin-plugin/plugin.json");
} else {
  const manifest = parseJson(manifestPath, ".devin-plugin/plugin.json");
  if (manifest) {
    if (!manifest.name) fail("manifest missing \"name\"");
    else if (!kebab.test(manifest.name))
      fail(`name "${manifest.name}" must be lowercase kebab-case`);
    if (manifest.version && !/^\d+\.\d+\.\d+([-+].*)?$/.test(manifest.version))
      fail(`version "${manifest.version}" is not semver`);
    for (const list of ["requiredPlugins", "optionalPlugins", "forbiddenPlugins"]) {
      if (manifest[list] !== undefined && !Array.isArray(manifest[list]))
        fail(`"${list}" must be an array`);
    }
  }
}

checkSkills(join(root, "skills"));
checkAgents(join(root, "agents"));

for (const file of ["hooks.json", ".mcp.json", "mcp_config.json"]) {
  const p = join(root, file);
  if (existsSync(p)) parseJson(p, file);
}

if (errors.length) {
  console.error(`Validation failed with ${errors.length} error(s):`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}
console.log("Plugin validation passed.");
