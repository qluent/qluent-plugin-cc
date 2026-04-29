#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SEMVER = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const DEFAULT_ROOT = resolve(SCRIPT_DIR, '..');

function parseArgs(argv) {
  const args = { check: false, root: DEFAULT_ROOT, version: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--check') args.check = true;
    else if (a === '--root') args.root = resolve(argv[++i]);
    else if (a.startsWith('--root=')) args.root = resolve(a.slice('--root='.length));
    else if (a === '-h' || a === '--help') {
      printUsage();
      process.exit(0);
    } else if (!args.version) args.version = a;
    else die(`Unexpected argument: ${a}`);
  }
  return args;
}

function printUsage() {
  console.log(`Usage:
  node scripts/bump-version.mjs <version>          Bump every manifest to <version>.
  node scripts/bump-version.mjs --check [version]  Verify all manifests share the same version.
                                                   Pass <version> to require a specific value.

Options:
  --root <path>    Repository root (defaults to the parent of this script).`);
}

function die(msg) {
  console.error(`Error: ${msg}`);
  process.exit(1);
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (err) {
    die(`Failed to read ${path}: ${err.message}`);
  }
}

function writeJson(path, value) {
  writeFileSync(path, JSON.stringify(value, null, 2) + '\n');
}

function targets(root) {
  const marketplacePath = resolve(root, '.claude-plugin/marketplace.json');
  const pluginPath = resolve(root, 'plugins/qluent/.claude-plugin/plugin.json');
  return [
    {
      label: '.claude-plugin/marketplace.json (metadata.version)',
      path: marketplacePath,
      get: (j) => j.metadata?.version,
      set: (j, v) => {
        j.metadata = j.metadata || {};
        j.metadata.version = v;
      },
    },
    {
      label: '.claude-plugin/marketplace.json (plugins[qluent].version)',
      path: marketplacePath,
      get: (j) => j.plugins?.find((p) => p.name === 'qluent')?.version,
      set: (j, v) => {
        const entry = j.plugins?.find((p) => p.name === 'qluent');
        if (!entry) die('marketplace.json has no plugin entry named "qluent"');
        entry.version = v;
      },
    },
    {
      label: 'plugins/qluent/.claude-plugin/plugin.json (version)',
      path: pluginPath,
      get: (j) => j.version,
      set: (j, v) => {
        j.version = v;
      },
    },
  ];
}

function check(root, expected) {
  const items = targets(root);
  const versions = items.map((t) => ({ label: t.label, version: t.get(readJson(t.path)) }));
  const distinct = new Set(versions.map((v) => v.version));

  if (distinct.size !== 1) {
    console.error('Error: version drift detected across manifests:');
    versions.forEach((v) => console.error(`  ${v.label}: ${v.version ?? '(missing)'}`));
    process.exit(1);
  }

  const [actual] = distinct;
  if (!actual || !SEMVER.test(actual)) {
    die(`Version "${actual}" is not a valid semver string`);
  }
  if (expected && actual !== expected) {
    die(`Expected version "${expected}" but found "${actual}"`);
  }
  console.log(`OK: every manifest is at ${actual}`);
}

function bump(root, version) {
  if (!SEMVER.test(version)) die(`"${version}" is not a valid semver string`);
  const items = targets(root);
  const seen = new Map();
  for (const t of items) {
    const json = seen.get(t.path) ?? readJson(t.path);
    t.set(json, version);
    seen.set(t.path, json);
  }
  for (const [path, json] of seen) writeJson(path, json);
  console.log(`Bumped ${seen.size} file(s) to ${version}:`);
  for (const path of seen.keys()) console.log(`  ${path}`);
}

const args = parseArgs(process.argv.slice(2));
if (args.check) check(args.root, args.version);
else if (args.version) bump(args.root, args.version);
else {
  printUsage();
  process.exit(1);
}
