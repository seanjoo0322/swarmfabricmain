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
docker volume rm swarmfabric_orderer${ordnum}.example.com swarmfabric_${peer0}.${network}.example.com swarmfabric_${peer1}.${network}.example.com
