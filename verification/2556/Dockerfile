FROM golang:1.25.13-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends tmux python3 zoxide && rm -rf /var/lib/apt/lists/*
ENV AGENTDECK_SKIP_UPDATE_CHECK=1

