#!/bin/sh
./legit.pl init
touch a b c
./legit.pl add a
./legit.pl commit -m commit-A
./legit.pl branch b1
./legit.pl checkout b1
touch d e
./legit.pl rm a b
ls
./legit.pl commit -m commit-B
./legit.pl checkout master
./legit.pl branch b2
./legit.pl checkout b2
touch f g
./legit.pl rm b 
./legit.pl add f g
./legit.pl commit -m commit-C
./legit.pl show 2:b
./legit.pl branch
./legit.pl checkout b1
