#!/usr/bin/env bash
# =============================================================================
# run.sh - Run the whole FoodTrace DApp demo with one command.
#
# Author: Andre Luiz Oliveira da Cunha (2024214)
#
# Steps:
#   1. Check that Python and the required libraries are installed
#   2. Check that Ganache is running (and explain how to start it if not)
#   3. Compile and deploy the contract      (scripts/deploy.py)
#   4. Simulate the full supply chain flow  (scripts/interact.py)
#
# Usage (from the project folder, in Git Bash, WSL, macOS or Linux):
#   bash scripts/run.sh
#
# Ganache must be running in another terminal:
#   ganache --wallet.deterministic --wallet.totalAccounts 5 --chain.chainId 1337
# =============================================================================

# Stop the script at the first error (-e), on undefined variables (-u)
# and if any command in a pipe fails (-o pipefail).
set -euo pipefail

GANACHE_URL="http://127.0.0.1:8545"

# Go to the project root (the folder above scripts/), so the script works
# no matter where it is called from.
cd "$(dirname "$0")/.."

echo "============================================================"
echo " FoodTrace DApp - automated run"
echo "============================================================"

# -----------------------------------------------------------------------------
# 1. Find Python. On Windows it is usually "python", on Mac/Linux "python3".
# -----------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON=python
else
    echo "[ERROR] Python not found. Install Python 3 first."
    exit 1
fi
echo "[OK] Using $($PYTHON --version)"

# Check the libraries; install them if they are missing.
if ! $PYTHON -c "import web3, solcx" >/dev/null 2>&1; then
    echo "[..] Installing web3 and py-solc-x"
    $PYTHON -m pip install web3 py-solc-x
fi
echo "[OK] web3 and py-solc-x installed"

# -----------------------------------------------------------------------------
# 2. Check that Ganache answers. eth_chainId is a simple JSON-RPC request:
#    if Ganache is running it returns the chain id, otherwise curl fails.
# -----------------------------------------------------------------------------
if ! curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        "$GANACHE_URL" >/dev/null; then
    echo "[ERROR] Ganache is not running at $GANACHE_URL"
    echo "        Start it in another terminal with:"
    echo "        ganache --wallet.deterministic --wallet.totalAccounts 5 --chain.chainId 1337"
    exit 1
fi
echo "[OK] Ganache is running at $GANACHE_URL"

# -----------------------------------------------------------------------------
# 3. Compile and deploy the contract.
# -----------------------------------------------------------------------------
echo
$PYTHON scripts/deploy.py

# -----------------------------------------------------------------------------
# 4. Run the supply chain simulation on the new contract.
# -----------------------------------------------------------------------------
echo
$PYTHON scripts/interact.py

echo
echo "[DONE] Deploy and simulation completed."
