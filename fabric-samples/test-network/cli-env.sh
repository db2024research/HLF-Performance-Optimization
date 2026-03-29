#!/usr/bin/env bash
# Source this file in any new shell to get working 'peer' CLI defaults.
#   source ./cli-env.sh

# Base tool paths (match test-network)
export PATH="${PWD}/../bin:$PATH"
export FABRIC_CFG_PATH="${PWD}/../config"

# Helper to target any peer quickly:
use_peer_env () {
  local MSPID="$1" MSPPATH="$2" ADDR="$3" TLSCRT="$4"
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="${MSPID}"
  export CORE_PEER_MSPCONFIGPATH="${MSPPATH}"
  export CORE_PEER_ADDRESS="${ADDR}"
  export CORE_PEER_TLS_ROOTCERT_FILE="${TLSCRT}"
}

# Shortcuts for the four peers in this network:
peer0org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:7051" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"; }
peer1org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:8051" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt"; }
peer0org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:9051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"; }
peer1org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:6051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt"; }

# Orderer TLS
export ORDERER_TLS_CA="${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
