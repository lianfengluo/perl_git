./legit.pl init
echo hello > a
./legit.pl add a
./legit.pl commit -m msg
./legit.pl branch b1
./legit.pl checkout b1
echo world > a
./legit.pl add a
./legit.pl commit -m 1
./legit.pl checkout master
echo biu > a
./legit.pl add a
./legit.pl commit -m master
./legit.pl merge b1 -m mg
cat a
echo hello > a
./legit.pl add a
./legit.pl commit -m msg
./legit.pl branch b1
cat a
cat b
./legit.pl checkout b1
echo world > b
./legit.pl add b
./legit.pl commit -m 1
cat a 
cat b
./legit.pl checkout master
cat a
cat b
echo something > c
./legit.pl add c
./legit.pl commit -m master
cat a
cat b
./legit.pl merge b1 -m msg
