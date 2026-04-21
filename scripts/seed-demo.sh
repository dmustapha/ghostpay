#!/usr/bin/env bash
# File: scripts/seed-demo.sh
# DEV-004: Must use minitiad tx evm call (not viem/cast send)
# DEV-008: Pre-fund contract via cosmos bank send, then createStream with explicit amount
# DEV-007: All contracts on Settlement
set -euo pipefail
export PATH="${HOME}/.foundry/bin:$PATH"

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/.env"

LOG_FILE="${PROJECT_DIR}/seed-demo.log"
: > "$LOG_FILE"  # reset log each run

MINITIAD="${MINITIAD_PATH:-${HOME}/.weave/data/minievm@v1.2.15/minitiad}"
HOME_DIR="${MINITIA_HOME:-${HOME}/.minitia}"
KEYRING_BACKEND="test"
CHAIN_ID="${SETTLEMENT_CHAIN_ID:-ghostpay-1}"

# NOTE: minitiad keyring uses coin_type 118 derivation, which gives different address
# than coin_type 60 (EVM). The keyring's "deployer" key is the one we can sign with.
SENDER_EVM="0x81817d76D7C31029786a4F643D4e0739A0e8e1eB"
SENDER_BECH32="init1sxqh6akhcvgzj7r2fajr6ns88xsw3c0tzczhec"
SENDER_KEY_NAME="deployer"  # minitiad keyring name
STREAM_SENDER="${STREAM_SENDER_ADDRESS}"
STREAM_SENDER_COSMOS="init1nxphp7gkrh7952v6un498z7zpltx6ytwra7xpv"
STREAM_RECEIVER="${STREAM_RECEIVER_ADDRESS}"
STREAM_RECEIVER_COSMOS="init15km372yem4hftjqsq0f7w6gms38u2ylmguzmww"
DENOM="${STREAM_DENOM:-umin}"

# Demo parameters
STREAM_AMOUNT=2000000    # 2 MIN (2,000,000 umin)
STREAM_DURATION=600      # 10 minutes
FUND_AMOUNT=2500000      # 2.5 MIN — extra headroom for gas

echo "=== GhostPay Demo Seed ==="
echo "Chain:           $CHAIN_ID"
echo "Sender (EVM):    $SENDER_EVM"
echo "Sender (Bech32): $SENDER_BECH32"
echo "StreamSender:    $STREAM_SENDER ($STREAM_SENDER_COSMOS)"
echo "StreamReceiver:  $STREAM_RECEIVER ($STREAM_RECEIVER_COSMOS)"
echo "Amount:          $STREAM_AMOUNT $DENOM ($((STREAM_AMOUNT / 1000000)) MIN)"
echo "Duration:        ${STREAM_DURATION}s"
echo ""

# --- Step 1: Check deployer balance ---
echo "--- Step 1: Check deployer balance ---"
BALANCE=$($MINITIAD query bank balances "$SENDER_BECH32" \
  --home "$HOME_DIR" --output json 2>>"$LOG_FILE" | \
  python3 -c "import sys,json; balances=json.load(sys.stdin).get('balances',[]); print(next((b['amount'] for b in balances if b['denom']=='$DENOM'), '0'))")
echo "Deployer balance: ${BALANCE:-0} $DENOM ($((${BALANCE:-0} / 1000000)) MIN)"

if [ "${BALANCE:-0}" -lt "$FUND_AMOUNT" ]; then
  echo "ERROR: Insufficient balance. Need at least $FUND_AMOUNT $DENOM, have ${BALANCE:-0}"
  exit 1
fi

# --- Step 2: Fund StreamSender contract (DEV-008: pre-fund via cosmos bank send) ---
echo ""
echo "--- Step 2: Fund StreamSender contract with ${FUND_AMOUNT} $DENOM ---"
FUND_TX=$($MINITIAD tx bank send "$SENDER_KEY_NAME" "$STREAM_SENDER_COSMOS" "${FUND_AMOUNT}${DENOM}" \
  --home "$HOME_DIR" \
  --keyring-backend "$KEYRING_BACKEND" \
  --chain-id "$CHAIN_ID" \
  --gas 500000 \
  --fees "1${DENOM}" \
  --yes --output json 2>>"$LOG_FILE")
FUND_CODE=$(echo "$FUND_TX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))")
FUND_HASH=$(echo "$FUND_TX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('txhash', 'unknown'))")
echo "Fund tx: $FUND_HASH (code: $FUND_CODE)"

if [ "$FUND_CODE" != "0" ]; then
  echo "WARNING: Fund tx broadcast code=$FUND_CODE — checking on-chain..."
fi
sleep 3

# Verify contract got funded
CONTRACT_BAL=$($MINITIAD query bank balances "$STREAM_SENDER_COSMOS" \
  --home "$HOME_DIR" --output json 2>>"$LOG_FILE" | \
  python3 -c "import sys,json; balances=json.load(sys.stdin).get('balances',[]); print(next((b['amount'] for b in balances if b['denom']=='$DENOM'), '0'))")
echo "StreamSender balance: ${CONTRACT_BAL} $DENOM"

# --- Step 3: Create demo stream via minitiad tx evm call ---
echo ""
echo "--- Step 3: Create demo stream ---"
# createStream(string senderCosmos, string receiver, string destChannel, uint256 amount, uint256 durationSeconds)
FULL_CALLDATA=$(cast calldata "createStream(string,string,string,uint256,uint256)" \
  "$SENDER_BECH32" \
  "$STREAM_RECEIVER_COSMOS" \
  "channel-0" \
  "$STREAM_AMOUNT" \
  "$STREAM_DURATION")

echo "Calldata: ${FULL_CALLDATA:0:20}...${FULL_CALLDATA: -20}"

CREATE_TX=$($MINITIAD tx evm call "$STREAM_SENDER" "$FULL_CALLDATA" \
  --from "$SENDER_KEY_NAME" \
  --home "$HOME_DIR" \
  --keyring-backend "$KEYRING_BACKEND" \
  --chain-id "$CHAIN_ID" \
  --gas 500000 \
  --fees "1${DENOM}" \
  --yes --output json 2>>"$LOG_FILE")
CREATE_CODE=$(echo "$CREATE_TX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))")
CREATE_HASH=$(echo "$CREATE_TX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('txhash', 'unknown'))")
echo "CreateStream tx: $CREATE_HASH (code: $CREATE_CODE)"

if [ "$CREATE_CODE" != "0" ]; then
  echo "WARNING: CreateStream broadcast code=$CREATE_CODE — checking on-chain..."
fi
sleep 3

# --- Step 3b: Send first tick (DEV-010: needs 2M gas) ---
echo ""
echo "--- Step 3b: Send first tick ---"
# Get the latest stream ID
LATEST_STREAM=$(cast call "$STREAM_SENDER" "getSenderStreams(address)(bytes32[])" "$SENDER_EVM" \
  --rpc-url http://localhost:8545 2>>"$LOG_FILE" | python3 -c "
import sys, re
data = sys.stdin.read().strip()
# Extract last hex value from array output like [0xabc, 0xdef]
matches = re.findall(r'0x[0-9a-fA-F]+', data)
print(matches[-1] if matches else '')
")
echo "Latest stream: $LATEST_STREAM"

if [ -n "$LATEST_STREAM" ]; then
  TICK_CALLDATA=$(cast calldata "sendTick(bytes32)" "$LATEST_STREAM")
  TICK_TX=$($MINITIAD tx evm call "$STREAM_SENDER" "$TICK_CALLDATA" \
    --from "$SENDER_KEY_NAME" \
    --home "$HOME_DIR" \
    --keyring-backend "$KEYRING_BACKEND" \
    --chain-id "$CHAIN_ID" \
    --gas 2000000 \
    --fees 1${DENOM} \
    --yes --output json 2>>"$LOG_FILE")
  TICK_CODE=$(echo "$TICK_TX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code', -1))")
  TICK_HASH=$(echo "$TICK_TX" | python3 -c "import sys,json; print(json.load(sys.stdin).get('txhash', 'unknown'))")
  echo "Tick tx: $TICK_HASH (code: $TICK_CODE)"
  sleep 3
fi

# --- Step 4: Verify stream exists ---
echo ""
echo "--- Step 4: Verify stream state ---"
# getSenderStreams(address) returns bytes32[]
STREAMS_DATA=$(cast call "$STREAM_SENDER" "getSenderStreams(address)(bytes32[])" "$SENDER_EVM" \
  --rpc-url http://localhost:8545 2>>"$LOG_FILE" || echo "QUERY_FAILED")

if [ "$STREAMS_DATA" = "QUERY_FAILED" ]; then
  echo "WARNING: Could not query streams via cast call — checking via minitiad..."
  STREAMS_DATA=$($MINITIAD query evm call --sender "$SENDER_BECH32" \
    "$STREAM_SENDER" \
    "$(cast sig 'getSenderStreams(address)')$(cast abi-encode 'getSenderStreams(address)' "$SENDER_EVM" | cut -c 3-)" \
    --home "$HOME_DIR" --output json 2>>"$LOG_FILE" || echo "{}")
fi

echo "Sender streams: $STREAMS_DATA"

# --- Step 5: Update .env with demo addresses ---
echo ""
echo "--- Step 5: Update .env demo addresses ---"
# Only update if not already set
if ! grep -q "VITE_DEMO_SENDER_ADDRESS=$SENDER_EVM" "$PROJECT_DIR/.env" 2>>"$LOG_FILE"; then
  sed -i '' "s|^VITE_DEMO_SENDER_ADDRESS=.*|VITE_DEMO_SENDER_ADDRESS=$SENDER_EVM|" "$PROJECT_DIR/.env"
  echo "Updated VITE_DEMO_SENDER_ADDRESS=$SENDER_EVM"
fi
if ! grep -q "VITE_DEMO_RECEIVER_ADDRESS=$STREAM_RECEIVER" "$PROJECT_DIR/.env" 2>>"$LOG_FILE"; then
  sed -i '' "s|^VITE_DEMO_RECEIVER_ADDRESS=.*|VITE_DEMO_RECEIVER_ADDRESS=$STREAM_RECEIVER|" "$PROJECT_DIR/.env"
  echo "Updated VITE_DEMO_RECEIVER_ADDRESS=$STREAM_RECEIVER"
fi

echo ""
echo "=== Seed Complete ==="
echo "Pre-seeded state:"
echo "  - 1 active stream: $((STREAM_AMOUNT / 1000000)) MIN over ${STREAM_DURATION}s"
echo "  - Sender:         $SENDER_EVM ($SENDER_BECH32)"
echo "  - Receiver:       $STREAM_RECEIVER_COSMOS"
echo "  - StreamSender:   $STREAM_SENDER"
echo "  - Fund tx:        $FUND_HASH"
echo "  - Create tx:      $CREATE_HASH"
