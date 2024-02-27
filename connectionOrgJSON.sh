#!/bin/bash

input_file="orgs_and_peers.txt"
current_org=""
peer_entries=""
peers=""
org_counter=1

function read_cert_file {
    cert_path="$1"
    if [[ -f "$cert_path" ]]; then
        cert_content=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "$cert_path")
        echo -n "$cert_content"
    else
        echo "Certificate file not found: $cert_path" >&2
        echo -n ""
    fi
}

while IFS= read -r line; do
    if [[ "$line" == Organization:* ]]; then
        if [[ ! -z "$current_org" ]]; then
            current_org_capitalized=$(echo "$current_org" | awk '{print toupper(substr($0,1,1))tolower(substr($0,2))}')
            
            ca_cert_path="crypto-config/peerOrganizations/${current_org}.example.com/ca/ca.${current_org}.example.com-cert.pem"
            ca_cert_content=$(read_cert_file "$ca_cert_path")

            ca_port=$((7054 + (org_counter - 1) * 1000))

            # Output the corrected JSON content to file, including the CA certificate content
            echo "{
    \"name\": \"test-network-$current_org\",
    \"version\": \"1.0.0\",
    \"client\": {
        \"organization\": \"$current_org_capitalized\",
        \"connection\": {
            \"timeout\": {
                \"peer\": {
                    \"endorser\": \"300\"
                }
            }
        }
    },
    \"organizations\": {
        \"$current_org_capitalized\": {
            \"mspid\": \"${current_org_capitalized}MSP\",
            \"peers\": [${peer_entries%?}],
            \"certificateAuthorities\": [
                \"ca.$current_org.example.com\"
            ]
        }
    },
    \"peers\": {${peers%?}},
    \"certificateAuthorities\": {
        \"ca.$current_org.example.com\": {
            \"url\": \"https://localhost:${ca_port}\",
            \"caName\": \"ca-$current_org\",
            \"tlsCACerts\": {
                \"pem\": [\"$ca_cert_content\"]
            },
            \"httpOptions\": {
                \"verify\": false
            }
        }
    }
}" > "crypto-config/peerOrganizations/${current_org}.example.com/connection-$current_org.json"
        fi
        current_org=$(echo "$line" | cut -d' ' -f2)
        peer_entries=""
        peers=""
        ((org_counter++))
    elif [[ ! -z "$line" && "$line" != Enter* && "$line" != *orderer* ]]; then
        peer_name=$(echo "$line" | cut -d'.' -f1 | xargs)
        org_name=$(echo "$line" | cut -d'.' -f2 | xargs)
        port=$(echo "$line" | cut -d':' -f2 | cut -d',' -f1 | xargs)
        
        peer_cert_path="crypto-config/peerOrganizations/${org_name}.example.com/tlsca/tlsca.${org_name}.example.com-cert.pem"
        peer_cert_content=$(read_cert_file "$peer_cert_path")

        peer_entries+="\"$peer_name.$org_name.example.com\","
        peers+="\"$peer_name.$org_name.example.com\": {
            \"url\": \"grpcs://localhost:$port\",
            \"tlsCACerts\": {
                \"pem\": \"$peer_cert_content\"
            },
            \"grpcOptions\": {
                \"ssl-target-name-override\": \"$peer_name.$org_name.example.com\",
                \"hostnameOverride\": \"$peer_name.$org_name.example.com\"
            }
        },"
    fi
done < "$input_file"

# Process the last organization
if [[ ! -z "$current_org" ]]; then
    current_org_capitalized=$(echo "$current_org" | awk '{print toupper(substr($0,1,1))tolower(substr($0,2))}')
    
    ca_cert_path="crypto-config/peerOrganizations/${current_org}.example.com/ca/ca.${current_org}.example.com-cert.pem"
    ca_cert_content=$(read_cert_file "$ca_cert_path")

    ca_port=$((7054 + (org_counter - 1) * 1000))

    echo "{
    \"name\": \"test-network-$current_org\",
    \"version\": \"1.0.0\",
    \"client\": {
        \"organization\": \"$current_org_capitalized\",
        \"connection\": {
            \"timeout\": {
                \"peer\": {
                    \"endorser\": \"300\"
                }
            }
        }
    },
    \"organizations\": {
        \"$current_org_capitalized\": {
            \"mspid\": \"${current_org_capitalized}MSP\",
            \"peers\": [${peer_entries%?}],
            \"certificateAuthorities\": [
                \"ca.$current_org.example.com\"
            ]
        }
    },
    \"peers\": {${peers%?}},
    \"certificateAuthorities\": {
        \"ca.$current_org.example.com\": {
            \"url\": \"https://localhost:${ca_port}\",
            \"caName\": \"ca-$current_org\",
            \"tlsCACerts\": {
                \"pem\": [\"$ca_cert_content\"]
            },
            \"httpOptions\": {
                \"verify\": false
            }
        }
    }
}" > "crypto-config/peerOrganizations/${current_org}.example.com/connection-$current_org.json"
fi

echo "JSON generation completed for all organizations."
