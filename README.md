# Claude Tag, run on an open-source stack you own

Kortix is the open-source AI Operating System: your agents, skills, company memory and connectors live in one git repo you own, and every session runs on its own cloud computer.

This repo is a working Kortix project built for one job: putting an AI agent in a Slack channel where the grants it runs under and the review of its work are files you can read, diff and revert. It is the open-source alternative to Anthropic's Claude Tag for teams that want the Slack thread without handing the runtime, the model choice and the deployment to someone else.

Anthropic's own announcement describes Claude Tag as a Slack teammate that admins provision per channel, in beta for Claude Enterprise and Team customers, running Opus 4.8, with an activity log and org-level spend limits ([anthropic.com/news/introducing-claude-tag](https://www.anthropic.com/news/introducing-claude-tag), read 23 Oct 2026). That is a good product, and if your company is already on Claude Enterprise, it is the shortest path to a first Slack agent. This kit is for the case it does not cover: the agent's configuration, its permissions and its change history live in your repository, it can run on a model you pick, and it runs where you deploy it.

## What is in the box

```
kortix.yaml                      the manifest: agents, grants, connector policies, triggers
agents/slack-ops.md              the agent: prompt, mode, tool permission rules
skills/grant-review/SKILL.md     how the agent reviews its own access before asking for more
scripts/check-grants.sh          preflight that fails a manifest with a blanket grant
docs/grants.md                   what each grant unlocks, and what nothing unlocks
docs/slack-setup.md              the four steps to a working Slack thread
examples/on-call/kortix.yaml     read-only incident triage, approvals on every write
examples/partner-ops/kortix.yaml a customer-facing agent with per-tool blocks
```

## Quickstart

You need the Kortix CLI and a Slack workspace you can install an app into.

```bash
curl -fsSL https://kortix.com/install | bash
kortix init claude-tag-kit            # or clone this repo and run the next line in it
kortix validate                       # schema check; exits 1 on an error
bash scripts/check-grants.sh             # this repo's own guard against blanket grants
kortix ship                           # push the manifest and start the project
kortix channels connect               # Slack: open the link, pick the workspace, allow
```

Then, in Slack: invite the bot to the channel, send `/kortix login` once to link your account, and mention the bot with a task. One Slack thread is one session; the agent works on its own cloud computer and replies in that thread. Full steps, including the commands each person runs and what the bot may read, are in [docs/slack-setup.md](docs/slack-setup.md).

Nothing in this repo needs an Anthropic account. The model is the project default until you pin one per agent or per channel; `kortix agents model slack-ops <model-id>` sets it, and `/kortix models` lists what the channel can run.

## The manifest is the security review

Kortix grants are deny-by-default. An agent with no `connectors` key reaches no connector; an agent with no `kortix_permissions` key may do nothing through the CLI, the API or git. The block that decides what the Slack agent can touch is 20 lines, and it is a file in this repo:

```yaml
agents:
  slack-ops:
    file: agents/slack-ops.md
    connectors: [kortix_slack, github, linear]
    secrets: []
    skills: [grant-review, kortix-slack]
    kortix_permissions:
      - project.read
      - project.session.read
      - project.review.submit
```

Three things follow from that block, and they are the reason to run it this way:

1. **The agent acts as itself, not as the person who tagged it.** Kortix gives each agent its own service account. The person's project role never widens what the agent may do; the effective set is the manifest's `kortix_permissions`, capped by the role an admin binds to the agent.
2. **Every write can be held.** `policy.default_mode: risk` makes every unmatched connector call need approval, and a `policies` rule can require approval or block one named tool. A held call posts a card in the Slack thread with the parameters the connector will receive.
3. **The change history is git.** A session pushes its own branch; work reaches the default branch through a change request a person merges. To see why the agent had GitHub write access in March, read the commit.

`bash scripts/check-grants.sh` is a preflight, not a policy: it fails on `all` in a grant, a missing `policy` block, and the four permissions that let an agent merge its own work or delete a project. Run it in CI on the pull request that edits `kortix.yaml`.

## A worked example: the incident channel

`examples/on-call/kortix.yaml` is the configuration to start from for this pattern (the examples carry their prompt inline, so one file is a whole project and validates on its own). The agent reads the incident channel, pulls the failing check from GitHub and the open issues from Linear, and posts a first-pass diagnosis. It cannot merge, close, comment on the customer's ticket, or restart anything: those tools are `block` in the connector's own `policies`, and the one write it is allowed to attempt, opening a GitHub issue with the diagnosis, is `require_approval` with a four-hour window.

```bash
cp examples/on-call/kortix.yaml kortix.yaml   # read the diff before you ship it
kortix validate && bash scripts/check-grants.sh && kortix ship
```

## Reading list

- The four setup steps, the Slack commands and the join policies: [docs/slack-setup.md](docs/slack-setup.md)
- Every grant, and what an agent can still do when you grant a connector: [docs/grants.md](docs/grants.md)
- Manifest reference, key by key: [kortix.com/docs/project/manifest](https://kortix.com/docs/project/manifest)
- What an open-source Claude Tag is, the project that uses the name, and Kortix as the runtime behind this kit: [open-source Claude Tag, by layer](https://claudetagalternative.com/open-source-claude-tag)
- If you are weighing the two paths for a team: [Claude Tag vs Kortix](https://claudetagalternative.com/claude-tag-vs-kortix) compares them on the questions that decide it — where the agent runs, which model it uses, who approves a write, and what happens to the transcript.

The repository is a starting point, not a product: change the grants, delete the examples, keep the review loop.
