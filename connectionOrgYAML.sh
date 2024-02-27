#!/bin/bash

input_file="orgs_and_peers.txt"
current_org=""
peer_list=""
peer_details=""
org_counter=1
declare -A org_ca_ports

function read_cert_file {
    local cert_path="$1"
    if [[ -f "$cert_path" ]]; then
        # Reads the certificate file and escapes it for YAML formatting
        echo "$(sed 's/^/          /' $cert_path)"
    else
        echo "Certificate file not found: $cert_path" >&2
    fi
}

while IFS= read -r line; do
    if [[ "$line" == Organization:* ]]; then
        if [[ ! -z "$current_org" ]]; then
            ca_cert_path="crypto-config/peerOrganizations/${current_org}.example.com/ca/ca.${current_org}.example.com-cert.pem"
            ca_cert_content=$(read_cert_file "$ca_cert_path")

            # Use the ${ca_cert_content} directly in the YAML content below
            printf -v final_yaml -- '---
name: test-network-%s
version: 1.0.0
client:
  organization: %s
  connection:
    timeout:
      peer:
        endorser: "300"
organizations:
  %s:
    mspid: %sMSP
    peers:%s
    certificateAuthorities:
    - ca.%s.example.com
peers:%s
certificateAuthorities:
  ca.%s.example.com:
    url: https://localhost:%s
    caName: ca-%s
    tlsCACerts:
      pem:
        - |
%s
    httpOptions:
      verify: false
' "$current_org" "${current_org^}" "${current_org^}" "${current_org^}" "$peer_list" "$current_org" "$peer_details" "$current_org" "${org_ca_ports[$current_org]}" "$current_org" "$ca_cert_content"

            echo "$final_yaml" > "crypto-config/peerOrganizations/${current_org}.example.com/connection-$current_org.yaml"
        fi

        current_org=$(echo "$line" | cut -d' ' -f2)
        peer_list=""
        peer_details=""
        org_ca_ports[$current_org]=$((7054 + (org_counter - 1) * 1000))
        ((org_counter++))
    elif [[ ! -z "$line" && "$line" != Enter* && "$line" != *orderer* ]]; then
        peer_name=$(echo "$line" | cut -d'.' -f1)
        org_name=$(echo "$line" | cut -d'.' -f2)
        peer_port=$(echo "$line" | cut -d':' -f2 | cut -d',' -f1)

        peer_cert_path="crypto-config/peerOrganizations/${org_name}.example.com/tlsca/tlsca.${org_name}.example.com-cert.pem"
        peer_cert_content=$(read_cert_file "$peer_cert_path")

        peer_list+=$'\n    - '"$peer_name.$org_name.example.com"
        # Insert ${peer_cert_content} directly into the YAML
        peer_details+=$'\n  '"$peer_name.$org_name.example.com:"$'\n    url: grpcs://localhost:'"$peer_port"$'\n    tlsCACerts:\n      pem: |\n'"$peer_cert_content"$'\n    grpcOptions:\n      ssl-target-name-override: '"$peer_name.$org_name.example.com"$'\n      hostnameOverride: '"$peer_name.$org_name.example.com"
    fi
done < "$input_file"

# Process the last organization
if [[ ! -z "$current_org" ]]; then
    ca_cert_path="crypto-config/peerOrganizations/${current_org}.example.com/ca/ca.${current_org}.example.com-cert.pem"
    ca_cert_content=$(read_cert_file "$ca_cert_path")

    printf -v final_yaml -- '---
name: test-network-%s
version: 1.0.0
client:
  organization: %s
  connection:
    timeout:
      peer:
        endorser: "300"
organizations:
  %s:
    mspid: %sMSP
    peers:%s
    certificateAuthorities:
    - ca.%s.example.com
peers:%s
certificateAuthorities:
  ca.%s.example.com:
    url: https://localhost:%s
    caName: ca-%s
    tlsCACerts:
      pem:
        - |
%s
    httpOptions:
      verify: false
' "$current_org" "${current_org^}" "${current_org^}" "${current_org^}" "$peer_list" "$current_org" "$peer_details" "$current_org" "${org_ca_ports[$current_org]}" "$current_org" "$ca_cert_content"

    echo "$final_yaml" > "crypto-config/peerOrganizations/${current_org}.example.com/connection-$current_org.yaml"
fi

echo "YAML generation completed for all organizations."
