#!/usr/bin/env bash
#
# This script generates the list of output paths of this whole
# repository. This list can be used to know which versions are used but
# also to clean the binary cache.

set +e

tmp=$(mktemp)

nix-instantiate all.nix | sed 's/!bin//g' | xargs nix-store -qR | uniq >$tmp

cat $tmp | egrep -v "*.drv$"
cat $tmp | egrep "*.drv$"  | xargs nix-store -q | cat

rm $tmp
