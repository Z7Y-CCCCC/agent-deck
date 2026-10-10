#!/bin/sh
# 0: interactive shell survived; 1: reported pane-death defect; 2: harness error.
set -eu
bin=$1
mkdir -p /work/bin /work/project "$HOME/.agent-deck" || exit 2
cp /fixtures/pi /work/bin/pi || exit 2
chmod 755 /work/bin/pi || exit 2
cat > /work/bin/tmux <<'EOF'
#!/bin/sh
exec /usr/bin/tmux -S "$TMUX_TMPDIR/issue2556.sock" "$@"
EOF
chmod 755 /work/bin/tmux || exit 2
export PATH="/work/bin:$PATH" SHELL=/bin/bash TERM=xterm-256color
export AGENTDECK_SKIP_UPDATE_CHECK=1
cat > "$HOME/.agent-deck/config.toml" <<'EOF'
[shell]
exit_to_shell = true
[updates]
auto_update = false
EOF
"$bin" version || exit 2
"$bin" add -c pi -t pi-e2s -g repro --json /work/project || exit 2
"$bin" session start pi-e2s --json || exit 2
name=''
for attempt in $(seq 1 100); do
    name=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^agentdeck_' | head -1 || true)
    if [ -n "$name" ]; then
        pane=$(tmux capture-pane -p -t "$name" 2>/dev/null || true)
        if printf '%s' "$pane" | grep -q PI_READY; then break; fi
    fi
    sleep 0.1
done
if [ -z "$name" ] || ! printf '%s' "${pane:-}" | grep -q PI_READY; then
    echo 'HARNESS_ERROR: fake pi did not become ready'
    exit 2
fi
echo "READY session=$name"
tmux display-message -p -t "$name" 'START_COMMAND=#{pane_start_command}' || exit 2
tmux send-keys -t "$name" /exit Enter || exit 2
sleep 1
if ! tmux has-session -t "$name" 2>/dev/null; then
    echo 'DEFECT: pi /exit destroyed the pane despite exit_to_shell=true'
    exit 1
fi
tmux send-keys -t "$name" 'printf "SHELL_FALLBACK cwd=%s\n" "$PWD"' Enter || exit 2
for attempt in $(seq 1 50); do
    pane=$(tmux capture-pane -p -t "$name" 2>/dev/null || true)
    if printf '%s' "$pane" | grep -q '^SHELL_FALLBACK cwd=/work/project'; then
        printf '%s\n' "$pane"
        echo 'HEALTHY: pi /exit preserved an interactive shell in the project cwd'
        exit 0
    fi
    sleep 0.1
done
printf '%s\n' "$pane"
echo 'HARNESS_ERROR: surviving pane did not execute the shell command'
exit 2
