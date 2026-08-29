#!/usr/bin/env bash
# Contract tests for the MCP compose transport (#79).
#
# qluent-cli ships an MCP stdio server exposing the compose surface as typed
# tools; the plugin drove the same flow through the shell instead, paying a
# permission prompt, shell quoting, a temp file and a lossy jq projection for
# each step. These tests pin the declaration, the tool names, and the rule
# that the CLI path survives as the documented fallback rather than being
# replaced.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_JSON="$ROOT/plugins/qluent/.claude-plugin/plugin.json"
COMPOSE_SKILL="$ROOT/plugins/qluent/skills/compose-authoring/SKILL.md"
QUERY_CMD="$ROOT/plugins/qluent/commands/query.md"
ANALYST="$ROOT/plugins/qluent/agents/qluent-analyst.md"

CATALOG_TOOL='mcp__qluent__qluent_compose_catalog'
QUERY_TOOL='mcp__qluent__qluent_compose_query'

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$file" || fail "$file should contain: $needle"
}

command -v jq >/dev/null || fail "jq is required to run this test"

# 1. The plugin declares the server, and declares it the way the CLI exposes
#    it: `qluent mcp serve` over stdio.
jq -e '.mcpServers.qluent' "$PLUGIN_JSON" >/dev/null \
  || fail "plugin.json does not declare the qluent MCP server"
[ "$(jq -r '.mcpServers.qluent.command' "$PLUGIN_JSON")" = "qluent" ] \
  || fail "the MCP server command should be the qluent CLI"
[ "$(jq -r '.mcpServers.qluent.args | join(" ")' "$PLUGIN_JSON")" = "mcp serve" ] \
  || fail "the MCP server args should be: mcp serve"

# The server name decides the tool prefix, so it is part of the contract every
# other file spells out.
server_name=$(jq -r '.mcpServers | keys[0]' "$PLUGIN_JSON")
[ "$CATALOG_TOOL" = "mcp__${server_name}__qluent_compose_catalog" ] \
  || fail "tool prefix does not match the declared server name '$server_name'"

# 2. The skill owns the transport choice, names both tools, and keeps the CLI
#    shapes as an explicit fallback rather than deleting them.
assert_contains "$COMPOSE_SKILL" '## Two transports, one protocol'
assert_contains "$COMPOSE_SKILL" "$CATALOG_TOOL"
assert_contains "$COMPOSE_SKILL" "$QUERY_TOOL"
assert_contains "$COMPOSE_SKILL" 'Prefer the MCP tools'
assert_contains "$COMPOSE_SKILL" 'The CLI shapes below are the fallback'
# The fallback has to remain executable: an older CLI, a missing `mcp`
# package, or a server that failed to launch all land here.
assert_contains "$COMPOSE_SKILL" 'qluent catalog --json-output'
assert_contains "$COMPOSE_SKILL" 'qluent plan --file'

# 3. Callers can actually reach the tools. A skill that prefers a tool the
#    command is not allowed to call would fail silently at runtime.
assert_contains "$QUERY_CMD" "$CATALOG_TOOL"
assert_contains "$QUERY_CMD" "$QUERY_TOOL"
grep -q "^allowed-tools:.*$CATALOG_TOOL" "$QUERY_CMD" \
  || fail "commands/query.md must list $CATALOG_TOOL in allowed-tools"
grep -q "^allowed-tools:.*$QUERY_TOOL" "$QUERY_CMD" \
  || fail "commands/query.md must list $QUERY_TOOL in allowed-tools"
grep -q "^tools:.*$QUERY_TOOL" "$ANALYST" \
  || fail "agents/qluent-analyst.md must list $QUERY_TOOL under tools:"

# 4. Presentation must not assume a file: an MCP-run plan never writes one.
assert_contains "$QUERY_CMD" 'there is no file to open'
assert_contains "$COMPOSE_SKILL" '/qluent:visualize --file'

echo "mcp wiring tests passed"
