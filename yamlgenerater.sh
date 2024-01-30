#!/bin/bash

infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo  # Add an extra echo to insert a newline
}


infoln "Please understand that Orderer other than basic orderer should have some parts removed "
infoln "Such as ordererports that is biggesr than 10000,        - ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:17050
"
infoln "Please understand that port 7050 8050 should not be touched" 
 
sleep 2

# Ask for organization name
echo "Enter organization name:"
read org_name

capitalorg="$(tr '[:lower:]' '[:upper:]' <<< ${org_name:0:1})${org_name:1}"
# Ask for number of peers
echo "Enter the number of peers:"
read peer_count

echo "What number is this orderer(0,2,3,4,5~) NO "1"? basic orderer no input needed" 
read orderer_num

echo "What port number is this orderer? IF this was orderer was basic it MUST be 7050"
read orderer_port

# Create the docker-compose.yaml file
echo "version: '2'

volumes:
  orderer$orderer_num.example.com:" > docker-compose_$org_name.yaml

# Initialize an array for peer names
declare -a peer_names

# Ask for custom peer names and generate volumes
for ((i = 0; i < peer_count; i++)); do
  echo "Enter custom name for peer $((i)):"
  read peer_name
  peer_names[$i]=$peer_name
  echo "  $peer_name.$org_name.example.com:" >> docker-compose_$org_name.yaml
done

# Continue with static parts of the file
echo "
networks:
  test:
    external: true
    name: first-network

services:
  orderer$orderer_num.example.com:
    container_name: orderer$orderer_num.example.com
    image: hyperledger/fabric-orderer:latest
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_LISTENPORT=$orderer_port
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/var/hyperledger/orderer/orderer.genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp
      - ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:17050
      # enabled TLS
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key
      - ORDERER_GENERAL_CLUSTER_ROOTCAS=[/var/hyperledger/orderer/tls/ca.crt]
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: orderer
    volumes:
        - ./channel-artifacts/genesis.block:/var/hyperledger/orderer/orderer.genesis.block
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer$orderer_num.example.com/msp:/var/hyperledger/orderer/msp
        - ./crypto-config/ordererOrganizations/example.com/orderers/orderer$orderer_num.example.com/tls:/var/hyperledger/orderer/tls
        - orderer$orderer_num.example.com:/var/hyperledger/production/orderer
    ports:
      - $orderer_port:$orderer_port
      - 17050:17050
    networks:
      - test
" >> docker-compose_$org_name.yaml

# Generate peer services
for ((i = 0; i < peer_count; i++)); do
  echo "Enter two ports for ${peer_names[$i]} (separated by space):"
  read port1 port2

  echo "  ${peer_names[$i]}.$org_name.example.com:
    container_name: ${peer_names[$i]}.$org_name.example.com
    image: hyperledger/fabric-peer:latest
    environment:
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=first-network
      - FABRIC_LOGGING_SPEC=INFO
      #- FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_PROFILE_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/fabric/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/fabric/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/fabric/tls/ca.crt
      # Peer specific variabes
      - CORE_PEER_ID=${peer_names[$i]}.$org_name.example.com
      - CORE_PEER_ADDRESS=${peer_names[$i]}.$org_name.example.com:$port1
      - CORE_PEER_LISTENADDRESS=0.0.0.0:$port1
      - CORE_PEER_CHAINCODEADDRESS=${peer_names[$i]}.$org_name.example.com:$port2
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:$port2
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=${peer_names[$i]}.$org_name.example.com:$port1
      - CORE_PEER_GOSSIP_BOOTSTRAP=${peer_names[$i]}.$org_name.example.com:$port1
      - CORE_PEER_LOCALMSPID=${org_name}MSP
      - CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:1$port1
    volumes:
        - /var/run/docker.sock:/host/var/run/docker.sock
        - ./crypto-config/peerOrganizations/$org_name.example.com/peers/${peer_names[$i]}.$org_name.example.com/msp:/etc/hyperledger/fabric/msp
        - ./crypto-config/peerOrganizations/$org_name.example.com/peers/${peer_names[$i]}.$org_name.example.com/tls:/etc/hyperledger/fabric/tls
        - ${peer_names[$i]}.$org_name.example.com:/var/hyperledger/production
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    ports:
      - $port1:$port1
      - 1$port1:1$port1
    networks:
      - test
    
" >> docker-compose_$org_name.yaml
done


# Function to replace volume name in the docker-compose template
replace_volume_name() {
    local old_name=$1
    local new_name
    read -p "Replacing name for $old_name: " new_name
    sed -i "s/$old_name/$new_name/g" docker-compose_$org_name.yaml
}


replace_volume_name "first-network"

echo "Docker Compose file has been generated: docker-compose_$org_name.yaml"


