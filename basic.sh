#!/bin/bash
# Set environment variables
export PATH="${PWD}/../bin:$PATH"
export FABRIC_CFG_PATH="${PWD}"

# Function to print a message with brighter cyan color and newline
infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo  # Add an extra echo to insert a newline
}

# Function to ask for number and names of organizations
askForOrgs() {
    infoln "How many organizations do you want to configure?"
    read orgCount

    for ((i=1; i<=orgCount; i++))
    do
        infoln "First letter should be capital. Enter the name of organization $i"
        read orgName
        orgs+=("$orgName")
    done
}

# Ask for channel name
infoln "What is your channel name?"
read channelName

# Ask for organizations
askForOrgs

# Example usage:
infoln "Loading Configuration"
cryptogen generate --config=./crypto-config.yaml

infoln "Creating Genesis Block"
configtxgen -profile SampleMultiNodeEtcdRaft -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

infoln "Creating config block"
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${channelName}.tx -channelID $channelName

# Generate Anchor Peer updates for each organization
for org in "${orgs[@]}"
do
    infoln "Org $org Anchor Peer"
    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${org}MSPanchors.tx -channelID $channelName -asOrg ${org}MSP
done

#infoln "Creating connection-org1 and connection-org2"
#./explorerSupporter.sh
