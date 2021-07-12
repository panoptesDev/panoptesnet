#!/usr/bin/env bash

here=$(dirname "$0")
# shellcheck source=multinode-demo/common.sh
source "$here"/common.sh

set -e

rm -rf "$PANOPTES_CONFIG_DIR"/latest-testnet-snapshot
mkdir -p "$PANOPTES_CONFIG_DIR"/latest-testnet-snapshot
(
  cd "$PANOPTES_CONFIG_DIR"/latest-testnet-snapshot || exit 1
  set -x
  wget http://api.testnet.solana.com/genesis.tar.bz2
  wget --trust-server-names http://testnet.solana.com/snapshot.tar.bz2
)

snapshot=$(ls "$PANOPTES_CONFIG_DIR"/latest-testnet-snapshot/snapshot-[0-9]*-*.tar.zst)
if [[ -z $snapshot ]]; then
  echo Error: Unable to find latest snapshot
  exit 1
fi

if [[ ! $snapshot =~ snapshot-([0-9]*)-.*.tar.zst ]]; then
  echo Error: Unable to determine snapshot slot for "$snapshot"
  exit 1
fi

snapshot_slot="${BASH_REMATCH[1]}"

rm -rf "$PANOPTES_CONFIG_DIR"/bootstrap-validator
mkdir -p "$PANOPTES_CONFIG_DIR"/bootstrap-validator


# Create genesis ledger
if [[ -r $FAUCET_KEYPAIR ]]; then
  cp -f "$FAUCET_KEYPAIR" "$PANOPTES_CONFIG_DIR"/faucet.json
else
  $panoptes_keygen new --no-passphrase -fso "$PANOPTES_CONFIG_DIR"/faucet.json
fi

if [[ -f $BOOTSTRAP_VALIDATOR_IDENTITY_KEYPAIR ]]; then
  cp -f "$BOOTSTRAP_VALIDATOR_IDENTITY_KEYPAIR" "$PANOPTES_CONFIG_DIR"/bootstrap-validator/identity.json
else
  $panoptes_keygen new --no-passphrase -so "$PANOPTES_CONFIG_DIR"/bootstrap-validator/identity.json
fi

$panoptes_keygen new --no-passphrase -so "$PANOPTES_CONFIG_DIR"/bootstrap-validator/vote-account.json
$panoptes_keygen new --no-passphrase -so "$PANOPTES_CONFIG_DIR"/bootstrap-validator/stake-account.json

$panoptes_ledger_tool create-snapshot \
  --ledger "$PANOPTES_CONFIG_DIR"/latest-testnet-snapshot \
  --faucet-pubkey "$PANOPTES_CONFIG_DIR"/faucet.json \
  --faucet-lamports 500000000000000000 \
  --bootstrap-validator "$PANOPTES_CONFIG_DIR"/bootstrap-validator/identity.json \
                        "$PANOPTES_CONFIG_DIR"/bootstrap-validator/vote-account.json \
                        "$PANOPTES_CONFIG_DIR"/bootstrap-validator/stake-account.json \
  --hashes-per-tick sleep \
  "$snapshot_slot" "$PANOPTES_CONFIG_DIR"/bootstrap-validator

$panoptes_ledger_tool modify-genesis \
  --ledger "$PANOPTES_CONFIG_DIR"/latest-testnet-snapshot \
  --hashes-per-tick sleep \
  "$PANOPTES_CONFIG_DIR"/bootstrap-validator
