#!/bin/bash

echo "How many orgs: "
read org_count

declare -a org_names   # Array for organization names
declare -A org_peers   # Associative array for mapping orgs to their peers

for ((i = 0; i < org_count; i++)); do
  echo "org name for Org $((i+1)): "
  read org_name
  org_names[$i]=$org_name
  
  while true; do
    echo "How many peers for Org $org_name: "
    read peer_count
    if [[ $peer_count =~ ^[0-9]+$ ]]; then
      break
    else
      echo "Please enter a valid number for the number of peers."
    fi
  done

  # Declare a unique array for each organization's peers
  declare -a "peer_names_$org_name"

  for ((j = 0; j < peer_count; j++)); do
    echo "Enter custom name for peer $((j)) in $org_name:"
    read peer_name

    # Input for port numbers
    echo "Enter port1 and port2 for peer $peer_name:"
    read port1 port2

    # Store the peer name with ports in the organization's unique peer array
    eval "peer_names_${org_name}[$j]=\"$peer_name.$org_name.example.com:$port1,$port2\""
  done

  # Collect and store orderer information
  echo "Enter orderer name for Org $org_name:"
  read orderer_name
  echo "Enter port for orderer $orderer_name:"
  read orderer_port

  # Append orderer information to the organization's unique peer array
  eval "peer_names_${org_name}[\$peer_count]=\"$orderer_name.example.com:$orderer_port\""

  # Store the reference to the organization's peer array in org_peers
  org_peers["$org_name"]="peer_names_$org_name"
done

# Print and output to a file
output_file="orgs_and_peers.txt"
> $output_file # Clear the file content before writing

for org in "${org_names[@]}"; do
  echo "Organization: $org"
  echo "Organization: $org" >> $output_file
  peer_array_name="${org_peers["$org"]}"
  eval "peer_list=(\"\${${peer_array_name}[@]}\")"
  
  for peer in "${peer_list[@]}"; do
    echo "  $peer"
    echo "  $peer" >> $output_file
  done
done
