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

# Function to parse orgs_and_peers.txt for organization names
parseOrgs() {
    # Initialize an empty array to hold organization names
    orgs=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ $line =~ Organization:\ (.+)$ ]]; then
            # Capitalize the first letter of the organization name and append "MSP"
            orgName="${BASH_REMATCH[1]^}MSP"
            orgs+=("$orgName")
        fi
    done < orgs_and_peers.txt
}

# Ask for channel name
infoln "What is your channel name?"
read channelName

# Parse organizations from orgs_and_peers.txt
parseOrgs

# Example usage:
infoln "Loading Configuration"
cryptogen generate --config=./crypto-config.yaml

infoln "Creating Genesis Block"
configtxgen -profile SampleMultiNodeEtcdRaft -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

infoln "Creating config block"
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${channelName}.tx -channelID $channelName

# Generate Anchor Peer updates for each organization
for orgMSP in "${orgs[@]}"
do
    # Extract just the org name from orgMSP for display purposes
    orgName="${orgMSP%MSP}"
    infoln "$orgName Anchor Peer"
    configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/${orgMSP}anchors.tx -channelID $channelName -asOrg $orgMSP
done
