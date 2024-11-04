#!/bin/sh
./sha256sums.sh | sha256sum -c >/dev/null || exit 1
./sha256sums.sh | cut -f3 -d' ' | xargs du -ks
