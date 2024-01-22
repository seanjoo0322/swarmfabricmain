#!/bin/bash

echo "Which network are you going to down?"
echo "Type 1 or 2"
read network

if [ "$network" == "1" ]; then
    docker-compose -f docker-compose-testingnetwork1.yaml down
    docker rmi $(docker images -q 'dev-*')
    docker volume rm swarmfabric_orderer.example.com swarmfabric_peer1.org1.example.com swarmfabric_peer0.org1.example.com
elif [ "$network" == "2" ]; then
    docker-compose -f docker-compose-testingnetwork2.yaml down
    docker rmi $(docker images -q 'dev-*')
    docker volume rm swarmfabric_orderer2.example.com swarmfabric_peer1.org2.example.com swarmfabric_peer0.org2.example.com
else
    echo "Invalid choice. Please type 1 or 2."
fi
