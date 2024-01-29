echo "Which network are you going to up?"
echo "Type 1 or 2"
read network

docker-compose -f docker-compose_org$network.yaml up 

docker ps -a

