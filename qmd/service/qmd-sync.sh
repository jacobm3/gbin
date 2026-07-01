#!/bin/bash
# Pull latest corpus from gitea and reindex. ponytail: simple pull+update, no diffing.
cd /opt/corpus || exit 1
git pull -q --ff-only && /usr/bin/qmd update && /usr/bin/qmd embed
