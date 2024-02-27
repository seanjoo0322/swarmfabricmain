#!/bin/bash

echo "Which org are you going to down?"
read network


docker-compose -f docker-compose_${network}.yaml down
docker rmi $(docker images -q 'dev-*')
docker volume prune


echo "list ur peers(2 max)"
read peer0 peer1

echo "Which orderer? Leave blank for basic"
read ordnum
docker volume rm swarmfabricmain_orderer${ordnum}.example.com swarmfabricmain_${peer0}.${network}.example.com swarmfabricmain_${peer1}.${network}.example.com
