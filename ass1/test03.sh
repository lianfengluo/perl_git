#!/bin/sh
# test script 2 for subset 1
# include rm commit -a and status function
./legit.pl init
./legit.pl rm
touch a b c d
./legit.pl add a b c
./legit.pl commit -m "commit-1"
./legit.pl status
./legit.pl rm --cached a
./legit.pl status
./legit.pl rm a
./legit.pl status
./legit.pl rm d
./legit.pl add d
./legit.pl status
./legit.pl commit -m "commit-2"
./legit.pl status
./legit.pl rm d
./legit.pl status
./legit.pl log
touch f
./legit.pl status
./legit.pl commit -a -m "commit-3"
./legit.pl status
./legit.pl log

