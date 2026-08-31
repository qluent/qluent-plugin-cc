# Releasing the qluent plugin

## The one rule: the CLI ships first

This plugin calls the `qluent` CLI and its MCP tools. The CLI knows nothing
about the plugin. That one-way dependency decides the release order.

`QLUENT_MIN_CLI_VERSION` in `plugins/qluent/scripts/cli-requirements.sh` is the
single declared contract between the two repos. `tests/test_cli_version_gate.sh`
pins that number into `README.md` and `commands/setup.md`, so it cannot drift
into the docs.

Two habits keep it honest:

1. **Raise it in the same PR that first uses a new CLI capability.** Not at
   release time, when nobody remembers which commit needed what. If a change
   calls nothing new, leave the constant alone.
2. **Never merge a raise before the matching CLI is on npm.** Otherwise the
   session-start gate tells every user to run `npm install -g @qluent/cli` and
   then hands them a CLI that is still too old.

`scripts/check-cli-floor.sh` enforces the second habit on every PR: it compares
`QLUENT_MIN_CLI_VERSION` against the newest published `@qluent/cli` and fails
the build if the plugin has outrun it.

## Cutting a release

Distribution is the marketplace, so merging to `main` is what actually reaches
users. The tag exists so a version is a thing people can name, pin and read
release notes for.

```bash
make bump VERSION=0.5.0        # writes all three manifest fields
git commit -am "Release plugin 0.5.0"
# open a PR, merge it, pull main, then:
make release VERSION=0.5.0     # verifies, tests, tags, pushes
```

`make release` refuses to run from a dirty tree, from a branch other than
`main`, from a `main` that is behind origin, or when the manifests disagree with
`VERSION`. Pushing the tag triggers
[.github/workflows/release.yml](.github/workflows/release.yml), which re-checks
the manifests and the CLI floor, runs the full suite, and publishes the GitHub
release with generated notes.

## Rehearsing the release path

`release.yml` only ever runs on a tag, so a change to it is first exercised
during a real release unless you rehearse. A tag with a prerelease suffix is
marked as a prerelease on GitHub and never displays as the latest release:

```bash
git checkout -b test/release-path
node scripts/bump-version.mjs 0.5.1-rc1
git commit -am "test: temporary rc bump"
git tag -a v0.5.1-rc1 -m "rehearsal" && git push origin v0.5.1-rc1
```

Push only the tag, not the branch, so `main` keeps its version. Delete the tag,
the prerelease and the branch once the run is green.

Unlike the CLI there is nothing irreversible here — the plugin publishes no
package, and marketplace users track `main`, which a prerelease tag never
touches.

## Versioning

Three fields must agree, all written by `scripts/bump-version.mjs`:

```text
.claude-plugin/marketplace.json           metadata.version
.claude-plugin/marketplace.json           plugins[qluent].version
plugins/qluent/.claude-plugin/plugin.json version
```

Bump the minor when commands, agents, skills or hooks change shape; the patch
for fixes and prompt wording.

## Local checks

```bash
make test           # every tests/*.sh
make version-check  # manifests agree
make cli-floor      # required CLI version is installable
```
