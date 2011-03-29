#!/bin/sh
src="$HOME/Downloads/dev"
dst="drop@sifr.mobi:~"
find $src -type d -name Debug -or -name Release | xargs chmod a+w
# time rsync --bwlimit 51 --delete --delete-excluded --exclude .DS_Store -abvzP "$src" "$dst"
time rsync --bwlimit 51 --exclude .DS_Store -abvzP "$src" "$dst"