#!/bin/sh
# test script 3 for subset 2
# include branch, merge and checkout branch operation
./legit.pl init
./legit.pl branch
touch a b c d
echo a > a
./legit.pl add a b c
ls
./legit.pl branch b1
./legit.pl commit -m "commit-1"
./legit.pl status
./legit.pl branch b1
./legit.pl branch
./legit.pl checkout b1
./legit.pl status
touch a
./legit.pl add d
./legit.pl status
cat a
cat b
cat c
cat d
./legit.pl show :a
./legit.pl show :b
./legit.pl show :c
./legit.pl show :d
./legit.pl commit -a -m "commit-2"
ls
./legit.pl checkout master
echo d >> d
./legit.pl add d
ls
touch a
./legit.pl show :a
./legit.pl show :b
./legit.pl show :c
./legit.pl show :d
./legit.pl commit -m "commit 3"
./legit.pl merge
./legit.pl merge b1
./legit.pl show 0:d
./legit.pl show 1:d
./legit.pl show 2:d
./legit.pl show 0:a
./legit.pl show 2:a
./legit.pl show 2:b
./legit.pl show 2:c
./legit.pl show 2:d
./legit.pl merge -m "commit 4" b1
./legit.pl log

