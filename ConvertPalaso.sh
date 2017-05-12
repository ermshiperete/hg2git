#!/bin/bash -e
# Convert $NAME repo from Mercurial to Git

usage()
{
    exec >&2
    echo "Usage: $(basename $0) name-of-repo [url-of-hg-repo [params for hg-to-git.sh]]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help                  Display this help"
	echo "  --add-files-to-hg           Add .gitattributes file, convert .hgignore to"
	echo "                              .gitignore and submit as new commit to hg"
	echo "  --no-cleanup                Omit cleanup step"
	echo ""
	echo "Example:"
	echo "$(basename $0) bloom-desktop  https://bitbucket.org/hatton/bloom-desktop"
    exit ${1-0}
}

abort()
{
    exec >&2
    echo "$1"
    echo ""
    usage 1
}

# Use getopt to parse options into a manageable form

PROGNAME=$(basename "$0")
PARSEDARGS=$(getopt -n "$PROGNAME" \
	-o h --long help,add-files-to-hg,no-cleanup,no-pull \
	-- "$@") || usage $?
eval set -- "$PARSEDARGS"

# Process options

while true
do
	case "$1" in
		-h|--help)           usage ;;
		--add-files-to-hg)   addMissingFilesToHg=1;;
		--no-cleanup)        noCleanup=1;;
		--no-pull)           noPull=1;;
		--)                  shift; break ;;
		*) echo "Internal error: option '$1' not handled"; exit 1;;
	esac
	shift
done

NAME=$1

if [ $# -ne 2 ]; then
	HGREPO=http://hg.palaso.org/$NAME
else
	HGREPO=$2
fi

DIR=$(dirname $(readlink -e $0))
WHERE=$(pwd)


if [ -d ${NAME}_hg ]; then
	if [ -z "$noPull" ]; then
		cd ${NAME}_hg
		hg pull
		hg update
		cd $WHERE
	fi
else
	hg clone $HGREPO ${NAME}_hg
fi

if [ -n "$addMissingFilesToHg" ]; then
	cd ${NAME}_hg
	$DIR/AddMissingFilesToHgBranches.sh
	hg push || true
	cd $WHERE
	shift
fi

echo "****** Preparing git repo ******"
[ -d "$NAME" ] && rm -rf $NAME

$DIR/hg-to-git.sh --authors=$DIR/authors.txt --force $3 $WHERE/${NAME}_hg $WHERE/${NAME}
cd $WHERE/${NAME}
. $DIR/cleanupLineEndingsAndWhiteSpace.sh

if [ -z "$noCleanup" ]; then
	normalize_line_endings
	fix_whitespace
	if [ -z "$addMissingFilesToHg" ]; then
		add_missing_files
	fi
fi
cleanup
