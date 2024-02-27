#!/bin/bash

# Function for printing colored messages
infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo  # Add an extra echo to insert a newline
}

# Prompt the user to input the channel name and remove leading/trailing whitespace
infoln "Type in Channel Name:"
read channelName
channelName=$(echo $channelName | xargs)

infoln "Creating Channel..."
docker exec cli peer channel create -o orderer.example.com:7050 -c ${channelName} -f ./channel-artifacts/${channelName}.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Initialize associative arrays to store organization and peer information
declare -A orgPeers

# Read and process orgs_and_peers.txt
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^Organization:\ (.+)$ ]]; then
        currentOrg="${BASH_REMATCH[1],,}"
        orgPeers[$currentOrg]=""
    elif [[ $line =~ ([a-z]+)\.([a-z]+)\.example\.com:([0-9]+) ]]; then
        peerName="${BASH_REMATCH[1]}"
        peerPort="${BASH_REMATCH[3]}"
        # Append peer information for the current organization
        if [ -z "${orgPeers[$currentOrg]}" ]; then
            orgPeers[$currentOrg]="${peerName}:${peerPort}"
        else
            orgPeers[$currentOrg]+=",${peerName}:${peerPort}"
        fi
    fi
done < orgs_and_peers.txt

# Join peers to the channel and set anchor peers
for org in "${!orgPeers[@]}"; do
    IFS=',' read -r -a peers <<< "${orgPeers[$org]}"
    for peerInfo in "${peers[@]}"; do
        IFS=':' read -r -a peerDetails <<< "$peerInfo"
        peerName="${peerDetails[0]}"
        peerPort="${peerDetails[1]}"

        # Properly capitalize org for MSP ID
        orgCapitalized="$(tr '[:lower:]' '[:upper:]' <<< ${org:0:1})${org:1}"
        mspID="${orgCapitalized}MSP"

        infoln "Adding ${peerName}.${org}.example.com to the channel..."
        docker exec -e CORE_PEER_LOCALMSPID="${mspID}" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${org}.example.com/peers/${peerName}.${org}.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${org}.example.com/users/Admin@${org}.example.com/msp -e CORE_PEER_ADDRESS=${peerName}.${org}.example.com:${peerPort} cli peer channel join -b ${channelName}.block

        # Only set the first peer as the anchor peer
        if [[ ${peerDetails[0]} == ${peers[0]%%:*} ]]; then
            infoln "Setting anchor peer for ${orgCapitalized}..."
            docker exec -e CORE_PEER_LOCALMSPID="${mspID}" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${org}.example.com/peers/${peerName}.${org}.example.com/tls/ca.crt -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${org}.example.com/users/Admin@${org}.example.com/msp -e CORE_PEER_ADDRESS=${peerName}.${org}.example.com:${peerPort} cli peer channel update -o orderer.example.com:7050 -c ${channelName} -f ./channel-artifacts/${mspID}anchors.tx --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
        fi
    done
done

infoln "Channel ${channelName} setup completed."
