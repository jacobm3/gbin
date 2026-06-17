#!/bin/bash
xfce4-terminal \
  --initial-title=htop \
  --maximize \
  --command="bash -c 'htop; exec bash'" \
  --active-tab \
  --tab -T btop --command="bash -c 'btop; exec bash'" \
  --tab -T shell

