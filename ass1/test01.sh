#!/bin/sh
# test script 2 for subset 0
# include init, add, commit, log, show function
./legit.pl init
ls -d .legit
touch a b c d
echo a>b
echo b>b
./legit.pl add b c d
# empty log file
./legit.pl log
./legit.pl commit -m "commit 3 files"
./legit.pl add a
./legit.pl commit -m "commit a"
echo aa>>a
./legit.pl commit -a -m "change a commit"
./legit.pl log
#unknown commit
./legit.pl show 3:a
#second commit
./legit.pl show 2:a
./legit.pl show 1:a
./legit.pl show 1:b
./legit.pl show 0:a
echo aaa>>a
./legit.pl add a
./legit.pl show :a
