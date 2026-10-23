---
name: grant-review
description: Use when a task needs a connector action you do not hold, when a call comes back blocked or unauthorised, or when someone asks why the agent could or could not do something.
---

# Grant review

The grants of this agent are in `kortix.yaml` under `agents.slack-ops`. They
are deny-by-default, and this skill is how you ask for one more without
widening what the agent can do.

## 1. Prove you need it

Write the exact action you tried or want to try: `<connector>.<action>`, from
`kortix connectors discover` or `kortix connectors show`. Then write the task
that needs it and the evidence that the task is real — the issue key, the
thread, the failing command. "It would be useful" is not evidence.

Check what the block actually was before you ask for a grant:

| Answer | What it means | What to do |
| --- | --- | --- |
| `connector_not_connected` | The connector has no account yet. | Ask a project manager to authorise one. Do not ask for a code change. |
| `pending_approval` | The action is allowed but held. | Nothing to grant: the card is waiting for a person. Do not retry. |
| A policy `block` | The project decided this action never runs. | Do not work around it. A person has to change `policies` in `kortix.yaml`. |
| `agent_scope_insufficient` | The action is outside the agent's `kortix_permissions`. | Propose the single permission, below. |
| No such action in `connectors` | The connector is not granted at all. | Propose the connector, below. |

## 2. Propose the smallest change

One line per change, in a branch and a change request, never on the default
branch:

```yaml
agents:
  slack-ops:
    connectors: [kortix_slack, linear, github, sentry]   # + sentry
```

or, for the CLI and API, one `kortix_permissions` entry:

```yaml
    kortix_permissions:
      - project.read
      - project.session.read
      - project.review.submit
      - project.trigger.read                              # + trigger read
```

Never propose `all`, never propose `project.gitops.merge`, `project.delete`,
`project.members.manage` or `project.credentials.issue` — the last one is
human-only and no agent may hold it. If the task needs one of those, it is not
an agent task.

## 3. Say what changes, then stop

In the change request description, state the action, the task, the narrowest
grant that covers it, and what the agent could newly do with it. Open the
change request with `project.review.submit`, post the link in the thread, and
stop. The merge is a person's decision; a running session never picks up the
new grant by itself, so tell them a new session starts with it.

## Why this is worth the friction

An agent that can grant itself access has no access boundary at all; the review
is the boundary. This is the same loop Kortix uses for code: a session pushes
its own branch, and work reaches the default branch only through a change
request a person merges. In an open-source setup that loop is a file you can
read, which is the whole point of running it here.
