#!/bin/sh
# test script 1 for subset 1
# include rm commit -a and status function
./legit.pl init
ls -d .legit
touch a b c d
echo a>b
echo b>b
./legit.pl add a b c d
echo aadfadsfasda>>a
./legit.pl commit -a -m "commit 4 files"
./legit.pl log
./legit.pl rm a
./legit.pl rm e
./legit.pl show :b
./legit.pl rm --cached b
./legit.pl show :b
./legit.pl status
# echo ff>>d
./legit.pl rm --cached d
./legit.pl status
./legit.pl add d
./legit.pl status
./legit.pl rm --cached d
./legit.pl status
./legit.pl rm --force --cached d
./legit.pl commit -a -m "commit 2"
rm c
./legit.pl status
./legit.pl rm --cached c
./legit.pl status
./legit.pl rm d
./legit.pl status
echo afffffffffaa>>a
./legit.pl add a
./legit.pl show :a
./legit.pl rm --force d
./legit.pl status
echo aa > f
./legit.pl add f
./legit.pl commit -a -m "commit 3"
./legit.pl rm --cached f
./legit.pl rm f

