#!/usr/bin/env bash
set -euo pipefail

# -------------------- Globals --------------------
export PATH="${PWD}/../bin:$PATH"
export FABRIC_CFG_PATH="${PWD}/../config"

CHANNEL_NAME="mychannel"
CC_NAME="fabcar"
CC_VERSION="1.0"
CC_LABEL="${CC_NAME}_${CC_VERSION}"
CC_LANG="node"
CC_SRC_PATH="../chaincode/fabcar/javascript"
CC_PKG="${CC_NAME}.tar.gz"

ORDERER_ADDR="localhost:7050"
ORDERER_TLS_CA="${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"

ORG1_MSP="Org1MSP"
ORG2_MSP="Org2MSP"

P0O1_ADDR="localhost:7051"
P0O1_TLS="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
P1O1_ADDR="localhost:8051"
P1O1_TLS_DIR="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls"
P1O1_TLS="${P1O1_TLS_DIR}/ca.crt"

P2O1_ADDR="localhost:1051"
P2O1_TLS_DIR="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls"
P2O1_TLS="${P2O1_TLS_DIR}/ca.crt"

P3O1_ADDR="localhost:1151"
P3O1_TLS_DIR="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer3.org1.example.com/tls"
P3O1_TLS="${P3O1_TLS_DIR}/ca.crt"

P4O1_ADDR="localhost:1251"
P4O1_TLS_DIR="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer4.org1.example.com/tls"
P4O1_TLS="${P4O1_TLS_DIR}/ca.crt"

P5O1_ADDR="localhost:1351"
P5O1_TLS_DIR="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer5.org1.example.com/tls"
P5O1_TLS="${P5O1_TLS_DIR}/ca.crt"

P6O1_ADDR="localhost:1451"
P6O1_TLS_DIR="${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer6.org1.example.com/tls"
P6O1_TLS="${P6O1_TLS_DIR}/ca.crt"

P0O2_ADDR="localhost:9051"
P0O2_TLS="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
P1O2_ADDR="localhost:6051"
P1O2_TLS_DIR="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls"
P1O2_TLS="${P1O2_TLS_DIR}/ca.crt"

P2O2_ADDR="localhost:2051"
P2O2_TLS_DIR="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer2.org2.example.com/tls"
P2O2_TLS="${P2O2_TLS_DIR}/ca.crt"

P3O2_ADDR="localhost:2151"
P3O2_TLS_DIR="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer3.org2.example.com/tls"
P3O2_TLS="${P3O2_TLS_DIR}/ca.crt"

P4O2_ADDR="localhost:2251"
P4O2_TLS_DIR="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer4.org2.example.com/tls"
P4O2_TLS="${P4O2_TLS_DIR}/ca.crt"

P5O2_ADDR="localhost:2351"
P5O2_TLS_DIR="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer5.org2.example.com/tls"
P5O2_TLS="${P5O2_TLS_DIR}/ca.crt"

P6O2_ADDR="localhost:2451"
P6O2_TLS_DIR="${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer6.org2.example.com/tls"
P6O2_TLS="${P6O2_TLS_DIR}/ca.crt"


# CA endpoints + TLS roots (NOTE: tls-cert.pem is correct)
CA_ORG1_URL="https://localhost:7054"
CA_ORG2_URL="https://localhost:8054"
CA_ORG1_TLS="${PWD}/organizations/fabric-ca/org1/tls-cert.pem"
CA_ORG2_TLS="${PWD}/organizations/fabric-ca/org2/tls-cert.pem"

# Unique enrollment IDs (avoid collisions with any old 'peer1')
EID_ORG1="peer1org1"
ESECRET_ORG1="peer1org1pw"
EID_ORG2="peer1org2"
ESECRET_ORG2="peer1org2pw"

# Unique enrollment IDs (avoid collisions with any old 'peer2')
EID_ORG1="peer2org1"
ESECRET_ORG1="peer2org1pw"
EID_ORG2="peer2org2"
ESECRET_ORG2="peer2org2pw"

# Unique enrollment IDs (avoid collisions with any old 'peer3')
EID_ORG1="peer3org1"
ESECRET_ORG1="peer3org1pw"
EID_ORG2="peer3org2"
ESECRET_ORG2="peer3org2pw"

# Unique enrollment IDs (avoid collisions with any old 'peer4')
EID_ORG1="peer4org1"
ESECRET_ORG1="peer4org1pw"
EID_ORG2="peer4org2"
ESECRET_ORG2="peer4org2pw"

# Unique enrollment IDs (avoid collisions with any old 'peer5')
EID_ORG1="peer5org1"
ESECRET_ORG1="peer5org1pw"
EID_ORG2="peer5org2"
ESECRET_ORG2="peer5org2pw"

# Unique enrollment IDs (avoid collisions with any old 'peer6')
EID_ORG1="peer6org1"
ESECRET_ORG1="peer6org1pw"
EID_ORG2="peer6org2"
ESECRET_ORG2="peer6org2pw"

die() { echo "ERROR: $*" >&2; exit 1; }

use_peer_env () {
  local MSPID="$1" MSPPATH="$2" ADDR="$3" TLSCRT="$4"
  export CORE_PEER_TLS_ENABLED=true
  export CORE_PEER_LOCALMSPID="${MSPID}"
  export CORE_PEER_MSPCONFIGPATH="${MSPPATH}"
  export CORE_PEER_ADDRESS="${ADDR}"
  export CORE_PEER_TLS_ROOTCERT_FILE="${TLSCRT}"
}

warmup_peer () {
  local MSPID="$1" MSPPATH="$2" ADDR="$3" TLSCRT="$4"
  use_peer_env "${MSPID}" "${MSPPATH}" "${ADDR}" "${TLSCRT}"
  # This query forces the chaincode container to start on that peer
  peer chaincode query -C "${CHANNEL_NAME}" -n "${CC_NAME}" \
    -c '{"Args":["queryAllCars"]}' \
    --peerAddresses "${ADDR}" \
    --tlsRootCertFiles "${TLSCRT}" || true
}


check_peer_joined () {
  local MSPID="$1" MSPPATH="$2" ADDR="$3" TLSCRT="$4"
  use_peer_env "${MSPID}" "${MSPPATH}" "${ADDR}" "${TLSCRT}"

  echo "Checking ${ADDR} ..."
  # retry getinfo (peer might still be starting)
  for i in {1..10}; do
    if peer channel getinfo -c "${CHANNEL_NAME}" >/dev/null 2>&1; then
      echo "✅ ${ADDR} is joined to ${CHANNEL_NAME}"
      return 0
    fi
    sleep 1
  done

  echo "❌ ${ADDR} not joined (yet), attempting join..."
  # try join; consider 'already exists' as success
  if out=$(peer channel join -b "channel-artifacts/${CHANNEL_NAME}.block" 2>&1); then
    echo "✅ ${ADDR} joined ${CHANNEL_NAME}"
  else
    if echo "$out" | grep -qi "LedgerID already exists"; then
      echo "ℹ️ ${ADDR} was already joined."
    else
      echo "$out"
      die "Join failed for ${ADDR}"
    fi
  fi
}


ensure_peer1_org1_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org1.example.com"
  mkdir -p "${P1O1_TLS_DIR}"

  # Register (idempotent)
  fabric-ca-client register \
    --caname ca-org1 \
    --id.name "${EID_ORG1}" --id.secret "${ESECRET_ORG1}" --id.type peer \
    --id.affiliation org1.department1 \
    --url "${CA_ORG1_URL}" \
    --tls.certfiles "${CA_ORG1_TLS}" 2>/dev/null || true

  # Enroll MSP
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/msp" \
    --csr.hosts "peer1.org1.example.com" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org1.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/msp/config.yaml"

  # Enroll TLS
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer1.org1.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${P1O1_TLS_DIR}/tlscacerts/"* "${P1O1_TLS_DIR}/ca.crt"
  cp "${P1O1_TLS_DIR}/signcerts/"*  "${P1O1_TLS_DIR}/server.crt"
  cp "${P1O1_TLS_DIR}/keystore/"*  "${P1O1_TLS_DIR}/server.key"
}

ensure_peer2_org1_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org1.example.com"
  mkdir -p "${P2O1_TLS_DIR}"

  # Register (idempotent)
  fabric-ca-client register \
    --caname ca-org1 \
    --id.name "${EID_ORG1}" --id.secret "${ESECRET_ORG1}" --id.type peer \
    --id.affiliation org1.department1 \
    --url "${CA_ORG1_URL}" \
    --tls.certfiles "${CA_ORG1_TLS}" 2>/dev/null || true

  # Enroll MSP
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/msp" \
    --csr.hosts "peer2.org1.example.com" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org1.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/msp/config.yaml"

  # Enroll TLS
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer2.org1.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${P2O1_TLS_DIR}/tlscacerts/"* "${P2O1_TLS_DIR}/ca.crt"
  cp "${P2O1_TLS_DIR}/signcerts/"*  "${P2O1_TLS_DIR}/server.crt"
  cp "${P2O1_TLS_DIR}/keystore/"*  "${P2O1_TLS_DIR}/server.key"
}

ensure_peer3_org1_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org1.example.com"
  mkdir -p "${P3O1_TLS_DIR}"

  # Register (idempotent)
  fabric-ca-client register \
    --caname ca-org1 \
    --id.name "${EID_ORG1}" --id.secret "${ESECRET_ORG1}" --id.type peer \
    --id.affiliation org1.department1 \
    --url "${CA_ORG1_URL}" \
    --tls.certfiles "${CA_ORG1_TLS}" 2>/dev/null || true

  # Enroll MSP
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer3.org1.example.com/msp" \
    --csr.hosts "peer3.org1.example.com" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org1.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer3.org1.example.com/msp/config.yaml"

  # Enroll TLS
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer3.org1.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer3.org1.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${P3O1_TLS_DIR}/tlscacerts/"* "${P3O1_TLS_DIR}/ca.crt"
  cp "${P3O1_TLS_DIR}/signcerts/"*  "${P3O1_TLS_DIR}/server.crt"
  cp "${P3O1_TLS_DIR}/keystore/"*  "${P3O1_TLS_DIR}/server.key"
}

ensure_peer4_org1_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org1.example.com"
  mkdir -p "${P4O1_TLS_DIR}"

  # Register (idempotent)
  fabric-ca-client register \
    --caname ca-org1 \
    --id.name "${EID_ORG1}" --id.secret "${ESECRET_ORG1}" --id.type peer \
    --id.affiliation org1.department1 \
    --url "${CA_ORG1_URL}" \
    --tls.certfiles "${CA_ORG1_TLS}" 2>/dev/null || true

  # Enroll MSP
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer4.org1.example.com/msp" \
    --csr.hosts "peer4.org1.example.com" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org1.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer4.org1.example.com/msp/config.yaml"

  # Enroll TLS
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer4.org1.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer4.org1.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${P4O1_TLS_DIR}/tlscacerts/"* "${P4O1_TLS_DIR}/ca.crt"
  cp "${P4O1_TLS_DIR}/signcerts/"*  "${P4O1_TLS_DIR}/server.crt"
  cp "${P4O1_TLS_DIR}/keystore/"*  "${P4O1_TLS_DIR}/server.key"
}

ensure_peer5_org1_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org1.example.com"
  mkdir -p "${P5O1_TLS_DIR}"

  # Register (idempotent)
  fabric-ca-client register \
    --caname ca-org1 \
    --id.name "${EID_ORG1}" --id.secret "${ESECRET_ORG1}" --id.type peer \
    --id.affiliation org1.department1 \
    --url "${CA_ORG1_URL}" \
    --tls.certfiles "${CA_ORG1_TLS}" 2>/dev/null || true

  # Enroll MSP
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer5.org1.example.com/msp" \
    --csr.hosts "peer5.org1.example.com" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org1.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer5.org1.example.com/msp/config.yaml"

  # Enroll TLS
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer5.org1.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer5.org1.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${P5O1_TLS_DIR}/tlscacerts/"* "${P5O1_TLS_DIR}/ca.crt"
  cp "${P5O1_TLS_DIR}/signcerts/"*  "${P5O1_TLS_DIR}/server.crt"
  cp "${P5O1_TLS_DIR}/keystore/"*  "${P5O1_TLS_DIR}/server.key"
}



ensure_peer6_org1_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org1.example.com"
  mkdir -p "${P6O1_TLS_DIR}"

  # Register (idempotent)
  fabric-ca-client register \
    --caname ca-org1 \
    --id.name "${EID_ORG1}" --id.secret "${ESECRET_ORG1}" --id.type peer \
    --id.affiliation org1.department1 \
    --url "${CA_ORG1_URL}" \
    --tls.certfiles "${CA_ORG1_TLS}" 2>/dev/null || true

  # Enroll MSP
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer6.org1.example.com/msp" \
    --csr.hosts "peer6.org1.example.com" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org1.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer6.org1.example.com/msp/config.yaml"

  # Enroll TLS
  fabric-ca-client enroll \
    -u "https://${EID_ORG1}:${ESECRET_ORG1}@localhost:7054" \
    --caname ca-org1 \
    -M "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer6.org1.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer6.org1.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG1_TLS}"

  cp "${P6O1_TLS_DIR}/tlscacerts/"* "${P6O1_TLS_DIR}/ca.crt"
  cp "${P6O1_TLS_DIR}/signcerts/"*  "${P6O1_TLS_DIR}/server.crt"
  cp "${P6O1_TLS_DIR}/keystore/"*  "${P6O1_TLS_DIR}/server.key"
}

ensure_peer1_org2_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org2.example.com"
  mkdir -p "${P1O2_TLS_DIR}"

  fabric-ca-client register \
    --caname ca-org2 \
    --id.name "${EID_ORG2}" --id.secret "${ESECRET_ORG2}" --id.type peer \
    --id.affiliation org2.department1 \
    --url "${CA_ORG2_URL}" \
    --tls.certfiles "${CA_ORG2_TLS}" 2>/dev/null || true

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/msp" \
    --csr.hosts "peer1.org2.example.com" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org2.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/msp/config.yaml"

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer1.org2.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${P1O2_TLS_DIR}/tlscacerts/"* "${P1O2_TLS_DIR}/ca.crt"
  cp "${P1O2_TLS_DIR}/signcerts/"*  "${P1O2_TLS_DIR}/server.crt"
  cp "${P1O2_TLS_DIR}/keystore/"*  "${P1O2_TLS_DIR}/server.key"
}
ensure_peer2_org2_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org2.example.com"
  mkdir -p "${P2O2_TLS_DIR}"

  fabric-ca-client register \
    --caname ca-org2 \
    --id.name "${EID_ORG2}" --id.secret "${ESECRET_ORG2}" --id.type peer \
    --id.affiliation org2.department1 \
    --url "${CA_ORG2_URL}" \
    --tls.certfiles "${CA_ORG2_TLS}" 2>/dev/null || true

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer2.org2.example.com/msp" \
    --csr.hosts "peer2.org2.example.com" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org2.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer2.org2.example.com/msp/config.yaml"

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer2.org2.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer2.org2.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${P2O2_TLS_DIR}/tlscacerts/"* "${P2O2_TLS_DIR}/ca.crt"
  cp "${P2O2_TLS_DIR}/signcerts/"*  "${P2O2_TLS_DIR}/server.crt"
  cp "${P2O2_TLS_DIR}/keystore/"*  "${P2O2_TLS_DIR}/server.key"
}


ensure_peer3_org2_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org2.example.com"
  mkdir -p "${P3O2_TLS_DIR}"

  fabric-ca-client register \
    --caname ca-org2 \
    --id.name "${EID_ORG2}" --id.secret "${ESECRET_ORG2}" --id.type peer \
    --id.affiliation org2.department1 \
    --url "${CA_ORG2_URL}" \
    --tls.certfiles "${CA_ORG2_TLS}" 2>/dev/null || true

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer3.org2.example.com/msp" \
    --csr.hosts "peer3.org2.example.com" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org2.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer3.org2.example.com/msp/config.yaml"

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer3.org2.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer3.org2.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${P3O2_TLS_DIR}/tlscacerts/"* "${P3O2_TLS_DIR}/ca.crt"
  cp "${P3O2_TLS_DIR}/signcerts/"*  "${P3O2_TLS_DIR}/server.crt"
  cp "${P3O2_TLS_DIR}/keystore/"*  "${P3O2_TLS_DIR}/server.key"
}

ensure_peer4_org2_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org2.example.com"
  mkdir -p "${P4O2_TLS_DIR}"

  fabric-ca-client register \
    --caname ca-org2 \
    --id.name "${EID_ORG2}" --id.secret "${ESECRET_ORG2}" --id.type peer \
    --id.affiliation org2.department1 \
    --url "${CA_ORG2_URL}" \
    --tls.certfiles "${CA_ORG2_TLS}" 2>/dev/null || true

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer4.org2.example.com/msp" \
    --csr.hosts "peer4.org2.example.com" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org2.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer4.org2.example.com/msp/config.yaml"

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer4.org2.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer4.org2.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${P4O2_TLS_DIR}/tlscacerts/"* "${P4O2_TLS_DIR}/ca.crt"
  cp "${P4O2_TLS_DIR}/signcerts/"*  "${P4O2_TLS_DIR}/server.crt"
  cp "${P4O2_TLS_DIR}/keystore/"*  "${P4O2_TLS_DIR}/server.key"
}

ensure_peer5_org2_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org2.example.com"
  mkdir -p "${P5O2_TLS_DIR}"

  fabric-ca-client register \
    --caname ca-org2 \
    --id.name "${EID_ORG2}" --id.secret "${ESECRET_ORG2}" --id.type peer \
    --id.affiliation org2.department1 \
    --url "${CA_ORG2_URL}" \
    --tls.certfiles "${CA_ORG2_TLS}" 2>/dev/null || true

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer5.org2.example.com/msp" \
    --csr.hosts "peer5.org2.example.com" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org2.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer5.org2.example.com/msp/config.yaml"

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer5.org2.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer5.org2.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${P5O2_TLS_DIR}/tlscacerts/"* "${P5O2_TLS_DIR}/ca.crt"
  cp "${P5O2_TLS_DIR}/signcerts/"*  "${P5O2_TLS_DIR}/server.crt"
  cp "${P5O2_TLS_DIR}/keystore/"*  "${P5O2_TLS_DIR}/server.key"
}

ensure_peer6_org2_material () {
  export FABRIC_CA_CLIENT_HOME="${PWD}/organizations/peerOrganizations/org2.example.com"
  mkdir -p "${P6O2_TLS_DIR}"

  fabric-ca-client register \
    --caname ca-org2 \
    --id.name "${EID_ORG2}" --id.secret "${ESECRET_ORG2}" --id.type peer \
    --id.affiliation org2.department1 \
    --url "${CA_ORG2_URL}" \
    --tls.certfiles "${CA_ORG2_TLS}" 2>/dev/null || true

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer6.org2.example.com/msp" \
    --csr.hosts "peer6.org2.example.com" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${PWD}/organizations/peerOrganizations/org2.example.com/msp/config.yaml" \
     "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer6.org2.example.com/msp/config.yaml"

  fabric-ca-client enroll \
    -u "https://${EID_ORG2}:${ESECRET_ORG2}@localhost:8054" \
    --caname ca-org2 \
    -M "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer6.org2.example.com/tls" \
    --enrollment.profile tls \
    --csr.hosts "peer6.org2.example.com" \
    --csr.hosts "localhost" \
    --tls.certfiles "${CA_ORG2_TLS}"

  cp "${P6O2_TLS_DIR}/tlscacerts/"* "${P6O2_TLS_DIR}/ca.crt"
  cp "${P6O2_TLS_DIR}/signcerts/"*  "${P6O2_TLS_DIR}/server.crt"
  cp "${P6O2_TLS_DIR}/keystore/"*  "${P6O2_TLS_DIR}/server.key"
}


install_if_needed () {
  local MSPID="$1" MSPPATH="$2" ADDR="$3" TLSCRT="$4"
  use_peer_env "${MSPID}" "${MSPPATH}" "${ADDR}" "${TLSCRT}"
  if ! peer lifecycle chaincode queryinstalled 2>/dev/null | grep -q "Label: ${CC_LABEL}"; then
    peer lifecycle chaincode install "${CC_PKG}"
  fi
}

# -------------------- 0) Network up --------------------
./network.sh up createChannel -s couchdb -ca

[ -f "${CA_ORG1_TLS}" ] || die "Missing ${CA_ORG1_TLS}"
[ -f "${CA_ORG2_TLS}" ] || die "Missing ${CA_ORG2_TLS}"

# -------------------- 1) Create peer1 material --------------------
ensure_peer1_org1_material
ensure_peer1_org2_material
ensure_peer2_org1_material
ensure_peer2_org2_material
ensure_peer3_org1_material
ensure_peer3_org2_material
ensure_peer4_org1_material
ensure_peer4_org2_material
ensure_peer5_org1_material
ensure_peer5_org2_material
ensure_peer6_org1_material
ensure_peer6_org2_material

# Bring up the extra peers (compose files must exist)
docker-compose -f docker/docker-compose-peer1org1.yaml up -d
docker-compose -f docker/docker-compose-peer1org2.yaml up -d
docker-compose -f docker/docker-compose-peer2org1.yaml up -d
docker-compose -f docker/docker-compose-peer2org2.yaml up -d
docker-compose -f docker/docker-compose-peer3org1.yaml up -d
docker-compose -f docker/docker-compose-peer3org2.yaml up -d
docker-compose -f docker/docker-compose-peer4org1.yaml up -d
docker-compose -f docker/docker-compose-peer4org2.yaml up -d
docker-compose -f docker/docker-compose-peer5org1.yaml up -d
docker-compose -f docker/docker-compose-peer5org2.yaml up -d
docker-compose -f docker/docker-compose-peer6org1.yaml up -d
docker-compose -f docker/docker-compose-peer6org2.yaml up -d

# -------------------- 2) Package CC --------------------
if [ ! -f "${CC_PKG}" ]; then
  peer lifecycle chaincode package "${CC_PKG}" \
    --path "${CC_SRC_PATH}" --lang "${CC_LANG}" --label "${CC_LABEL}"
fi

# -------------------- 3) Join all peers --------------------
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P0O1_ADDR}" "${P0O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P1O1_ADDR}" "${P1O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P2O1_ADDR}" "${P2O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P3O1_ADDR}" "${P3O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P4O1_ADDR}" "${P4O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P5O1_ADDR}" "${P5O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P6O1_ADDR}" "${P6O1_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P0O2_ADDR}" "${P0O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P1O2_ADDR}" "${P1O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P2O2_ADDR}" "${P2O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P3O2_ADDR}" "${P3O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P4O2_ADDR}" "${P4O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P5O2_ADDR}" "${P5O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P6O2_ADDR}" "${P6O2_TLS}"


# -------------------- 4) Install on all peers --------------------
# Org1
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P0O1_ADDR}" "${P0O1_TLS}"
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P1O1_ADDR}" "${P1O1_TLS}"
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P2O1_ADDR}" "${P2O1_TLS}"
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P3O1_ADDR}" "${P3O1_TLS}"
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P4O1_ADDR}" "${P4O1_TLS}"
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P5O1_ADDR}" "${P5O1_TLS}"
install_if_needed "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P6O1_ADDR}" "${P6O1_TLS}"
# Org2
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P0O2_ADDR}" "${P0O2_TLS}"
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P1O2_ADDR}" "${P1O2_TLS}"
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P2O2_ADDR}" "${P2O2_TLS}"
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P3O2_ADDR}" "${P3O2_TLS}"
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P4O2_ADDR}" "${P4O2_TLS}"
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P5O2_ADDR}" "${P5O2_TLS}"
install_if_needed "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P6O2_ADDR}" "${P6O2_TLS}"


# -------------------- 5) Approve + commit --------------------
use_peer_env "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P0O1_ADDR}" "${P0O1_TLS}"
CC_PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | sed -n "s/^Package ID: \(.*\), Label: ${CC_LABEL}\$/\1/p")
[ -n "${CC_PACKAGE_ID}" ] || die "Could not detect CC package ID"

peer lifecycle chaincode approveformyorg -o "${ORDERER_ADDR}" --ordererTLSHostnameOverride orderer.example.com \
  --channelID "${CHANNEL_NAME}" --name "${CC_NAME}" --version "${CC_VERSION}" --package-id "${CC_PACKAGE_ID}" \
  --sequence 1 --tls --cafile "${ORDERER_TLS_CA}"

use_peer_env "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P0O2_ADDR}" "${P0O2_TLS}"
peer lifecycle chaincode approveformyorg -o "${ORDERER_ADDR}" --ordererTLSHostnameOverride orderer.example.com \
  --channelID "${CHANNEL_NAME}" --name "${CC_NAME}" --version "${CC_VERSION}" --package-id "${CC_PACKAGE_ID}" \
  --sequence 1 --tls --cafile "${ORDERER_TLS_CA}"

use_peer_env "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P0O1_ADDR}" "${P0O1_TLS}"
if ! peer lifecycle chaincode querycommitted -C "${CHANNEL_NAME}" --name "${CC_NAME}" >/dev/null 2>&1; then
  peer lifecycle chaincode commit -o "${ORDERER_ADDR}" --ordererTLSHostnameOverride orderer.example.com \
    --channelID "${CHANNEL_NAME}" --name "${CC_NAME}" --version "${CC_VERSION}" --sequence 1 \
    --tls --cafile "${ORDERER_TLS_CA}" \
    --peerAddresses "${P0O1_ADDR}" --tlsRootCertFiles "${P0O1_TLS}" \
    --peerAddresses "${P0O2_ADDR}" --tlsRootCertFiles "${P0O2_TLS}"
fi

echo "✅ Chaincode committed:"
echo "Warming up chaincode containers on all peers..."
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:7051" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:8051" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt"
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1051" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/ca.crt"
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1151" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer3.org1.example.com/tls/ca.crt"
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1251" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer4.org1.example.com/tls/ca.crt"
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1351" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer5.org1.example.com/tls/ca.crt"
warmup_peer "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1451" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer6.org1.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:9051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:6051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer2.org2.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2151" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer3.org2.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2251" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer4.org2.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2351" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer5.org2.example.com/tls/ca.crt"
warmup_peer "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2451" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer6.org2.example.com/tls/ca.crt"

peer lifecycle chaincode querycommitted -C "${CHANNEL_NAME}" --name "${CC_NAME}"

# -------------------- 6) Final verify --------------------
echo "-------------------------------------------------------------"
echo "Verifying peers on ${CHANNEL_NAME}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P0O1_ADDR}" "${P0O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P1O1_ADDR}" "${P1O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P2O1_ADDR}" "${P2O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P3O1_ADDR}" "${P3O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P4O1_ADDR}" "${P4O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P5O1_ADDR}" "${P5O1_TLS}"
check_peer_joined "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P6O1_ADDR}" "${P6O1_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P0O2_ADDR}" "${P0O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P1O2_ADDR}" "${P1O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P2O2_ADDR}" "${P2O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P3O2_ADDR}" "${P3O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P4O2_ADDR}" "${P4O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P5O2_ADDR}" "${P5O2_TLS}"
check_peer_joined "${ORG2_MSP}" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "${P6O2_ADDR}" "${P6O2_TLS}"
echo "-------------------------------------------------------------"
echo "✅ All peers verified and joined."

# -------------------- 7) Write reusable CLI env for manual checks --------------------
cat > ./cli-env.sh <<'EOF'
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
peer2org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1051" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer2.org1.example.com/tls/ca.crt"; }
peer3org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1151" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer3.org1.example.com/tls/ca.crt"; }
peer4org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1251" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer4.org1.example.com/tls/ca.crt"; }
peer5org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1351" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer5.org1.example.com/tls/ca.crt"; }
peer6org1() { use_peer_env "Org1MSP" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "localhost:1451" "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer6.org1.example.com/tls/ca.crt"; }
peer0org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:9051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"; }
peer1org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:6051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt"; }
peer2org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2051" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer2.org2.example.com/tls/ca.crt"; }
peer3org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2151" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer3.org2.example.com/tls/ca.crt"; }
peer4org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2251" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer4.org2.example.com/tls/ca.crt"; }
peer5org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2351" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer5.org2.example.com/tls/ca.crt"; }
peer6org2() { use_peer_env "Org2MSP" "${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" "localhost:2451" "${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer6.org2.example.com/tls/ca.crt"; }
# Orderer TLS
export ORDERER_TLS_CA="${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
EOF
chmod +x ./cli-env.sh
echo "✅ Wrote ./cli-env.sh (run: 'source ./cli-env.sh')"

# -------------------- 8) Smoke test: invoke + query fabcar --------------------
echo "Running a small end-to-end check (invoke + query)..."
use_peer_env "${ORG1_MSP}" "${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" "${P0O1_ADDR}" "${P0O1_TLS}"

# Create a car (endorsed by both orgs' anchor peers)
peer chaincode invoke -o "${ORDERER_ADDR}" --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "${ORDERER_TLS_CA}" \
  -C "${CHANNEL_NAME}" -n "${CC_NAME}" \
  --peerAddresses "${P0O1_ADDR}" --tlsRootCertFiles "${P0O1_TLS}" \
  --peerAddresses "${P0O2_ADDR}" --tlsRootCertFiles "${P0O2_TLS}" \
  -c '{"Args":["createCar","CARa101","Toyotaa","Priuss","bluee","Toram"]}'

# Give commit a moment and query from each peer to ensure state is visible
sleep 2
for p in "${P0O1_ADDR},${P0O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P1O1_ADDR},${P1O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P2O1_ADDR},${P2O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P3O1_ADDR},${P3O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P4O1_ADDR},${P4O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P5O1_ADDR},${P5O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P6O1_ADDR},${P6O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P0O2_ADDR},${P0O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P1O2_ADDR},${P1O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P2O2_ADDR},${P2O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P3O2_ADDR},${P3O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P4O2_ADDR},${P4O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P5O2_ADDR},${P5O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P6O2_ADDR},${P6O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
do
  IFS=, read ADDR TLSCRT MSPID MSPPATH <<<"$p"
  use_peer_env "${MSPID}" "${MSPPATH}" "${ADDR}" "${TLSCRT}"
  echo "Querying CAR10 on ${ADDR} ..."
  peer chaincode query -C "${CHANNEL_NAME}" -n "${CC_NAME}" -c '{"Args":["queryCar","CAR10"]}'
done

# Also show channel height from each peer:
for p in "${P0O1_ADDR},${P0O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P1O1_ADDR},${P1O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P2O1_ADDR},${P2O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P3O1_ADDR},${P3O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P4O1_ADDR},${P4O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P5O1_ADDR},${P5O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P6O1_ADDR},${P6O1_TLS},${ORG1_MSP},${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp" \
         "${P0O2_ADDR},${P0O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P1O2_ADDR},${P1O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P2O2_ADDR},${P2O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P3O2_ADDR},${P3O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P4O2_ADDR},${P4O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P5O2_ADDR},${P5O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp" \
         "${P6O2_ADDR},${P6O2_TLS},${ORG2_MSP},${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp"
do
  IFS=, read ADDR TLSCRT MSPID MSPPATH <<<"$p"
  use_peer_env "${MSPID}" "${MSPPATH}" "${ADDR}" "${TLSCRT}"
  printf "getinfo @ %s -> " "${ADDR}"
  peer channel getinfo -c "${CHANNEL_NAME}"
done
echo "✅ End-to-end check complete."
