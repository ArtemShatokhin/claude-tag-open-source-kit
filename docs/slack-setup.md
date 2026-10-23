# Slack setup: from a manifest to a thread

Four steps, in the order the product expects them. The install takes a few
minutes; the grants in `kortix.yaml` are what decide what happens after.

## 1. Ship the project

```bash
curl -fsSL https://kortix.com/install | bash
kortix init claude-tag-kit        # or clone this repo; the manifest is already here
kortix validate
./scripts/check-grants.sh
kortix ship
```

`kortix ship` pushes the manifest, and the project reads it from its default
branch. `kortix validate` is the same check the change request merge runs, so an
error you see here is an error that would have blocked the merge.

If you keep the project in your own git remote, point Kortix at it and push as
usual; the manifest still only takes effect on the default branch.

## 2. Connect Slack

```bash
kortix channels connect
```

Open the link it prints, pick the workspace, allow. On a host without the shared
Slack app, `kortix channels connect --manual` prints a manifest you paste at
`api.slack.com/apps` (create the app **From a manifest**), then
`kortix channels connect --bot-token xoxb-… --signing-secret …`.

`kortix channels status` shows the workspace, the bot user and the webhook URL.
`kortix channels bindings` lists each bound channel with its agent, model and
join policy.

## 3. Let people in

Invite the bot to the channel. Then every person who will use it sends
`/kortix login` once, opens the link, and signs in. That link is private, works
once, and expires in 10 minutes. A message sent before linking runs when the
person links within those 10 minutes.

- `/kortix whoami` shows the account a person is linked as.
- An unlinked sender gets a connect prompt, not a run.
- A linked member without access to the project gets a request-access card that
  account admins see in Kortix.

## 4. Tag it with a task

Mention the bot in the channel with the task. In a channel only a mention
reaches the session; a reply without one stays between people, and the agent
reads the thread the next time someone mentions it. In a DM with the bot every
message reaches the session.

One Slack thread is one session. The agent works on its own cloud computer and
replies in that thread, with live progress and a **Stop** button. Later messages
in the thread continue the same session, also after the sandbox has stopped and
resumed.

## The settings that matter after install

| Setting | Command | What it decides |
| --- | --- | --- |
| Agent | `/kortix agent slack-ops` | Which agent runs in this channel. The default is the project's `default_agent`. |
| Model | `/kortix models`, `/kortix model <id>` | Which model the next new thread runs. A thread keeps the model it started with. |
| Join policy | `/kortix policy owner_approval` | `project_open` (any linked member), `owner_approval` (the session owner approves each new person), `owner_only`. |
| Channel binding | `kortix channels bind <bindingId> --agent slack-ops --policy owner_approval` | The same settings, from a terminal. |

Model choice is where an open-source stack earns its keep: `/kortix models`
lists what the channel can run and how each is paid for, and a channel uses keys
shared with the whole project while a DM can use a person's own keys.

## What the agent may read and post

All projects in one Slack workspace share one bot, and Kortix keeps each
project's agent inside that project's own conversations: a channel or DM bound
to the project, and threads a session of the project started or joined. Anything
else is refused with `conversation_not_in_project`. Slack channel arguments are
ids such as `C0123ABCD`, not names; `kortix connectors show kortix_slack.<action>`
prints the schema before you call one.

## When something does not arrive

| Symptom | Check |
| --- | --- |
| No reply in the thread | `kortix channels status`; is the bot in the channel? Was the message a mention? |
| "Link your account" prompt | `/kortix whoami`, then `/kortix login` again. |
| A connector call sits at pending | The approval card in the thread, or **Review → Needs you**. Approve or deny; a retry does nothing. |
| A call is refused with `conversation_not_in_project` | The channel belongs to another project on the same workspace. `/kortix switch` in that channel. |
| Trigger digest never posts | The channel id in the `morning-digest` prompt is a placeholder; set it to the ops channel's id. |
