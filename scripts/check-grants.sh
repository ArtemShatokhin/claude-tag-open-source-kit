#!/usr/bin/env bash
# check-grants.sh — the guard this repo runs before a manifest reaches main.
#
# It is a textual preflight, not the Kortix schema check: run `kortix validate`
# for that. This script fails on the mistakes a schema cannot see — a blanket
# grant, a manifest with no default policy, and the permissions that let an
# agent merge its own work or delete a project.
#
# Usage: ./scripts/check-grants.sh [path/to/kortix.yaml]
# Exit:  0 clean, 1 findings, 2 no manifest.

set -u

file="${1:-kortix.yaml}"
fails=0
warns=0

ok()   { printf 'ok     %s\n' "$1"; }
fail() { printf 'FAIL   %s\n' "$1"; fails=$((fails + 1)); }
warn() { printf 'warn   %s\n' "$1"; warns=$((warns + 1)); }

if [ ! -f "$file" ]; then
  printf 'error  no such manifest: %s\n' "$file" >&2
  exit 2
fi

printf 'checking %s\n\n' "$file"

# 1. No blanket grant. A grant of `all` hands the agent every connector, every
#    secret, every skill or every permission in the project.
blanket=$(grep -nE '^[[:space:]]*(connectors|secrets|skills|apps|kortix_permissions|tools)[[:space:]]*:[[:space:]]*("?all"?|all)[[:space:]]*$' "$file" || true)
if [ -n "$blanket" ]; then
  fail "blanket grant — list the entries instead:"
  printf '%s\n' "$blanket" | sed 's/^/       /'
else
  ok "no grant set to all"
fi

wild=$(grep -nE '^[[:space:]]*(connectors|secrets|skills|apps|kortix_permissions)[[:space:]]*:.*["'\'']\*["'\'']' "$file" || true)
if [ -n "$wild" ]; then
  fail "grant list contains \"*\" — that is the same as all:"
  printf '%s\n' "$wild" | sed 's/^/       /'
else
  ok "no \"*\" in a grant list"
fi

# 2. A default policy. Without `policy.default_mode`, the platform default is
#    allow_all: every connector call no rule matches runs.
if ! grep -qE '^policy[[:space:]]*:' "$file"; then
  fail "no policy: block — default_mode is allow_all, so every unmatched call runs"
elif ! grep -qE '^[[:space:]]+default_mode[[:space:]]*:[[:space:]]*risk[[:space:]]*$' "$file"; then
  fail "policy.default_mode is not risk — writes run without approval"
else
  ok "policy.default_mode: risk"
fi

# 3. An approval window. The platform default is 24h; a shorter one keeps a
#    stale request from sitting in someone's queue for a day.
if grep -qE '^approvals[[:space:]]*:' "$file"; then
  ok "approvals.ttl set"
else
  warn "no approvals: block — held calls wait the 24h default"
fi

# 4. Connector rules. Without any, `risk` alone decides, which is fine, but a
#    manifest that also blocks nothing has no action a person can rely on.
if grep -qE '^policies[[:space:]]*:' "$file" || grep -qE '^[[:space:]]+policies[[:space:]]*:' "$file"; then
  ok "connector policy rules present"
else
  warn "no policies: rules — every write is held, or none is; name the few that matter"
fi

# 5. Permissions no Slack agent needs. Each is a real escalation or an
#    irreversible action, and none belongs in a channel agent's manifest.
danger=$(grep -nE '^[[:space:]]*-[[:space:]]*project\.(gitops\.merge|gitops\.ref\.any|gitops\.ref\.delete|delete|members\.manage|credentials\.issue|settings\.write)[[:space:]]*$' "$file" || true)
if [ -n "$danger" ]; then
  fail "escalating permission granted to an agent:"
  printf '%s\n' "$danger" | sed 's/^/       /'
else
  ok "no merge, delete, member-management or credential permission"
fi

# 6. The agent file the manifest points at must exist in this checkout.
missing=0
while IFS= read -r path; do
  [ -z "$path" ] && continue
  if [ ! -f "$path" ]; then
    fail "agent file not found: $path"
    missing=1
  fi
done < <(sed -nE 's/^[[:space:]]*file[[:space:]]*:[[:space:]]*([^[:space:]#]+).*/\1/p' "$file")
[ "$missing" -eq 0 ] && ok "agent files referenced by the manifest exist"

printf '\n%d failure(s), %d warning(s)\n' "$fails" "$warns"
[ "$fails" -eq 0 ] || exit 1
