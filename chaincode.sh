infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo  # Add an extra echo to insert a newline
}

infoln "Type in your chaincode file name(Ex)chaincode-go): "
read chaincodeFile

infoln "Type in the name of your chaincode"
read chaincodeName

infoln "Step 1: Packaging Chaincode"
docker exec cli peer lifecycle chaincode package ${chaincodeName}.tar.gz --path /opt/gopath/src/github.com/chaincode/${chaincodeFile} --label ${chaincodeName}_1.0


infoln "Adding peer0 org1"
docker exec cli peer lifecycle chaincode install ${chaincodeName}.tar.gz

PACKAGEIDORG1=$(docker exec cli peer lifecycle chaincode queryinstalled | grep "Package ID: ${chaincodeName}_1.0" | awk '{print $3}' | tr -d ',')

infoln "Type in name for org one"
read orgname


infoln "How many peers do you have for ${orgname} except for peer0?"
read peernum

for ((i=1; i<=peernum; i++))
do  
    infoln "Type in peer name"
    read peername

    infoln "Type in port number for ${peername}"
    read portnum

    infoln "Adding ${peername}.${orgname}"
    docker exec -e CORE_PEER_ADDRESS=${peername}.${orgname}.example.com:${portnum} -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/peers/${peername}.${orgname}.example.com/tls/ca.crt cli peer lifecycle chaincode install ${chaincodeName}.tar.gz
done



infoln "How many orgs do you have other than org1?" 
read orgCount

for (( i=1; i<=orgCount; i++ ))
do
    infoln "What is your org name?"
    read orgname

    infoln "How many peers do u have?"
    read peerCount

    capitalorg="$(tr '[:lower:]' '[:upper:]' <<< ${orgname:0:1})${orgname:1}"

    for ((i=0; i<peerCount; i++ ))
    do
        echo "What is the name of peer${i} in ${orgname}?"
        read peername

        echo "What is port number of ${peername}?"
        read portnumber

        infoln "Adding ${peername}.${orgname}"
        docker exec -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/users/Admin@${orgname}.example.com/msp -e CORE_PEER_ADDRESS=${peername}.${orgname}.example.com:${portnumber} -e CORE_PEER_LOCALMSPID="${capitalorg}MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/peers/${peername}.${orgname}.example.com/tls/ca.crt cli peer lifecycle chaincode install ${chaincodeName}.tar.gz
    done
done


infoln "Type in your channel Name"
read channelName

infoln "APPROVE org1"
docker exec cli peer lifecycle chaincode approveformyorg --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --channelID ${channelName} --name ${chaincodeName} --version 1 --sequence 1 --waitForEvent --package-id $PACKAGEIDORG1

for (( i=1; i<=orgCount; i++ ))
do
    infoln "Type in your org name for org${i} assuming org0 is the basic org"
    read orgname

    infoln "Type in peer0 name"
    read peerzero

    infoln "Type in port for ${peerzero}"
    read portnumber

    capitalorg="$(tr '[:lower:]' '[:upper:]' <<< ${orgname:0:1})${orgname:1}"

    infoln "APPROVING ${orgname}"
    docker exec -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/users/Admin@${orgname}.example.com/msp -e CORE_PEER_ADDRESS=${peerzero}.${orgname}.example.com:${portnumber} -e CORE_PEER_LOCALMSPID="${capitalorg}MSP" -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/${orgname}.example.com/peers/${peerzero}.${orgname}.example.com/tls/ca.crt cli peer lifecycle chaincode approveformyorg --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --channelID ${channelName} --name ${chaincodeName} --version 1 --sequence 1 --waitForEvent --package-id $PACKAGEIDORG1
done 




infoln "Checking Commit Readiness if not true true, ur doomed"
docker exec cli peer lifecycle chaincode checkcommitreadiness --channelID ${channelName} --name ${chaincodeName} --version 1 --sequence 1

infoln "Commiting Chaincode.." 
docker exec cli peer lifecycle chaincode commit -o orderer.example.com:7050 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --channelID mychannel --name basic --version 1 --sequence 1

exit 0;

infoln "Checking if commit is complete"
docker exec cli peer lifecycle chaincode querycommitted --channelID ${channelName} --name ${chaincodeName}

infoln "Invoking main code"
docker exec cli peer chaincode invoke -o orderer2.example.com:8050 --tls true --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/ordererOrganizations/example.com/orderers/orderer2.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n basic --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"InitLedger","Args":[]}'
