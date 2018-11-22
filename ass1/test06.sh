
legit.pl init
echo hello > a
legit.pl add a
legit.pl commit -m 0
legit.pl log
legit.pl branch b1
legit.pl checkout b1
echo world > a
legit.pl commit -a -m 1
echo how r u > a
legit.pl add a
legit.pl checkout master
echo world > a
legit.pl checkout master
