#!/bin/bash

# Prompt the user to input the channel name\


# Remove any leading or trailing whitespace from the input

# Function for printing colored messages
infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo  # Add an extra echo to insert a newline
}


infoln "Type in Channel Name"
read channelName

infoln "Creating Channel"
docker exec cli peer channel create -o orderer.example.com:7050 -c ${channelName} -f ./channel-artifacts/${channelName}.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "Type in how many peers are in org1"
read num_orgs

infoln "Adding ${peername}.org1"
docker exec cli peer channel join -b ${channelName}.block

for ((i=1; i<num_orgs; i++))
do
    echo "Type in your peer${i} and org${i} name and port number(3 input)"
    read peerone orgone portnumber
    orgcapital="$(tr '[:lower:]' '[:upper:]' <<< ${orgone:0:1})${orgone:1}"
    docker exec -e CORE_PEER_ADDRESS=${peerone}.${orgone}.example.com:${portnumber} -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgone}.example.com/peers/${peerone}.${orgone}.example.com/tls/ca.crt cli peer channel join -b ${channelName}.block
done



infoln "Anchor Peer setting as ${peername} Org1"
docker exec cli peer channel update -o orderer.example.com:7050 -c ${channelName} -f ./channel-artifacts/${orgcapital}MSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem




# Prompt the user for the number of organizations
echo -n "Enter the number of organizations: other than org1 "
read num_orgs

# Loop through each organization
for ((org_num=1; org_num<=$num_orgs; org_num++)); do
    echo -n "Enter the name of organization $org_num: "
    read orgname

    capitalorg="$(tr '[:lower:]' '[:upper:]' <<< ${orgname:0:1})${orgname:1}"

    # Prompt the user for the number of peers for this organization
    echo -n "Enter the number of peers for $orgname: "
    read num_peers

    # Loop through each peer for this organization
    for ((peer_num=0; peer_num<$num_peers; peer_num++)); do
        echo -n "Enter the name for peer $peer_num in $orgname: "
        read peername
        echo -n "Enter the port number for $peername in $orgname: "
        read portnumber

        # Construct and execute the Docker command
        docker exec -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/users/Admin@${orgname}.example.com/msp -e CORE_PEER_ADDRESS=${peername}.${orgname}.example.com:${portnumber} -e CORE_PEER_LOCALMSPID="${capitalorg}MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/peers/${peername}.${orgname}.example.com/tls/ca.crt cli peer channel join -b ${channelName}.block

        echo "Added Sucessfully"
        # Uncomment the next line to actually execute the Docker command
        # eval "$docker_command"
    
        if [ "$peer_num" -eq 0 ]; then    
        infoln "Anchor Peer setting as ${peername} ${orgname}"
        docker exec -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/users/Admin@${orgname}.example.com/msp -e CORE_PEER_ADDRESS=${peername}.${orgname}.example.com:${portnumber} -e CORE_PEER_LOCALMSPID="${capitalorg}MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/peers/${peername}.${orgname}.example.com/tls/ca.crt cli peer channel update -o orderer.example.com:7050 -c ${channelName} -f ./channel-artifacts/${capitalorg}MSPanchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
        fi
        
    done
done


