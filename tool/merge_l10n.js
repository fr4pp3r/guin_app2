// Merges per-lane localization parts into the single per-locale ARB files.
// Usage: node tool/merge_l10n.js
//
// Reads every tool/l10n_parts/*.json of shape { key: {en,fil,ceb}, "@key": {...meta} }
// and appends the new keys to lib/l10n/app_{en,fil,ceb}.arb, keeping existing keys.
// Validates: duplicate keys across parts, keys that already exist, missing locales,
// placeholder parity across locales, and missing placeholder metadata.
const fs = require('fs');
const path = require('path');

const root = process.cwd();
const partsDir = path.join(root, 'tool', 'l10n_parts');
const l10nDir = path.join(root, 'lib', 'l10n');
const locales = { en: 'app_en.arb', fil: 'app_fil.arb', ceb: 'app_ceb.arb' };

const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));

const arbs = {};
for (const [code, file] of Object.entries(locales)) {
  arbs[code] = readJson(path.join(l10nDir, file));
}

const existingKeys = new Set();
for (const code of Object.keys(locales)) {
  for (const k of Object.keys(arbs[code])) existingKeys.add(k);
}

if (!fs.existsSync(partsDir)) {
  console.error(`No parts directory: ${partsDir}`);
  process.exit(1);
}

const errors = [];
const warnings = [];
const owner = {};
const meta = {};
const additions = {};
for (const code of Object.keys(locales)) additions[code] = {};

const files = fs.readdirSync(partsDir).filter((f) => f.endsWith('.json')).sort();
for (const f of files) {
  const data = readJson(path.join(partsDir, f));
  for (const [k, v] of Object.entries(data)) {
    if (k.startsWith('@')) {
      meta[k.slice(1)] = v;
      continue;
    }
    if (owner[k]) {
      errors.push(`Duplicate key "${k}" in ${f} (already defined in ${owner[k]})`);
      continue;
    }
    owner[k] = f;
    if (existingKeys.has(k)) {
      warnings.push(`Key "${k}" from ${f} already exists in ARB; keeping existing value`);
      continue;
    }
    for (const code of Object.keys(locales)) {
      if (typeof v[code] !== 'string') {
        errors.push(`Missing "${code}" translation for key "${k}" in ${f}`);
      } else {
        additions[code][k] = v[code];
      }
    }
  }
}

// Placeholder parity + metadata checks (on the additions only).
const placeholdersOf = (s) => {
  const set = new Set();
  const re = /\{\s*(\w+)\s*[,}]/g;
  let m;
  while ((m = re.exec(s)) !== null) set.add(m[1]);
  return set;
};
for (const k of Object.keys(additions.en)) {
  const en = additions.en[k];
  const enPh = placeholdersOf(en);
  if (enPh.size > 0 && !meta[k]) {
    warnings.push(`Key "${k}" has placeholders but no "@${k}" metadata`);
  }
  for (const code of ['fil', 'ceb']) {
    const other = additions[code][k];
    if (other === undefined) continue;
    const otherPh = placeholdersOf(other);
    for (const p of enPh) if (!otherPh.has(p)) {
      errors.push(`Placeholder "{${p}}" missing in "${code}" for key "${k}"`);
    }
    for (const p of otherPh) if (!enPh.has(p)) {
      errors.push(`Extra placeholder "{${p}}" in "${code}" for key "${k}"`);
    }
  }
}

if (errors.length) {
  console.error(`\n${errors.length} error(s):`);
  for (const e of errors) console.error('  ✗ ' + e);
  console.error('\nAborted; no files written.');
  process.exit(1);
}

const newKeys = Object.keys(additions.en).sort();
for (const code of Object.keys(locales)) {
  const out = arbs[code];
  for (const k of newKeys) {
    out[k] = additions[code][k];
    if (code === 'en' && meta[k]) out['@' + k] = meta[k];
  }
  fs.writeFileSync(
    path.join(l10nDir, locales[code]),
    JSON.stringify(out, null, 2) + '\n',
    'utf8',
  );
}

console.log(`Merged ${files.length} part file(s).`);
console.log(`Added ${newKeys.length} new key(s): ${newKeys.join(', ')}`);
if (warnings.length) {
  console.log(`\n${warnings.length} warning(s):`);
  for (const w of warnings) console.log('  ! ' + w);
}
