#!/bin/sh
for sha in *.sha256; do
	f=$(echo "$sha" | sed -e s/.sha256//)
	# Some .sha256 files are .sha256sum
	if ! grep -q "$f" "$sha"; then
		echo "$(cat "$sha")  $f"
	else
		cat "$sha"
	fi
done
for sum in *.sha256sum; do
	cat "$sum"
done
