#!/bin/bash

# Start with static header information for configtx.yaml
echo "Organizations:" > configtx.yaml
echo "    - &OrdererOrg" >> configtx.yaml
echo "        Name: OrdererOrg" >> configtx.yaml
echo "        ID: OrdererMSP" >> configtx.yaml
echo "        MSPDir: crypto-config/ordererOrganizations/example.com/msp" >> configtx.yaml
echo "        Policies:" >> configtx.yaml
echo "            Readers:" >> configtx.yaml
echo "                Type: Signature" >> configtx.yaml
echo "                Rule: \"OR('OrdererMSP.member')\"" >> configtx.yaml
echo "            Writers:" >> configtx.yaml
echo "                Type: Signature" >> configtx.yaml
echo "                Rule: \"OR('OrdererMSP.member')\"" >> configtx.yaml
echo "            Admins:" >> configtx.yaml
echo "                Type: Signature" >> configtx.yaml
echo "                Rule: \"OR('OrdererMSP.admin')\"" >> configtx.yaml
echo "" >> configtx.yaml

# Initialize variables
declare -A orgs
declare -A firstPeers
orderers=()
profiles=""

# Read and process orgs_and_peers.txt
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^Organization:\ (.+)$ ]]; then
        org_name="${BASH_REMATCH[1],,}"
        org_var_name="${org_name,,}"
        orgs[${org_var_name}]=1
    elif [[ $line =~ ([a-z]+)\.([a-z]+)\.example\.com:([0-9]+) ]]; then
        peer_name="${BASH_REMATCH[1]}"
        org_domain="${BASH_REMATCH[2],,}"
        port="${BASH_REMATCH[3]}"
        # Construct fully qualified domain name (FQDN) for the peer
        fqdn="${peer_name}.${org_domain}.example.com"
        # Check if this is the first peer for the org and store it
        if [ -z "${firstPeers[${org_domain}]}" ]; then
            firstPeers[${org_domain}]="$fqdn:$port"
        fi
    elif [[ $line =~ orderer[0-9]+\.example\.com:([0-9]+) ]]; then
        orderer="${BASH_REMATCH[0]}"
        orderers+=("$orderer")
    fi
done < orgs_and_peers.txt

# Add organizations
for org in "${!orgs[@]}"; do
    echo "    - &${org^}" >> configtx.yaml
    echo "        Name: ${org^}MSP" >> configtx.yaml
    echo "        ID: ${org^}MSP" >> configtx.yaml
    echo "        MSPDir: crypto-config/peerOrganizations/${org}.example.com/msp" >> configtx.yaml
    echo "        Policies:" >> configtx.yaml
    echo "            Readers:" >> configtx.yaml
    echo "                Type: Signature" >> configtx.yaml
    echo "                Rule: \"OR('${org^}MSP.admin', '${org^}MSP.peer', '${org^}MSP.client')\"" >> configtx.yaml
    echo "            Writers:" >> configtx.yaml
    echo "                Type: Signature" >> configtx.yaml
    echo "                Rule: \"OR('${org^}MSP.admin', '${org^}MSP.client')\"" >> configtx.yaml
    echo "            Admins:" >> configtx.yaml
    echo "                Type: Signature" >> configtx.yaml
    echo "                Rule: \"OR('${org^}MSP.admin')\"" >> configtx.yaml
    echo "            Endorsement: " >> configtx.yaml
    echo "                Type: Signature" >> configtx.yaml
    echo "                Rule: \"OR('${org^}MSP.peer')\"" >> configtx.yaml
    # Correctly setting AnchorPeers with FQDN and port
    first_peer="${firstPeers[${org}]}"
    peer_host="${first_peer%%:*}"
    peer_port="${first_peer##*:}"
    echo "        AnchorPeers:" >> configtx.yaml
    echo "            - Host: ${peer_host}" >> configtx.yaml
    echo "              Port: ${peer_port}" >> configtx.yaml
    echo "" >> configtx.yaml
    profiles+="                      - *${org^}"$'\n'
done

# Continue with the static parts of the configtx.yaml
cat <<EOF >> configtx.yaml
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
EOF

# Add orderer addresses
for orderer in "${orderers[@]}"; do
    echo "        - ${orderer%%,*}" >> configtx.yaml
done

# Continue with orderer configurations
cat <<EOF >> configtx.yaml
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
$profiles
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
EOF

# Add consenters
for orderer in "${orderers[@]}"; do
    host=$(echo "${orderer%%:*}" | tr -d ' ') # Remove spaces from the host variable
    port="${orderer##*:}"
    port=$(echo "${port%%,*}" | tr -d ' ') # Ensure port is also trimmed of any spaces
    
    # Now, concatenate the host with the rest of the path ensuring no extra spaces
    echo "                - Host: $host" >> configtx.yaml
    echo "                  Port: $port" >> configtx.yaml
    echo "                  ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/$host/tls/server.crt" >> configtx.yaml
    echo "                  ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/$host/tls/server.crt" >> configtx.yaml
done



# Finish the configtx.yaml
cat <<EOF >> configtx.yaml
            Addresses:
                - orderer.example.com:7050
EOF

for orderer in "${orderers[@]}"; do
    echo "                - ${orderer%%,*}" >> configtx.yaml
done

cat <<EOF >> configtx.yaml
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
$profiles
EOF

echo "The configtx.yaml file has been successfully generated."
