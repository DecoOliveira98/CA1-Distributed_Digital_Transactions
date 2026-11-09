# Poster-Ready Summary (~340 words)

Condensed version of the Phase 1 study notes (`project_plan.ipynb`, sections 1.1–1.4), ready to copy into the poster.
Headings and citations do not count towards the 700-word limit.

---

## Problem
Food traceability today relies on paper records and isolated ERP systems, creating data silos (Iqbal, 2020). Each business typically only knows its immediate supplier and customer, so nobody sees the full chain. Tracing a package of mangoes took Walmart about seven days (Kamath, 2018), food fraud costs up to US$40 billion a year (PwC, 2016), and in Ireland 10 of 27 beef burgers tested contained undeclared horse DNA (Food Safety Authority of Ireland, 2013).

## Proposed Solution
A consortium blockchain DApp where every food batch is registered on-chain and each change of custody is a signed transfer from **sender to receiver**: Farmer → Processor → Distributor → Retailer. The smart contract acts as the middle layer between users, enforcing roles, recording temperature checkpoints, flagging cold-chain breaches and enabling instant recalls. Consumers verify a batch's history by scanning a QR code. Large retailers fund the infrastructure through subscriptions, while farmers join at low cost. Using this approach, Walmart's traceback time fell to 2.2 seconds (Kamath, 2018).

## Recent Advancements
IoT sensors record cold-chain data automatically, and oracles bring that data on-chain. Certificates are stored on IPFS with only their hash on-chain, and Layer 2 rollups reduce transaction costs. New regulations in the EU and US are also making digital traceability a legal requirement.

## Benefits vs Challenges

| Benefits                        | Challenges                                                                |
| ------------------------------- | ------------------------------------------------------------------------- |
| Immutable, shared record        | Bad data at the source stays bad (Galvez, Mejuto and Simal-Gandara, 2018) |
| Recalls in seconds, not days    | Gas costs and scalability                                                 |
| Harder to commit food fraud     | Privacy between competitors                                               |
| Real-time audits for regulators | Trusting external data via oracles                                        |
| Greater consumer trust          | Adoption barriers for small producers (Saberi *et al.*, 2019)             |

## Cryptography
The solution uses **ECDSA on the secp256k1 curve** combined with **Keccak-256 hashing**, both native to Ethereum (Wood, 2014). Each participant signs transactions with their private key; the network recovers their address from the signature, and the smart contract uses it for access control. This guarantees **authenticity** and **non-repudiation**: nobody can impersonate a farmer or deny a transfer. Keccak-256 hashes chain blocks and certificates together, so any tampering is detectable, ensuring **integrity**. ECDSA was chosen over RSA because a 256-bit key offers the same security as a 3072-bit RSA key (Barker, 2020), giving smaller signatures and lower costs, which also suits IoT devices. It does not provide confidentiality, so sensitive commercial data stays off-chain.

---

## References

Barker, E. (2020) *Recommendation for key management: Part 1 – General*. NIST Special Publication 800-57 Part 1, Revision 5. Gaithersburg, MD: National Institute of Standards and Technology. doi: 10.6028/NIST.SP.800-57pt1r5.

Food Safety Authority of Ireland (2013) *FSAI horse meat incident survey 2013*. Dublin: FSAI. Available at: https://www.fsai.ie/publications/fsai-horse-meat-incident-survey-2013 (Accessed: 27 October 2026).

Galvez, J.F., Mejuto, J.C. and Simal-Gandara, J. (2018) 'Future challenges on the use of blockchain for food traceability analysis', *TrAC Trends in Analytical Chemistry*, 107, pp. 222–232. doi: 10.1016/j.trac.2018.08.011.

Iqbal, M. (2020) 'Introduction to blockchain technology' [Lecture notes]. *Distributed Digital Transactions*. CCT College Dublin.

Kamath, R. (2018) 'Food traceability on blockchain: Walmart's pork and mango pilots with IBM', *The Journal of the British Blockchain Association*, 1(1), pp. 47–53. doi: 10.31585/jbba-1-1-(10)2018.

PwC (2016) *Fighting $40bn food fraud to protect food supply* [Press release]. 27 January. Available at: https://www.pwc.com/my/en/press/160127-fighting-40bn-food-fraud-to-protect-food-supply.html (Accessed: 27 October 2026).

Saberi, S., Kouhizadeh, M., Sarkis, J. and Shen, L. (2019) 'Blockchain technology and its relationships to sustainable supply chain management', *International Journal of Production Research*, 57(7), pp. 2117–2135. doi: 10.1080/00207543.2018.1533261.

Wood, G. (2014) *Ethereum: a secure decentralised generalised transaction ledger*. Ethereum Project Yellow Paper. Available at: https://ethereum.github.io/yellowpaper/paper.pdf (Accessed: 27 October 2026).
