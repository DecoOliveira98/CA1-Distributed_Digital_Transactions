"""
deploy.py - Compile FoodTrace.sol and deploy it to the local Ganache blockchain.

Author: Andre Luiz Oliveira da Cunha (2024214)

What this script does (the same steps done by hand in Remix):
  1. Connects to Ganache (http://127.0.0.1:8545) using web3.py
  2. Compiles contracts/FoodTrace.sol with the Solidity compiler (py-solc-x)
  3. Deploys the contract from account 0, which becomes the consortium admin
  4. Saves the contract address and ABI to build/FoodTrace.json,
     so interact.py can talk to the deployed contract

Usage (Ganache must be running first, in another terminal):
  python scripts/deploy.py
"""

# ============================================================================
# IMPORTS
# ============================================================================

import json  # to save the address + ABI in a .json file
import sys  # sys.exit() stops the script with an error message
from pathlib import Path  # builds file paths that work on Windows, Mac and Linux

# packaging.Version compares version numbers correctly ("0.8.24" > "0.8.9").
from packaging.version import Version

# py-solc-x: a Python wrapper around "solc", the official Solidity compiler.
# It is the same compiler Remix runs in the "Solidity Compiler" tab.
from solcx import compile_standard, get_installed_solc_versions, install_solc

# web3.py: the Python library that talks to an Ethereum node (here, Ganache).
# Every action (deploy, transaction, read) is a JSON-RPC request to the node.
from web3 import Web3

# ============================================================================
# SETTINGS
# ============================================================================

# Address of the Ganache RPC server. Remix's "Dev - Ganache Provider" uses
# this same address.
GANACHE_URL = "http://127.0.0.1:8545"

# Compiler version. The contract says "pragma solidity ^0.8.20", which accepts
# any 0.8.x version from 0.8.20 upwards, so 0.8.24 is allowed.
SOLC_VERSION = "0.8.24"

# EVM version = which set of opcodes the bytecode may use. It must match
# Ganache's hardfork ("Hardfork: shanghai" in the Ganache startup log),
# otherwise the deploy can fail with "invalid opcode". This is the same
# setting changed in Remix under "Advanced Configurations".
EVM_VERSION = "shanghai"

# __file__ is this script. .parent is "scripts/" and .parent.parent is the
# project root, so the paths below work no matter which folder you run from.
ROOT = Path(__file__).resolve().parent.parent
CONTRACT_FILE = ROOT / "contracts" / "FoodTrace.sol"
BUILD_DIR = ROOT / "build"  # generated files (ignored by .gitignore)
OUTPUT_FILE = BUILD_DIR / "FoodTrace.json"


# ============================================================================
# STEP 1 - CONNECT TO THE BLOCKCHAIN
# ============================================================================

def connect() -> Web3:
    """Connect to Ganache and stop with a clear message if it is not running."""
    # HTTPProvider sends JSON-RPC requests to Ganache over HTTP.
    w3 = Web3(Web3.HTTPProvider(GANACHE_URL))

    # is_connected() returns False if nothing answers at that address.
    if not w3.is_connected():
        sys.exit(f"[ERROR] Cannot connect to Ganache at {GANACHE_URL}. "
                 "Start it first with:\n  ganache --wallet.deterministic "
                 "--wallet.totalAccounts 5 --chain.chainId 1337")

    # chain_id identifies the network (1337 = our local Ganache chain).
    # It is part of every signed transaction, so a transaction signed for one
    # network cannot be replayed on another one.
    print(f"[OK] Connected to Ganache (chain id {w3.eth.chain_id})")
    return w3


# ============================================================================
# STEP 2 - COMPILE THE CONTRACT
# ============================================================================

def compile_contract() -> tuple[list, str]:
    """Compile FoodTrace.sol and return its ABI and bytecode."""
    # The compiler is a separate program. Download it only the first time
    # (needs internet once); after that it is reused from the local cache.
    if Version(SOLC_VERSION) not in get_installed_solc_versions():
        print(f"[..] Downloading solc {SOLC_VERSION} (first run only)")
        install_solc(SOLC_VERSION)

    # Read the Solidity source code as text.
    source = CONTRACT_FILE.read_text(encoding="utf-8")

    # compile_standard() uses the compiler's "Standard JSON" input format,
    # which is the same format Remix uses internally.
    compiled = compile_standard(
        {
            "language": "Solidity",
            "sources": {"FoodTrace.sol": {"content": source}},
            "settings": {
                "evmVersion": EVM_VERSION,
                # The optimizer makes the bytecode cheaper to run (less gas).
                # "runs: 200" = optimise for a contract called often.
                "optimizer": {"enabled": True, "runs": 200},
                # Ask the compiler only for what we need: ABI and bytecode.
                "outputSelection": {
                    "*": {"*": ["abi", "evm.bytecode.object"]}
                },
            },
        },
        solc_version=SOLC_VERSION,
    )

    # The result is a nested dictionary: contracts -> file -> contract name.
    contract = compiled["contracts"]["FoodTrace.sol"]["FoodTrace"]

    # ABI (Application Binary Interface): a JSON list describing every
    # function, parameter and event. web3.py needs it to know how to encode
    # calls to the contract and decode its answers (like an API contract).
    abi = contract["abi"]

    # Bytecode: the compiled machine code that will run on the EVM
    # (Ethereum Virtual Machine). It is a hex string, so 2 characters = 1 byte.
    bytecode = contract["evm"]["bytecode"]["object"]

    print(f"[OK] Compiled FoodTrace.sol ({len(bytecode) // 2} bytes of bytecode)")
    return abi, bytecode


# ============================================================================
# STEP 3 - DEPLOY THE CONTRACT
# ============================================================================

def deploy(w3: Web3, abi: list, bytecode: str) -> str:
    """Deploy the contract from account 0 and return its address."""
    # Ganache creates test accounts that are already "unlocked": it holds
    # their private keys, so it can sign transactions for them. Account 0
    # deploys the contract, so the constructor makes it the admin
    # (admin = msg.sender).
    admin = w3.eth.accounts[0]

    # A contract "factory": it knows the ABI and bytecode but is not on the
    # blockchain yet.
    FoodTrace = w3.eth.contract(abi=abi, bytecode=bytecode)

    # constructor().transact() sends a deploy transaction: a transaction with
    # no "to" address whose data is the bytecode. Ganache signs it with
    # account 0's private key (ECDSA secp256k1) and returns its hash.
    tx_hash = FoodTrace.constructor().transact({"from": admin})

    # Wait until the transaction is mined into a block. The receipt is the
    # proof that it was included, with the new contract's address.
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    print(f"[OK] Deployed by admin {admin}")
    # The contract address is derived from the deployer's address and nonce
    # (Keccak-256 hash), so it is unique.
    print(f"     Contract address : {receipt.contractAddress}")
    # The transaction hash is the Keccak-256 hash of the signed transaction:
    # its unique, tamper-proof ID on the blockchain.
    print(f"     Transaction hash : {w3.to_hex(tx_hash)}")
    print(f"     Block number     : {receipt.blockNumber}")
    # Gas = the computational cost of the deploy. Deploying is the most
    # expensive operation because the whole bytecode is stored on-chain.
    print(f"     Gas used         : {receipt.gasUsed}")
    return receipt.contractAddress


# ============================================================================
# STEP 4 - SAVE THE RESULT
# ============================================================================

def save(address: str, abi: list, w3: Web3) -> None:
    """Save the address and ABI so interact.py can use the deployed contract."""
    # Create build/ if it does not exist yet.
    BUILD_DIR.mkdir(exist_ok=True)

    # To use a deployed contract you need two things: WHERE it is (address)
    # and HOW to talk to it (ABI). Saving both lets interact.py work
    # without compiling again.
    OUTPUT_FILE.write_text(
        json.dumps({"address": address, "chainId": w3.eth.chain_id, "abi": abi},
                   indent=2),
        encoding="utf-8",
    )
    print(f"[OK] Saved address and ABI to {OUTPUT_FILE.relative_to(ROOT)}")


# ============================================================================
# MAIN
# ============================================================================

# This block only runs when the file is executed directly
# (python scripts/deploy.py), not when it is imported by another script.
if __name__ == "__main__":
    print("=" * 60)
    print(" FoodTrace - Deploy")
    print("=" * 60)
    w3 = connect()
    abi, bytecode = compile_contract()
    address = deploy(w3, abi, bytecode)
    save(address, abi, w3)
