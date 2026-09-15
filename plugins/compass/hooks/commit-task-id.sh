#!/bin/sh
# Compass plugin — a commit Claude makes names its task (adr-041, adr-048).
#
# PreToolUse hook on the Bash and PowerShell tools. Compass links a task to the
# pull requests and files that built it only through a task UUID in a commit
# message, and a commit that lands without one can never be linked later. So in
# a repository connected to Compass, a `git commit` whose message carries no
# UUID is refused (exit 2): Claude reads the reason, adds `Task: <uuid>` and
# commits again. Everything else passes untouched:
#   - any command that is not a `git commit`;
#   - repositories not connected to Compass (the plugin is installed per user);
#   - commits that reuse a message already written (--no-edit, -C/-c, --fixup,
#     --squash, -F <file>);
#   - a machine without a POSIX shell (the hook cannot run, Claude Code goes on).
# POSIX sh and grep only: no jq, python or node on the engineer's machine.
# Generated into the plugin by scripts/build_plugin.py; edit it here.

input=$(cat)

# tool_input.command, still JSON-escaped (\" \n \\ stay as written).
cmd=$(printf '%s' "$input" | tr '\n' ' ' \
  | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -n 1 \
  | sed -e 's/^"command"[[:space:]]*:[[:space:]]*"//' -e 's/"$//')
[ -n "$cmd" ] || exit 0

# A git commit: `git [-C dir | -c key=value]... commit`, at the start of a command
# (start, after ; & | ( or a newline), never `git commit-tree` or a quoted mention.
git_commit='(^|[;&|(]|\\n)[[:space:]]*git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$cmd" | grep -qE "$git_commit" || exit 0

# Only repositories connected to Compass: the plugin enabled in the repo's
# settings, or the Compass CLAUDE.md (the pointer or the generated rules block).
dir=${CLAUDE_PROJECT_DIR:-$PWD}
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
connected=
grep -qs 'compass@compass' "$top/.claude/settings.json" && connected=1
grep -qsE 'works with Compass|compass:agent-rules' "$top/CLAUDE.md" && connected=1
[ -n "$connected" ] || exit 0

# What follows the `commit` word: the options and the message.
after=${cmd#*commit}
uuid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
printf '%s' "$after" | grep -qE "$uuid" && exit 0

# A message written before: amend without editing, reuse, fixup/squash, or a file
# (not `-F -`, whose text is in the command itself and was just checked).
printf '%s' "$after" | grep -qE '(^|[[:space:]])(--no-edit|-C|-c|--reuse-message|--reedit-message|--fixup|--squash)([[:space:]=]|$)' && exit 0
printf '%s' "$after" | grep -qE '(^|[[:space:]])(-F|--file)([[:space:]]+|=)[^-[:space:]]' && exit 0

cat >&2 <<'EOF'
Compass: this commit names no task, so Compass could never link it to the work it builds.
End the commit message with the line

  Task: <uuid>

using the task you are working on: get_context() lists your claims under "Active Claims".
No claim fits this change? Claim one first: manage_tasks("claim", id="<uuid>", status="in_progress").
Then run the same commit again with that line.
EOF
exit 2
