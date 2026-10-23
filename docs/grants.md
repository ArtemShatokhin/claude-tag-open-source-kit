# Grants: what the agent can reach, and what stops it

This file is the short version of the permission model for the Slack agent in
this repo. Every rule below is enforced by Kortix, not by the prompt: the
prompt is advice, the manifest is the boundary. That separation is what makes an
open-source agent setup reviewable — the security review is a diff of
`kortix.yaml`.

## The five grants

| Grant | Lists | Omitted means | Unlocks |
| --- | --- | --- | --- |
| `connectors` | connector slugs | none | Calls to those connectors from a session. |
| `secrets` | secret names declared under `env` | none | Those secrets in the sandbox. |
| `skills` | skill names | the agent file decides | Loading those skills. |
| `apps` | App slugs | none | Opening those Apps when access is restricted. |
| `kortix_permissions` | `project.*` permissions | none | The CLI, the API and git actions. |

`tools` is the exception: omitted, the agent gets every tool; set it, the agent
gets only what it names. This repo leaves `tools` alone and constrains the tool
calls with `permission` in `agents/slack-ops.md`.

## What the agent may do

Kortix gives each agent its own service account. The person who tags it lends
it no authority, so this is the whole rule:

```
effective = kortix_permissions (kortix.yaml) ∩ ceiling role (bound by an admin) − human-only
```

- `project.credentials.issue` is human-only. No agent can hold it.
- The ceiling role never adds a permission; an admin has to raise it for the
  agent to exceed what `kortix.yaml` already grants.
- A pull request into `kortix.yaml` that changes `agents` needs
  `project.gitops.merge` **and** `project.agent.write` on whoever merges it.

The Slack agent in this repo holds three permissions on purpose: read the
project, read sessions, submit a review. It cannot merge, delete, manage members
or change settings — not because the prompt says so, but because the list stops
there.

## Connector policies, in the order Kortix checks them

For every connector call, the first match wins:

1. The project's `policies:` in `kortix.yaml`, matched on the fully qualified
   name (`github.create_issue`, `*.delete*`).
2. The connector's own `policies:`, matched on the action alone (`*merge*`).
3. `sensitive: true` on the connector: every remaining action, reads included,
   needs approval.
4. `policy.default_mode`: `allow_all` runs everything left; `risk` runs reads
   and holds writes and destructive actions.

Patterns are globs, compared case-insensitively, or `/regex/` in slashes. A rule
can also test arguments, which is how a rule can allow an email to one domain
and hold everything else:

```yaml
policies:
  - match: gmail.send_email
    action: always_run
    conditions:
      - arg: to
        match: "*@yourcompany.com"
  - match: gmail.send_email
    action: require_approval
```

A malformed condition fails closed. A missing argument never matches a pattern,
so a negated condition on it does hold.

## Approvals

A held call runs nothing. It answers `pending_approval` with the arguments the
provider will receive, and posts a card in the Slack thread (and in the web
app's Review page). Approve or deny there. The details worth knowing:

- An approval covers one exact request — same connector, action, arguments and
  account. Change one and it needs a new approval.
- The identical call runs once without a new approval if it repeats within 15
  minutes.
- `approvals.ttl` in this repo is 4h; the platform default is 24h and it clamps
  to between 5 minutes and 30 days. An expired call does not resume the session;
  the agent asks again.
- A project manager, or the person who started the session, decides. A session
  started from a trigger or the CLI is decided by project managers only.

## Checking a manifest before it merges

```bash
kortix validate                  # schema, missing files, undeclared secrets and connectors
kortix validate --scopes         # every grantable project permission
./scripts/check-grants.sh        # this repo's guard: blanket grants, no policy, dangerous permissions
```

`kortix validate` exits 0 clean, 1 on an error, 2 when the file is missing. The
same check runs on merge, so a malformed manifest cannot reach the default
branch.

Then read the two things a checker cannot judge: whether each connector in
`connectors:` is one the task needs, and whether each `require_approval` rule
names an action a person should actually be interrupted for. A blanket
`require_approval` trains people to click through; three precise holds work.
