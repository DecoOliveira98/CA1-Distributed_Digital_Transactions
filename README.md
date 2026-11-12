# Food Traceability DApp

**Module:** Distributed Digital Transactions – CA1
**College:** CCT College Dublin
**Student:** Andre Luiz Oliveira da Cunha - 2024214
**Deadline:** 13 November 2026

## Overview

A blockchain-based decentralized application (DApp) for tracking food products across the supply chain, from farm to retailer. Each product batch is recorded on-chain, and every transfer between two parties (sender → receiver) is stored as an immutable, verifiable transaction. This gives all participants and consumers a transparent and tamper-proof history of the product's origin, handling and condition.

## Project Timeline

| Phase                     | Dates  | Goal                                                                | Status |
| ------------------------- | ------ | ------------------------------------------------------------------- | ------ |
| 0 – Setup                 | 27 Oct | Repository, environment (Ganache, Python, Remix), project structure | Done   |
| 1 – Research & Design     | 27 oct | Business model, benefits & challenges, cryptography, references     | Done   |
| 2 – Smart Contract & DApp | 9 nov  | Solidity contract, Remix + Ganache testing, Python & shell scripts  | Done   |
| 2.1 - Screenshots         | 9 nov  | take all screenshot of the test in Remix IDE                        | Done   |
| 3 – Poster                | 12 nov | PowerPoint poster (max. 700 words)                                  | Done   |
| 4 – Video & Submission    | 13 nov | Video presentation (max. 4 min), cover page, Moodle upload          | Done   |

The detailed checklist for each phase is in [`docs/project_plan.ipynb`](docs/project_plan.ipynb).

## Deliverables

1. **DApp** – Solidity smart contract and scripts, working on Remix IDE and Ganache
2. **Poster** – PowerPoint poster presentation covering research, design and implementation
3. **Video** – presentation of the poster contents (max. 4 minutes)

## Supply Chain Actors

- **Farmer** – creates a new product batch
- **Processor** – receives and processes the batch
- **Distributor** – transports the batch and records checkpoints (e.g. temperature, location)
- **Retailer** – receives the final product for sale
- **Consumer** – verifies the full history of a batch

## Planned Smart Contract Features

- Role-based access control (only registered participants can act)
- Batch creation with an on-chain hash of the quality certificate
- Batch transfers between two parties (sender → receiver), with full ownership history
- Checkpoints for location and temperature, with alerts for cold-chain breaches
- Batch recall by the consortium administrator
- Public view functions so consumers can verify a batch's history

## Tech Stack

| Tool             | Purpose                                                |
| ---------------- | ------------------------------------------------------ |
| Solidity         | Smart contract development                             |
| Remix IDE        | Writing, compiling, deploying and testing the contract |
| Ganache          | Local Ethereum blockchain for development              |
| Python (web3.py) | Deploying and interacting with the contract            |
| Shell script     | Automating the local environment and scripts           |

## Project Structure

```
contracts/                 Solidity smart contract (FoodTrace.sol)
scripts/                   Python deploy/interaction scripts and shell script
docs/project_plan.ipynb    Step-by-step plan and research notes
docs/poster_summary.md     Condensed research text for the poster
docs/references.md         Harvard reference list
docs/screenshots/          Screenshots of contract testing
poster/                    PowerPoint poster presentation
```

## How to Run

**Requirements:** Python 3, Node.js and Git Bash (on Windows).

```bash
npm install -g ganache
pip install web3 py-solc-x
```

### Option 1 – Automated (Python + shell script)

```bash
bash scripts/run.sh
```

This starts Ganache, deploys the contract (`deploy.py`) and runs the full supply chain flow (`interact.py`), then shuts Ganache down.

To run the steps separately, start Ganache in one terminal and run the scripts in another:

```bash
ganache --wallet.deterministic --wallet.totalAccounts 5 --chain.chainId 1337
python scripts/deploy.py
python scripts/interact.py
```

### Option 2 – Remix IDE

1. Start Ganache (command above).
2. Open [Remix](https://remix.ethereum.org) and paste `contracts/FoodTrace.sol`.
3. Compile with version 0.8.24 and **EVM version `shanghai`** (Advanced Configurations).
4. In Deploy & Run, choose **Dev – Ganache Provider** (`http://127.0.0.1:8545`) and deploy with account 0 (admin).
5. Use accounts 1–4 as Farmer, Processor, Distributor and Retailer.

Screenshots of the tests are in [`docs/screenshots/`](docs/screenshots/).
