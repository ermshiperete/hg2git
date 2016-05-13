# Convert HG repo to Git

## Requirements

git, hg, hg-fast-export, dos2unix (and probably some others)

My main development machine is running Linux which is where I wrote and tried this tool.
I haven't tried running on Windows. It might not work there.

## Preparations

In preparation for the migration to git you might want to close any branches that are no longer
needed or used, e.g. any topic branch that got merged but not closed yet.

## Usage

Run the script passing the name of the repo as well as the URL of the hg repo, e.g.

    ./Convert.sh hearthis https://yautokes@bitbucket.org/sillsdev/hearthis

This will import the commits from Mercurial into git, convert the `.hgignore` file to `.gitignore`,
and do some cleanup, e.g. adding a `.gitattributes` file and normalizing whitespace and line-endings.
Closed and inactive branches in Mercurial will be preserved by accordingly named tags.

The conversion will create two subdirectories, one named `hearthis_hg` (for example) that
contains the Mercurial repo, and another one named `hearthis` that contains the git repo and can
be pushed the github.

It's possible to provide the parameter `--add-files-to-hg`. This will commit the cleanup to the
hg repo. This is useful when the Mercurial will still be used for a while after the initial
conversion to git was done. As long as no commits happen on the git repo side (and nothing in
the mapping etc changed), the conversion can be run again and will only bring in new commits from
hg (or more accurate: the conversion will produce the same results for previous commits).

After the conversion you can push the git repo to GitHub (after creating a new repo on GitHub):

    git remote add origin git@github.com:sillsdev/hearthis.git
    git push origin --prune --all
    git push origin --force --tags

## authors.txt

The accuracy of the conversion can be improved by providing a `authors.txt` file in the same
directory as `Convert.sh`. This file maps authors as they appear in hg to authors in git and
serves to normalize the authors. The entries are of the form

    <author in hg> = <author in git>

For example:

    Mickey <mickey@localhost> = Mickey Mouse <mickey@mouse.com>

The reason this might be necessary is that Mercurial has much looser requirements for the
author specification, whereas Git requires the author entry to be of the form "`Name <email>`".

The `authors.txt` file should list all authors that should be mapped. A list of authors can
be found by running

    hg log --template '{author}\n' | sort | uniq

Add the missing mappings to `authors.txt` before running the conversion. After the conversion
you can run

    git log --format="%an <%ae>" | sort | uniq

to check that you didn't miss anything.

There is a [`authors.txt`](https://docs.google.com/a/sil.org/document/d/1bjOgI5qFDu8Ja_Ign4b6GkLJMf4nkgLe4KYfjCOo7Vk/edit?usp=sharing)
file uploaded to google doc, editable by everyone within SIL. Please add new entries to this
file so that it can be shared when importing our other hg repos.
