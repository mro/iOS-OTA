#!/bin/sh
src="<local filesystem path>"
dst="<remote? ssh path>"
find $src -type d -name Debug -or -name Release | xargs chmod a+w
# time rsync --bwlimit 51 --delete --delete-excluded --exclude .DS_Store -abvzP "$src" "$dst"
time rsync --bwlimit 51 --exclude .DS_Store -abvzP "$src" "$dst"