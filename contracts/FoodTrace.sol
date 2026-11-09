// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/// @title  FoodTrace - Food traceability across the supply chain
/// @author Andre Luiz Oliveira da Cunha (2024214)
/// @notice Records food batches on-chain and tracks every transfer between
///         two parties (sender -> receiver), from farm to retailer.
/// @dev    The blockchain acts as the "middle layer" between users: no single
///         company owns the data, but every participant can verify it.
contract FoodTrace {
    // ======================================================================
    // TYPES
    // ======================================================================

    // An enum is a list of named constants. Internally each value is stored as
    // a number starting at 0, so: None = 0, Farmer = 1, Processor = 2,
    // Distributor = 3, Retailer = 4.
    // In Remix, you pass the NUMBER (e.g. 1 for Farmer).
    // The order matters: it represents the stages of the supply chain, and it is
    // used in transferBatch() to stop batches from moving backwards.
    enum Role {
        None,
        Farmer,
        Processor,
        Distributor,
        Retailer
    }

    // Lifecycle of a batch:
    // Created = 0, Processed = 1, InTransit = 2, Delivered = 3, Sold = 4, Recalled = 5
    enum Status {
        Created,
        Processed,
        InTransit,
        Delivered,
        Sold,
        Recalled
    }

    // A struct groups related data into one custom type (similar to a class
    // with only attributes, or a row in a database table).

    // A supply chain company registered by the admin.
    struct Participant {
        string name; // company name
        Role role; // its stage in the supply chain
        bool registered; // true once registered (defaults to false)
    }

    // A batch of food (e.g. 500 kg of tomatoes from one harvest).
    struct Batch {
        uint256 id; // unique number (1, 2, 3...)
        string productName; // e.g. "Organic Tomatoes"
        string origin; // e.g. "Wexford, Ireland"
        uint256 quantity; // e.g. in kg
        address currentOwner; // blockchain address of who holds the batch now
        Status status; // current stage of its lifecycle
        uint256 createdAt; // Unix timestamp (seconds) of creation
        bytes32 certificateHash; // Keccak-256 hash of the off-chain quality certificate.
    }
    // The document itself is stored off-chain
    // because storing files on-chain is very expensive.
    // If anyone changes the document, its hash changes,
    // so tampering can be detected (integrity).

    // One change of custody: the SENDER hands the batch to the RECEIVER.
    struct Transfer {
        address from; // sender (previous owner)
        address to; // receiver (new owner)
        uint256 timestamp; // when the transfer happened
        string location; // where the transfer happened
    }

    // A reading taken during transport (cold chain monitoring).
    // In a real system this could come automatically from an IoT sensor via an oracle.
    struct Checkpoint {
        string location; // e.g. "M50 Dublin"
        int16 temperature; // degrees Celsius. int16 = signed integer (allows negative
        // values, e.g. -18 for frozen food) and uses little storage.
        uint256 timestamp; // when it was recorded
        address recordedBy; // who recorded it
    }

    // ======================================================================
    // STATE VARIABLES (permanently stored on the blockchain)
    // ======================================================================

    // The consortium administrator: the account that deployed the contract.
    // "public" makes Solidity automatically create a getter function admin().
    address public admin;

    // Total number of batches created. Also used to generate the next batch id.
    uint256 public batchCount;

    // Maximum safe temperature for the cold chain (°C).
    // "constant" = fixed at compile time; it costs no storage and no gas to read.
    int16 public constant MAX_TEMPERATURE = 8;

    // A mapping is a key -> value lookup table (like a dictionary / hash map).
    // Every possible key exists and returns default values (0, false, "") if unset.

    // address -> participant details. Public, so anyone can check who is registered.
    mapping(address => Participant) public participants;

    // batch id -> batch details. Private: read it through getBatch() instead.
    // NOTE: "private" only stops OTHER CONTRACTS from reading it directly.
    // All data on a public blockchain can still be read by anyone (no confidentiality).
    mapping(uint256 => Batch) private batches;

    // batch id -> list of all its transfers (the full ownership history).
    mapping(uint256 => Transfer[]) private transferHistory;

    // batch id -> list of all its checkpoints.
    mapping(uint256 => Checkpoint[]) private checkpoints;

    // ======================================================================
    // EVENTS
    // ======================================================================

    // Events are logs written to the blockchain when something happens.
    // They are cheap, cannot be modified, and external apps (a DApp, web3.py,
    // Remix) can listen to them. In Remix they appear in the transaction "logs".
    // "indexed" parameters can be used as search filters
    // (e.g. "show me all transfers of batch 1").

    event ParticipantRegistered(
        address indexed account,
        string name,
        Role role
    );
    event BatchCreated(
        uint256 indexed batchId,
        address indexed farmer,
        string productName
    );
    event BatchTransferred(
        uint256 indexed batchId,
        address indexed from,
        address indexed to,
        uint256 timestamp
    );
    event StatusUpdated(uint256 indexed batchId, Status status);
    event CheckpointAdded(
        uint256 indexed batchId,
        string location,
        int16 temperature
    );
    event TemperatureAlert(uint256 indexed batchId, int16 temperature);
    event BatchRecalled(uint256 indexed batchId, string reason);

    // ======================================================================
    // MODIFIERS (reusable access-control checks)
    // ======================================================================

    // A modifier runs its checks BEFORE the function body.
    // "_;" is where the function's own code is inserted.
    // require(condition, "message"): if the condition is false, the transaction
    // is reverted (all changes are undone), and the message is shown as the error.
    //
    // msg.sender = the address that signed the transaction.
    // The network recovers it from the transaction's ECDSA (secp256k1) signature,
    // so it cannot be faked without the private key. This is what makes the
    // access control below secure (authenticity and non-repudiation).

    // Only the consortium administrator.
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    // Only participants with a specific role (e.g. only Farmers can create batches).
    modifier onlyRole(Role _role) {
        require(
            participants[msg.sender].role == _role,
            "Caller does not have the required role"
        );
        _;
    }

    // The batch id must exist (ids start at 1 and go up to batchCount).
    modifier batchExists(uint256 _batchId) {
        require(_batchId > 0 && _batchId <= batchCount, "Batch does not exist");
        _;
    }

    // Only the current owner of the batch (the SENDER in a transfer).
    modifier onlyBatchOwner(uint256 _batchId) {
        require(
            batches[_batchId].currentOwner == msg.sender,
            "Only the current owner can do this"
        );
        _;
    }

    // A recalled batch is frozen: no more transfers, status updates or checkpoints.
    modifier notRecalled(uint256 _batchId) {
        require(
            batches[_batchId].status != Status.Recalled,
            "Batch has been recalled"
        );
        _;
    }

    // ======================================================================
    // CONSTRUCTOR
    // ======================================================================

    // Runs only ONCE, when the contract is deployed.
    // Whoever deploys the contract (Account 0 in Ganache) becomes the admin.
    constructor() {
        admin = msg.sender;
    }

    // ======================================================================
    // ADMIN FUNCTIONS
    // ======================================================================

    /// @notice Register a supply chain participant with a role.
    /// @dev    This is what makes the blockchain "permissioned": only accounts
    ///         approved by the consortium can write data.
    /// @param  _account  blockchain address of the company
    /// @param  _name     company name
    /// @param  _role     1 = Farmer, 2 = Processor, 3 = Distributor, 4 = Retailer
    // "external" = can only be called from outside the contract (users / other contracts).
    // "memory"   = the string is a temporary copy that only exists during the call.
    function registerParticipant(
        address _account,
        string memory _name,
        Role _role
    ) external onlyAdmin {
        require(_account != address(0), "Invalid address"); // 0x000...0 is not a real account
        require(_role != Role.None, "Invalid role"); // must choose a real role
        require(
            !participants[_account].registered,
            "Participant already registered"
        ); // no duplicates

        // Save the participant in the mapping (on-chain storage).
        participants[_account] = Participant(_name, _role, true);

        // Write a log so the registration can be audited later.
        emit ParticipantRegistered(_account, _name, _role);
    }

    /// @notice Recall a batch (e.g. contamination found).
    /// @dev    Instead of a blanket recall of all products, only this specific batch
    ///         is blocked, and its full history shows every company that handled it.
    function recallBatch(
        uint256 _batchId,
        string memory _reason
    ) external onlyAdmin batchExists(_batchId) {
        batches[_batchId].status = Status.Recalled;
        emit BatchRecalled(_batchId, _reason);
    }

    // ======================================================================
    // SUPPLY CHAIN FUNCTIONS
    // ======================================================================

    /// @notice A Farmer creates a new batch (the start of the supply chain).
    /// @param  _certificateHash keccak256 hash of the quality/organic certificate
    /// @return the id of the new batch
    function createBatch(
        string memory _productName,
        string memory _origin,
        uint256 _quantity,
        bytes32 _certificateHash
    ) external onlyRole(Role.Farmer) returns (uint256) {
        require(_quantity > 0, "Quantity must be greater than zero");

        // Generate the new id (first batch = 1).
        batchCount++;

        // Create the batch and store it. The farmer is the first owner.
        batches[batchCount] = Batch({
            id: batchCount,
            productName: _productName,
            origin: _origin,
            quantity: _quantity,
            currentOwner: msg.sender,
            status: Status.Created,
            createdAt: block.timestamp, // time of the block that includes this transaction
            certificateHash: _certificateHash
        });

        emit BatchCreated(batchCount, msg.sender, _productName);
        return batchCount;
    }

    /// @notice Transfer a batch from the SENDER (current owner) to the RECEIVER.
    /// @dev    This is the core "sender -> receiver" feature required by the brief.
    ///         Several modifiers run first: the batch must exist, the caller must
    ///         own it, and it must not be recalled.
    function transferBatch(
        uint256 _batchId,
        address _receiver,
        string memory _location
    )
        external
        batchExists(_batchId)
        onlyBatchOwner(_batchId)
        notRecalled(_batchId)
    {
        // Load both participants into memory (cheaper than reading storage several times).
        Participant memory sender = participants[msg.sender];
        Participant memory receiver = participants[_receiver];

        // Business rules:
        require(
            receiver.registered,
            "Receiver is not a registered participant"
        ); // only known companies
        require(_receiver != msg.sender, "Cannot transfer to yourself");
        require(
            sender.role != Role.Retailer,
            "Retailer cannot transfer the batch"
        ); // end of the chain
        // Convert the enums to numbers to compare stages: the batch can stay at the
        // same stage (e.g. distributor -> distributor) or move forward, never backwards.
        require(
            uint8(receiver.role) >= uint8(sender.role),
            "Receiver must be at the same or a later stage"
        );

        // Change the owner of the batch.
        batches[_batchId].currentOwner = _receiver;

        // Add this transfer to the batch's permanent, append-only history.
        transferHistory[_batchId].push(
            Transfer(msg.sender, _receiver, block.timestamp, _location)
        );

        emit BatchTransferred(_batchId, msg.sender, _receiver, block.timestamp);
    }

    /// @notice The current owner updates the status of the batch
    ///         (e.g. Processor -> Processed, Distributor -> InTransit, Retailer -> Sold).
    function updateStatus(
        uint256 _batchId,
        Status _status
    )
        external
        batchExists(_batchId)
        onlyBatchOwner(_batchId)
        notRecalled(_batchId)
    {
        // Recalling is a special action reserved for the admin (see recallBatch).
        require(_status != Status.Recalled, "Only admin can recall a batch");
        batches[_batchId].status = _status;
        emit StatusUpdated(_batchId, _status);
    }

    /// @notice The current owner records a checkpoint (location + temperature).
    /// @dev    If the temperature is above MAX_TEMPERATURE, an alert event is emitted,
    ///         so a cold-chain breach is permanently recorded and cannot be hidden.
    function addCheckpoint(
        uint256 _batchId,
        string memory _location,
        int16 _temperature
    )
        external
        batchExists(_batchId)
        onlyBatchOwner(_batchId)
        notRecalled(_batchId)
    {
        checkpoints[_batchId].push(
            Checkpoint(_location, _temperature, block.timestamp, msg.sender)
        );
        emit CheckpointAdded(_batchId, _location, _temperature);

        if (_temperature > MAX_TEMPERATURE) {
            emit TemperatureAlert(_batchId, _temperature);
        }
    }

    // ======================================================================
    // VIEW FUNCTIONS (read-only: anyone can verify, e.g. consumers, regulators)
    // ======================================================================

    // "view" = the function only reads data and does not change the blockchain.
    // Calling a view function is FREE (no transaction, no gas), which is ideal
    // for a consumer scanning a QR code. In Remix these buttons are blue.

    /// @notice Get all details of a batch.
    function getBatch(
        uint256 _batchId
    ) external view batchExists(_batchId) returns (Batch memory) {
        return batches[_batchId];
    }

    /// @notice Get the full ownership history of a batch (every sender -> receiver).
    function getTransferHistory(
        uint256 _batchId
    ) external view batchExists(_batchId) returns (Transfer[] memory) {
        return transferHistory[_batchId];
    }

    /// @notice Get all checkpoints (locations and temperatures) of a batch.
    function getCheckpoints(
        uint256 _batchId
    ) external view batchExists(_batchId) returns (Checkpoint[] memory) {
        return checkpoints[_batchId];
    }

    /// @notice Check if a document matches the certificate hash stored on-chain.
    /// @dev    The verifier hashes the document they received with keccak256 and
    ///         compares it with the stored hash. Same hash = document is authentic
    ///         and unchanged. Different hash = the document was altered or is fake.
    function verifyCertificate(
        uint256 _batchId,
        bytes32 _documentHash
    ) external view batchExists(_batchId) returns (bool) {
        return batches[_batchId].certificateHash == _documentHash;
    }
}
