./legit.pl init
echo root > root
./legit.pl add root
./legit.pl commit -m root
./legit.pl branch b0
./legit.pl branch b1
./legit.pl branch
./legit.pl checkout b0
echo 0 > level0
./legit.pl add level0
./legit.pl commit -m 0
./legit.pl branch b00
./legit.pl branch b01
./legit.pl branch
./legit.pl checkout b1
echo 1 > level0
./legit.pl add level0
./legit.pl commit -m 1
./legit.pl branch b10
./legit.pl branch b11
./legit.pl branch
