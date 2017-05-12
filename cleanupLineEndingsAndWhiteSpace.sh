#!/bin/bash -e
# Rewrite git repo to normalize line endings and cleanup whitespace

normalize_line_endings()
{
	echo "****** Normalize line endings ******"
	# Normalize line endings
	# see http://christoph.ruegg.name/blog/cleaning-up-after-migrating-from-hg-to-git.html
	# Note: the dos2unix in Ubuntu Precise automatically skips binary files. We can't use fromdos
	# instead of dos2unix because that can't skip binary files.
	AUTOCRLF=$(git config --local core.autocrlf) || true
	# Unset whitespace options, otherwise the conversion doesn't work because the files get
	# checked out with normalized line endings, resulting in an (always) dirty tree.
	[ -f .git/info/attributes ] && mv .git/info/attributes{,.bak}
	echo "* !text !whitespace" > .git/info/attributes
	git config core.autocrlf false
	git reset --hard
	git filter-branch -f --prune-empty --tree-filter 'git ls-files -z | xargs -0 dos2unix' --tag-name-filter cat -- --all
	if [ -z "$AUTOCRLF" ]; then
		git config --unset core.autocrlf
	else
		git config core.autocrlf "$AUTOCRLF"
	fi
	rm .git/info/attributes
	[ -f .git/info/attributes.bak ] && mv .git/info/attributes{.bak,} || true
}

fix_whitespace()
{
	# Fix whitespace
	echo "****** Fix whitespace ******"

	[ -f .git/info/attributes ] && mv .git/info/attributes{,.bak}
	add_gitattributes .git/info/attributes

	# following lines based on https://github.com/npp-community/nppcr_repo_scripts/blob/master/git/wsfix.sh
	WS_FILTER='filter_whitespace()
	{
		if git rev-parse --quiet --verify $GIT_COMMIT^ >/dev/null
		then
			against=$(map $(git rev-parse $GIT_COMMIT^))
			git reset -q $against -- .
		else
			# Initial commit: diff against an empty tree object
			against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
			git rm --cached -rfq --ignore-unmatch '*'
		fi
		git diff --full-index $against $GIT_COMMIT | git apply --cached --whitespace=fix || true
	}'

	git filter-branch -f --index-filter "$WS_FILTER; filter_whitespace" --tag-name-filter cat -- --all || true

	rm .git/info/attributes
	[ -f .git/info/attributes.bak ] && mv .git/info/attributes{.bak,} || true
}

add_gitattributes()
{
	GITATTR=$1
	[ -z $GITATTR ] && GITATTR=.gitattributes
	cat > $GITATTR <<-'ENDOFFILE'
		* text=auto whitespace=space-before-tab,indent-with-non-tab,trailing-space,tabwidth=4

		*.cs    diff=csharp
		*.cpp   diff=cpp
		*.h     diff=cpp
		*.idh   diff=cpp

		# Different settings for javascript files
		*.js   whitespace=-indent-with-non-tab,tab-in-indent,trailing-space,tabwidth=2
		*.ts   whitespace=-indent-with-non-tab,tab-in-indent,trailing-space,tabwidth=2
		*.htm* whitespace=-indent-with-non-tab,tab-in-indent,trailing-space,tabwidth=2
		*.tmx  whitespace=-indent-with-non-tab,tab-in-indent,trailing-space,tabwidth=2

		# Don't check (nor fix) whitespace for generated files
		*.csproj -whitespace
		*.resx -whitespace
		*.Designer.cs -whitespace
		*.vdproj -whitespace
		*.config -whitespace
		*.settings -whitespace
		*.ReSharper -whitespace
		*.vcxproj -whitespace
		*.vcxproj.filters -whitespace
		*.patch -whitespace
		*.svg -whitespace
		*.xml -whitespace
		*.bmml -whitespace
		*.DotSettings -whitespace
		*.mdpolicy -whitespace
		changelog -whitespace
ENDOFFILE
}

convert_hgignore()
{
	HGIGNORE=$1
	GITIGNORE=$2

	sed 's/^glob://g;s/^relglob://g;s/^syntax:\s*glob//g;s/^syntax:\s*relglob//g;s/^re://g;s/^relre://g;s/^regexp://g;s/^syntax:\s*re//g;s/^syntax:\s*relre//g;s/^syntax:\s*regexp//g;s/^\(output\|obj\|.bzr\|bin\|test-results\|config\|packages\)$/\1\//g;s#\\#/#g' < "$HGIGNORE" > "$GITIGNORE"
}

add_missing_files()
{
	# Add .gitattributes file to all branches if missing. Convert .hgignore to .gitignore.
	# Submit as a new commit
	echo "****** Add .gitattributes file and convert .hgignore ******"
	IFS=$'\n'
	for BRANCH in $(git branch); do
		COMMIT=0
		BRANCH="${BRANCH#"${BRANCH%%[![:space:]]*}"}"
		BRANCH="${BRANCH#* }"

		echo "************ Adding missing files for $BRANCH"
		git checkout -f ${BRANCH#origin/}
		if [ ! -f .gitattributes ]; then
			add_gitattributes
			git add .gitattributes
			COMMIT=1
		fi

		for HGIGNORE in $(find . -name .hgignore); do
			GITIGNORE="$(dirname $HGIGNORE)/.gitignore"
			if [ ! -f "$GITIGNORE" ]; then
				echo "Converting $HGIGNORE file"
				convert_hgignore "$HGIGNORE" "$GITIGNORE"
				git add "$GITIGNORE"
				COMMIT=1
			fi
		done

		if [ $COMMIT -gt 0 ] ; then
			git commit -m "Adding .gitattributes and .gitignore files" --author="Git Importer <sillsdevgerrit@users.noreply.github.com>"
		fi
	done
}

cleanup()
{
	echo "****** Cleanup ******"
	git fsck --full
	git prune
	git gc --aggressive
}

if [ ! -d .git ]; then
	echo "Need to be in root of git repo"
	exit
fi
