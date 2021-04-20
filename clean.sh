MIN=1000

DEL=0
KEEP=0

for i in ~/git/dadaist2/data/its-mock/split/*.fq; 
do 
  c=$(wc -l $i| perl -ne 'print $1 if ($_=~/(\d+)/)'); 
  if [ $c -lt $MIN ]; then
    DEL=$((DEL+1))
    rm $i
  else
    KEEP=$((KEEP+1))
  fi
done

echo "Kept $KEEP, deleted $DEL"
