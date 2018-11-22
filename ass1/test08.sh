./legit.pl init
echo root > root
./legit.pl add root
./legit.pl commit -m root
./legit.pl branch b0
./legit.pl branch b1
./legit.pl branch
./legit.pl checkout b0
seq 0 120 > 120.txt
./legit.pl add 120.txt
./legit.pl commit -m 0
./legit.pl merge b0 -m msg
# ./legit.pl show :120.txt
# cat .legit/master/.pointer
./legit.pl checkout master
./legit.pl merge master -m msg
./legit.pl checkout b1
seq 7 121 > 121.txt
./legit.pl show :root
cat root
ls
./legit.pl status
# ls
# ls .legit/.index
./legit.pl commit -a -m b1
./legit.pl checkout master
./legit.pl merge b1 -m msg
cat root
./legit.pl log
echo toor > root
./legit.pl add root
./legit.pl commit -m 4
./legit.pl checkout master
# ./legit.pl show :120.txt
./legit.pl status
./legit.pl merge b0 -m merge_b0
./legit.pl log
