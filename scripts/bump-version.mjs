#!/usr/bin/env node
//
// Maintains the plugin's informational version label.
//
// This version does NOT gate updates. Claude Code tracks this plugin by the
// resolved commit SHA, because neither plugin.json nor the marketplace plugin
// entry declares a `version` — deliberately. A declared version there pins the
// plugin, so forgetting to bump it silently withholds every change from every
// user, which is exactly what happened between 0.4.3 and 0.5.0.
//
// `metadata.version` is marketplace-level and informational only. It records
// what was last released. Its worst failure is a stale label; `make release`
// pins it to the tag so it cannot drift at the moment it matters.
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
  node scripts/bump-version.mjs <version>          Set the informational version label.
  node scripts/bump-version.mjs --check [version]  Verify the label is valid semver and that
                                                   no manifest declares an update-gating
                                                   version. Pass <version> to require a value.

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
  ];
}

// Guards the decision above: a `version` reappearing in either manifest would
// silently re-pin the plugin and stop users receiving updates.
function assertNoPinningVersions(root) {
  const checks = [
    {
      label: 'plugins/qluent/.claude-plugin/plugin.json',
      path: resolve(root, 'plugins/qluent/.claude-plugin/plugin.json'),
      get: (j) => j.version,
    },
    {
      label: '.claude-plugin/marketplace.json (plugins[qluent])',
      path: resolve(root, '.claude-plugin/marketplace.json'),
      get: (j) => j.plugins?.find((p) => p.name === 'qluent')?.version,
    },
  ];
  for (const c of checks) {
    if (c.get(readJson(c.path)) !== undefined) {
      die(
        `${c.label} declares a "version". That pins the plugin, so users stop ` +
          'receiving updates until it is bumped. Remove it; Claude Code tracks ' +
          'this plugin by commit SHA.'
      );
    }
  }
}

function check(root, expected) {
  assertNoPinningVersions(root);
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
  console.log(`OK: version label is ${actual}; no update-gating version declared`);
}

function bump(root, version) {
  if (!SEMVER.test(version)) die(`"${version}" is not a valid semver string`);
  assertNoPinningVersions(root);
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
