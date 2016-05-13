#!/bin/bash -e

# Adapted from http://www.manas.com.ar/mgarcia/2013/10/09/introducing-hg-to-git/

usage()
{
    exec >&2
    echo "Usage: $(basename $0) [OPTIONS] /path/to/hg/repo /path/to/new/repo"
    echo ""
    echo "OPTIONS:"
    echo "  -a, --authors=FILE         File of author mappings"
    echo "  -f, --force                Passed on to hg-fast-export"
    echo "  -h, --help                 Display this help"
    exit ${1-0}
}

abort()
{
    exec >&2
    echo "$1"
    echo ""
    usage 1
}

abs()
{
    readlink -f "$1"
}

# Use getopt to parse options into a manageable form

PROGNAME=$(basename "$0")
PARSEDARGS=$(getopt -n "$PROGNAME" \
	-o a:fh --long authors:,force,help,strip-inactive \
	-- "$@") || usage $?
eval set -- "$PARSEDARGS"

# Process options

AUTHORS=

while true
do
	case "$1" in
		-a|--authors)     AUTHORS=$(abs $2); shift;;
		-f|--force)       FORCE=--force;;
		--help)           usage ;;
		--strip-inactive) STRIP_INACTIVE_BRANCHES=true ;;
		--)               shift; break ;;
		*) echo "Internal error: option '$1' not handled"; exit 1;;
	esac
	shift
done

if [ $# -ne 2 ]
then
	echo "Incorrect number of arguments:" "$@" >&2
    echo "" >&2
	usage 1
fi

[ -d "$1" ]     || abort "$1 should be an existing hg repository"
[ -d "$1/.hg" ] || abort "$1 should be an existing hg repository ($1/.hg must be a directory)"
[ -d "$2" ]     && abort "$2 should not exist"

SOURCE=$(cd "$1" && pwd)
git init "$2" && cd "$2"
LOG=$(mktemp)
SANITIZE=$(mktemp)
trap "rm -f $LOG $SANITIZE" 0

hg-fast-export -r "$SOURCE" $FORCE ${AUTHORS:+-A $AUTHORS} |& tee "$LOG"
git checkout

sed -n '/Warning: sanitized branch/s/.*\[\([^]]*\)\] to \[\([^]]*\)\].*/s@^\1$@\2@/p' "$LOG" |
sort -u -o "$SANITIZE"

(cd "$SOURCE" && hg branches --closed) |
sed -n '/(closed)/s/ *[0-9]*:.*//p' |
sed -f "$SANITIZE" |
while read branch
do
    git tag -am "Mercurial branch that was closed" "closed/$branch" "$branch" &&
    git branch -D "$branch"
done


if [ -n "$STRIP_INACTIVE_BRANCHES" ]; then
	(cd "$SOURCE" && hg branches --closed) |
	sed -n '/(inactive)/s/ *[0-9]*:.*//p' |
	sed -f "$SANITIZE" |
	while read branch
	do
		git tag -am "Mercurial branch that was inactive" "inactive/$branch" "$branch" &&
		git branch -D "$branch"
	done
fi
