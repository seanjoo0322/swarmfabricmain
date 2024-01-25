#!/bin/bash

infoln() {
    echo
    echo -e "\e[96m$1\e[0m"
    echo
}


infoln "This is configtx Generator" 

infoln "Type in how many orgs you have"
read org_count

org_profiles=""

echo '
Organizations:
    - &OrdererOrg
        Name: OrdererOrg
        ID: OrdererMSP
        MSPDir: crypto-config/ordererOrganizations/example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: "OR('\''OrdererMSP.member'\'')"
            Writers:
                Type: Signature
                Rule: "OR('\''OrdererMSP.member'\'')"
            Admins:
                Type: Signature
                Rule: "OR('\''OrdererMSP.admin'\'')"
' > configtx.yaml

for ((i=0; i<org_count; i++)); do 
    infoln "What is the name of your Org"
    read orgname
    infoln "Main port for anchor peer"
    read anchorpeerport
    infoln "anchor peer name" 
    read anchorpeername
    echo "
    - &${orgname}
        Name: ${orgname}MSP
        ID: ${orgname}MSP
        MSPDir: crypto-config/peerOrganizations/${orgname}.example.com/msp
        Policies:
            Readers:
                Type: Signature
                Rule: \"OR('${orgname}MSP.admin', '${orgname}MSP.peer', '${orgname}MSP.client')\"
            Writers:
                Type: Signature
                Rule: \"OR('${orgname}MSP.admin', '${orgname}MSP.client')\"
            Admins:
                Type: Signature
                Rule: \"OR('${orgname}MSP.admin')\"
            Endorsement:
                Type: Signature
                Rule: \"OR('${orgname}MSP.peer')\"
        AnchorPeers:
            - Host: $anchorpeername.${orgname}.example.com
              Port: $anchorpeerport
    " >> configtx.yaml
    org_profiles="${org_profiles}                      - *${orgname}"$'\n'
done



# Ask for the number of orderers
infoln "How many orderers do you have?"
read orderer_count

# Initialize the variables
orderer_addresses=""
orderer_addressesone=""
orderer_consenters=""

for ((i=1; i<=(orderer_count-1); i++)); do 
    infoln "What is the port for orderer$i?"
    read ordererport

    # Append orderer address to the list
    orderer_addresses+="        - orderer$i.example.com:$ordererport"$'\n'
    orderer_addressesone+="                - orderer$i.example.com:$ordererport"$'\n'

    # Append orderer consenter details
    orderer_consenters+="                - Host: orderer$i.example.com"$'\n'
    orderer_consenters+="                  Port: $ordererport"$'\n'
    orderer_consenters+="                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer$i.example.com/tls/server.crt"$'\n'
    orderer_consenters+="                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer$i.example.com/tls/server.crt"$'\n'
done


echo "
Capabilities:
    Channel: &ChannelCapabilities
        V2_0: true
    Orderer: &OrdererCapabilities
        V2_0: true
    Application: &ApplicationCapabilities
        V2_0: true
Application: &ApplicationDefaults
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        LifecycleEndorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
        Endorsement:
            Type: ImplicitMeta
            Rule: "MAJORITY Endorsement"
    Capabilities:
        <<: *ApplicationCapabilities
Orderer: &OrdererDefaults
    OrdererType: etcdraft
    Addresses:
        - orderer.example.com:7050
$orderer_addresses
    BatchTimeout: 2s
    BatchSize:
        MaxMessageCount: 10
        AbsoluteMaxBytes: 99 MB
        PreferredMaxBytes: 512 KB
    Organizations:
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
        BlockValidation:
            Type: ImplicitMeta
            Rule: "ANY Writers"
Channel: &ChannelDefaults
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
    Capabilities:
        <<: *ChannelCapabilities
Profiles:
    TwoOrgsChannel:
        Consortium: SampleConsortium
        <<: *ChannelDefaults
        Application:
            <<: *ApplicationDefaults
            Organizations:
$org_profiles
            Capabilities:
                <<: *ApplicationCapabilities
    SampleMultiNodeEtcdRaft:
        <<: *ChannelDefaults
        Capabilities:
            <<: *ChannelCapabilities
        Orderer:
            <<: *OrdererDefaults
            OrdererType: etcdraft
            EtcdRaft:
                Consenters:
                - Host: orderer.example.com
                  Port: 7050
                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
$orderer_consenters
            Addresses:
                - orderer.example.com:7050
$orderer_addressesone
            Organizations:
            - *OrdererOrg
            Capabilities:
                <<: *OrdererCapabilities
        Application:
            <<: *ApplicationDefaults
            Organizations:
            - <<: *OrdererOrg
        Consortiums:
            SampleConsortium:
                Organizations:
$org_profiles
" >>configtx.yaml



infoln "configtx.yaml has been generated."
