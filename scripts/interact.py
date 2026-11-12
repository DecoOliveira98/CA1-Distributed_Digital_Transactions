"""
interact.py - Runs the full FoodTrace supply chain flow on Ganache.
Author: Andre Luiz Oliveira da Cunha (2024214)

Run deploy.py first, then: python scripts/interact.py
"""

import json
from importlib import import_module
from pathlib import Path

try:
    Web3 = import_module("web3").Web3
except ModuleNotFoundError as error:
    if error.name == "web3":
        raise SystemExit("Missing dependency: install it with `python -m pip install web3`.") from error
    raise

# Load the address and ABI saved by deploy.py
build = json.loads((Path(__file__).parent.parent / "build" / "FoodTrace.json").read_text())

w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
contract = w3.eth.contract(address=build["address"], abi=build["abi"])
fn = contract.functions

# One Ganache account per actor (account 0 deployed the contract, so it is the admin)
admin, farmer, processor, distributor, retailer = list(w3.eth.accounts)[:5]
STATUS = ["Created", "Processed", "InTransit", "Delivered", "Sold", "Recalled"]


def send(function, sender, message):
    """Send a transaction signed by 'sender' and wait until it is mined."""
    tx = function.transact({"from": sender})
    receipt = w3.eth.wait_for_transaction_receipt(tx)
    print(f"[OK] {message} (block {receipt['blockNumber']}, gas {receipt['gasUsed']})")


def must_fail(function, sender, message):
    """Try an action the contract should reject and print the reason."""
    try:
        function.call({"from": sender})  # simulate only, no gas spent
        print(f"[!!] NOT blocked: {message}")
    except Exception as error:
        reason = str(error).split("revert ")[-1].split("'")[0]
        print(f"[BLOCKED] {message} -> {reason}")


print("\n--- 1. Admin registers the participants ---")
for account, name, role in [(farmer, "Green Farm", 1), (processor, "Fresh Process Ltd", 2),
                            (distributor, "IrishLogistics", 3), (retailer, "Dublin Supermarket", 4)]:
    if not fn.participants(account).call()[2]:  # skip if already registered
        send(fn.registerParticipant(account, name, role), admin, f"Registered {name}")

print("\n--- 2. Farmer creates a batch ---")
certificate = "Organic certificate - Green Farm - Tomatoes - Nov 2026"
cert_hash = w3.keccak(text=certificate)  # only the Keccak-256 hash goes on-chain
print(f"Certificate hash: {w3.to_hex(cert_hash)}")
send(fn.createBatch("Organic Tomatoes", "Wexford, Ireland", 500, cert_hash), farmer, "Batch created")
batch_id = fn.batchCount().call()

print("\n--- 3. Batch moves along the chain (sender -> receiver) ---")
send(fn.transferBatch(batch_id, processor, "Wexford Farm"), farmer, "Farmer -> Processor")
send(fn.updateStatus(batch_id, 1), processor, "Status: Processed")
send(fn.transferBatch(batch_id, distributor, "Dublin Plant"), processor, "Processor -> Distributor")
send(fn.addCheckpoint(batch_id, "M50 Dublin", 4), distributor, "Checkpoint 4 C (safe)")
send(fn.addCheckpoint(batch_id, "Dublin Port", 12), distributor, "Checkpoint 12 C (ALERT, above 8 C)")
send(fn.transferBatch(batch_id, retailer, "Dublin Store"), distributor, "Distributor -> Retailer")
send(fn.updateStatus(batch_id, 4), retailer, "Status: Sold")

print("\n--- 4. Consumer view (free read-only calls) ---")
batch = fn.getBatch(batch_id).call()
print(f"Batch {batch[0]}: {batch[1]} from {batch[2]}, {batch[3]} kg, status {STATUS[batch[5]]}")
for sender, receiver, _time, location in fn.getTransferHistory(batch_id).call():
    print(f"  Transfer: {fn.participants(sender).call()[0]} -> "
          f"{fn.participants(receiver).call()[0]} at {location}")
for location, temperature, _time, _by in fn.getCheckpoints(batch_id).call():
    print(f"  Checkpoint: {location} {temperature} C")
print("Original certificate valid:", fn.verifyCertificate(batch_id, cert_hash).call())
print("Altered certificate valid: ",
      fn.verifyCertificate(batch_id, w3.keccak(text=certificate + "!")).call())

print("\n--- 5. Security tests (must be rejected) ---")
must_fail(fn.createBatch("Fake", "Unknown", 1, cert_hash), processor, "Processor creates a batch")
must_fail(fn.registerParticipant(processor, "Fake", 1), distributor, "Non-admin registers")
must_fail(fn.transferBatch(batch_id, processor, "X"), farmer, "Farmer moves a batch it doesn't own")
must_fail(fn.transferBatch(batch_id, distributor, "X"), retailer, "Retailer sends batch back")

print("\n--- 6. Admin recalls the batch ---")
send(fn.recallBatch(batch_id, "Salmonella detected"), admin, "Batch recalled")
must_fail(fn.updateStatus(batch_id, 3), retailer, "Update a recalled batch")

print("\nDone.")
