#!/bin/bash

# 이미 기본 파일 만들어놓아서 사용할 필요가 없음. 

# Set environment variables
export PATH="${PWD}/../bin:$PATH"
export FABRIC_CFG_PATH="${PWD}"

# Function to print a message with brighter cyan color and newline
infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo  # Add an extra echo to insert a newline
}

infoln "org names"
read org1 org2


# Example usage:
infoln "Loading Configuration"
cryptogen generate --config=./crypto-config.yaml

infoln "Creating Genesis Block"
configtxgen -profile SampleMultiNodeEtcdRaft -channelID system-channel -outputBlock ./channel-artifacts/genesis.block

infoln "Creating config block"
configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/mychannel.tx -channelID mychannel

infoln "Org 1 Anchor peer"
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID mychannel -asOrg ${org1}MSP

infoln "Org 2 Anchor Peer"
configtxgen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID mychannel -asOrg ${org2}MSP

infoln "Creating connection-org1 and connection-org2"
./explorerSupporter.sh