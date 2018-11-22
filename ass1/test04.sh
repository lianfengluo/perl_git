#!/bin/sh
# test script 1 for subset 2
# include branch, delete branch, checkout branch operation
./legit.pl init
./legit.pl branch
touch a b c d
./legit.pl add a b c
ls
./legit.pl branch b1
./legit.pl commit -m "commit-1"
./legit.pl status
./legit.pl branch b1
./legit.pl branch
./legit.pl checkout b1
./lrgit.pl rm a
./legit.pl branch b2
./legit.pl checkout b2
./legit.pl add d
./legit.pl commit -m "commit-2"
./legit.pl branch -d b1
./legit.pl branch -d master
./legit.pl checkout master
./legit.pl add d
./legit.pl checkout master
ls
cat d
cat a
./legit.pl checkout a
./legit.pl branch -d a
./legit.pl rm a
./legit.pl commit -a -m "commit-3"
./legit.pl checkout master
ls
./legit.pl show :a

