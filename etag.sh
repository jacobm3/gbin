#clear
echo 
for x in `seq 1 6`; do
    curl -I $1 | egrep -i 'etag'
    sleep 0.1
done
for x in `seq 1 6`; do
    echo -n 'body hash: '
    curl $1 | grep -v 'Generated on.' | md5sum
done
echo 
