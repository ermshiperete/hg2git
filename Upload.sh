#!/bin/bash
cd $1
git remote add origin git@github.com:sillsdevarchive/$1.git
git push origin --all
