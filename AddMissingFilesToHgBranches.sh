#!/bin/bash
# Add .gitattributes file to all branches if missing. Convert .hgignore to .gitignore.
# Submit as a new commit
echo "****** Add .gitattributes file and convert .hgignore ******"
. $(dirname $0)/cleanupLineEndingsAndWhiteSpace.sh
LOGFILE=/tmp/multibranch-$(basename $(pwd))
IFS=$'\n'
for BRANCH in $(hg branches); do
	COMMIT=0
	BRANCH="$(expr match "$BRANCH" '\([^ ]*\)')"

	if [ $(hg heads --template '{branches} {rev}:{node}\n' "$BRANCH" | wc -l) -gt 1 ]; then
		echo "Found branch with multiple heads:" >> $LOGFILE
		echo "$(hg heads --template '{branches} {rev}:{node}\n' $BRANCH)" >> $LOGFILE
		echo "**** Found branch with multiple heads in $BRANCH"
	fi

	echo "Processing $BRANCH"
	hg update "branch($BRANCH)"
	if [ ! -f .gitattributes ]; then
		add_gitattributes
		hg add .gitattributes
		COMMIT=1
	fi

	for HGIGNORE in $(find . -name .hgignore); do
		GITIGNORE="$(dirname $HGIGNORE)/.gitignore"
		if [ ! -f "$GITIGNORE" ]; then
			echo "Converting $HGIGNORE file"
			convert_hgignore "$HGIGNORE" "$GITIGNORE"
			hg add "$GITIGNORE"
			COMMIT=1
		fi
	done

	if [ $COMMIT -gt 0 ] ; then
		hg commit -m "Adding .gitattributes and .gitignore files

This is in preparation for the migration to git."
	fi
done
