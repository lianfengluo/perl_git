#!/bin/sh
# test script 1 for subset 0
# include init, add, commit function
./legit.pl
./legit.pl init
# check more than one init
ls -d .legit
./legit.pl init
touch a
./legit.pl add a
./legit.pl commit -m "commit 1 file"
touch b c d
./legit.pl add b c d
./legit.pl commit -m "commit 3 files"
echo aa>>a
./legit.pl commit -a -m "test -a command"
