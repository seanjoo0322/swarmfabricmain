echo "Which network are you going to down?"
echo "Type 1 or 2"
read network

docker-compose -f docker-compose-testingnetwork$network.yaml down