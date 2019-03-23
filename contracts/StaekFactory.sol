pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * StaekFactory - Staek(house) Factory for ERC-20 Staek(-ing) Management
 *
 *                *** Used Exclusively by Tokens w/ ZeroCache Integration ***
 *                    ( see WaitingList.sol for integration info )
 *
 *                Offering both staekers and providers the ability to
 *                create & manage their own staekhouse(s) for ANY
 *                ERC20-compatible token they choose.
 *
 *                Limited DEBT-ing (token withdrawal) rights are granted to the
 *                service provider / stakeholder. However, all contract options
 *                are pre-authorized and stored on-chain at creation time.
 *
 *                What are the benefits of STAEK-ing?
 *                -----------------------------------
 *
 *                Staekhouses allow users the ability to self-manage a
 *                time-locked STAEK (an escrow of tokens) in compatible DApps
 *                that provide ANY or ALL the following:
 *                    - Fee-less, On-chain Token Transactions
 *                    - Recurring / Subscription Services
 *                    - Content and Access Restrictions
 *                    - Community-based Voting & Governance
 *
 * Version 19.3.23
 *
 * https://d14na.org
 * support@d14na.org
 */


/*******************************************************************************
 *
 * SafeMath
 */
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


/*******************************************************************************
 *
 * ECRecovery
 *
 * Contract function to validate signature of pre-approved token transfers.
 * (borrowed from LavaWallet)
 */
contract ECRecovery {
    function recover(bytes32 hash, bytes sig) public pure returns (address);
}


/*******************************************************************************
 *
 * ERC Token Standard #20 Interface
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
 */
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


/*******************************************************************************
 *
 * ApproveAndCallFallBack
 *
 * Contract function to receive approval and execute function in one call
 * (borrowed from MiniMeToken)
 */
contract ApproveAndCallFallBack {
    function approveAndCall(address spender, uint tokens, bytes data) public;
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}


/*******************************************************************************
 *
 * Owned contract
 */
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);

        emit OwnershipTransferred(owner, newOwner);

        owner = newOwner;

        newOwner = address(0);
    }
}


/*******************************************************************************
 *
 * Zer0netDb Interface
 */
contract Zer0netDbInterface {
    /* Interface getters. */
    function getAddress(bytes32 _key) external view returns (address);
    function getBool(bytes32 _key)    external view returns (bool);
    function getBytes(bytes32 _key)   external view returns (bytes);
    function getInt(bytes32 _key)     external view returns (int);
    function getString(bytes32 _key)  external view returns (string);
    function getUint(bytes32 _key)    external view returns (uint);

    /* Interface setters. */
    function setAddress(bytes32 _key, address _value) external;
    function setBool(bytes32 _key, bool _value) external;
    function setBytes(bytes32 _key, bytes _value) external;
    function setInt(bytes32 _key, int _value) external;
    function setString(bytes32 _key, string _value) external;
    function setUint(bytes32 _key, uint _value) external;

    /* Interface deletes. */
    function deleteAddress(bytes32 _key) external;
    function deleteBool(bytes32 _key) external;
    function deleteBytes(bytes32 _key) external;
    function deleteInt(bytes32 _key) external;
    function deleteString(bytes32 _key) external;
    function deleteUint(bytes32 _key) external;
}


/*******************************************************************************
 *
 * ZeroCache Interface
 */
contract ZeroCacheInterface {
    function balanceOf(address _token, address _owner) public constant returns (uint balance);
    function transfer(address _to, address _token, uint _tokens) external returns (bool success);
    function transfer(address _token, address _from, address _to, uint _tokens, address _staekholder, uint _staek, uint _expires, uint _nonce, bytes _signature) external returns (bool success);
}


/*******************************************************************************
 *
 * @notice Staek(house) Factory
 *
 * @dev Allows token managers with ZeroCache integration for their tokens to
 *      support individual staekhouses.
 *
 *      NOTE: All on-chain token transfers occur via the ZeroCache wallet.
 */
contract StaekFactory is Owned {
    using SafeMath for uint;

    /* Initialize predecessor contract. */
    address private _predecessor;

    /* Initialize successor contract. */
    address private _successor;

    /* Initialize revision number. */
    uint private _revision;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /* Set namespace. */
    string private _namespace = 'staek.factory';

    /**
     * Staekhouse Structure
     *
     * token          - ANY ZeroCache-integrated token.
     * owner          - The staekhouse owner.
     * isPrivate      - Flag handling for either single or multiple user(s).
     * debtLimit      - Maximum debt (withdrawal) amount (per debt cycle).
     * debtPower      - Reduces the `lockInterval` for `debtLimit` by this divisor.
     * lockInterval   - Number of blocks to enfore lock time (during creation/renewal).
     * staekLockTimes - Places time limit on staeker withdrawal(s).
     * debtLockTimes  - Places time limit on debt (provider) withdrawal(s).
     * balances       - Map of token quantities for individual STAEKers.
     * inceptions     - Initial staeking times.
     * collections    - Debt collections made during debt cycles.
     */
    struct Staekhouse {
        address token;
        address owner;
        bool isPrivate;
        uint debtLimit;
        uint debtPower;
        uint lockInterval;
        mapping(address => uint) staekLockTimes;
        mapping(address => uint) debtLockTimes;
        mapping(address => uint) balances;
        mapping(address => uint) inceptions;
        mapping(uint => mapping(address => uint)) collections;
    }

    /* Initialize staekhouses. */
    mapping(bytes32 => Staekhouse) private _staekhouses;

    /* Initialize default lock interval. */
    // NOTE: 1,000 blocks is approximately 4 hours.
    uint _DEFAULT_LOCK_INTERVAL = 1000;

    /* Initialize maximum lock interval. */
    // NOTE: 175,000 blocks is approximately 30 days.
    uint _MAX_LOCK_INTERVAL = 175000;

    /* Initialize minimum lock interval. */
    // NOTE: 20 blocks is approximately 5 minutes.
    uint _MIN_LOCK_INTERVAL = 20;

    event CollectDebt(
        bytes32 indexed staekhouseId,
        uint tokens
    );

    event Migrate(
        bytes32 staekhouseId
    );

    event Renewal(
        bytes32 indexed staekhouseId,
        address user // can be either owner OR provider address
    );

    event Staeking(
        bytes32 staekhouseId,
        address token
    );

    event StaekUp(
        bytes32 indexed staekhouseId,
        uint tokens
    );

    event StaekDown(
        bytes32 indexed staekhouseId,
        uint tokens
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        // _zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);
        _zer0netDb = Zer0netDbInterface(0x4C2f68bCdEEB88764b1031eC330aD4DF8d6F64D6); // ROPSTEN

        /* Initialize (aname) hash. */
        bytes32 hash = keccak256(abi.encodePacked('aname.', _namespace));

        /* Set predecessor address. */
        _predecessor = _zer0netDb.getAddress(hash);

        /* Verify predecessor address. */
        if (_predecessor != 0x0) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = StaekFactory(_predecessor).getRevision();

            /* Set (current) revision number. */
            _revision = lastRevision + 1;
        }
    }

    /**
     * @dev Only allow access to an authorized Zer0net administrator.
     */
    modifier onlyAuthBy0Admin() {
        /* Verify write access is only permitted to authorized accounts. */
        require(_zer0netDb.getBool(keccak256(
            abi.encodePacked(msg.sender, '.has.auth.for.', _namespace))) == true);

        _;      // function code is inserted here
    }

    /**
     * @dev Only allow access to "registered" staekhouse owner.
     */
    modifier onlyStaekhouseOwner(
        bytes32 _staekhouseId
    ) {
        /* Retrieve staekhouse owner. */
        address staekhouseOwner = _staekhouses[_staekhouseId].owner;

        /* Validate token owner. */
        require(msg.sender == staekhouseOwner);

        _;      // function code is inserted here
    }

    /**
     * @dev Only allow access to "registered" staekhouse authorized user/contract.
     */
    modifier onlyTokenProvider(
        bytes32 _staekhouseId
    ) {
        /* Retrieve staekhouse token. */
        address token = _staekhouses[_staekhouseId].token;

        /* Validate authorized token manager. */
        require(_zer0netDb.getBool(keccak256(abi.encodePacked(
            _namespace, '.',
            msg.sender,
            '.has.auth.for.',
            token
        ))) == true);

        _;      // function code is inserted here
    }

    /**
     * THIS CONTRACT DOES NOT ACCEPT DIRECT ETHER
     */
    function () public payable {
        /* Cancel this transaction. */
        revert('Oops! Direct payments are NOT permitted here.');
    }


    /***************************************************************************
     *
     * ACTIONS
     *
     */

    /**
     * Add Staekhouse
     *
     * Any user can create and manage a new staekhouse
     * exclusively for their desired ERC20-compatible token.
     *
     * Staekhouse Debts
     * ----------------
     *
     * Token managers may DEBT staeked tokens from owners, if the
     * `_debtLimit` is greater than zero. All DEBTs made are recorded
     * to the Ethereum Event Log.
     */
    function addStaekhouse(
        address _token,
        uint _lockInterval,
        uint _debtLimit,
        uint _debtPower,
        bool _isPrivate
    ) external returns (bytes32 staekhouseId) {
        /* Set last block hash. */
        bytes32 lastBlockHash = blockhash(block.number - 1);

        /* Generate staekhouse id. */
        staekhouseId = keccak256(abi.encodePacked(
            _namespace, '.',
            msg.sender, '.',
            _token, '.',
            lastBlockHash
        ));

        /* Initialize lock interval. */
        uint lockInterval = 0;

        /* Validate minimum lock time. */
        if (
            _lockInterval >= _MIN_LOCK_INTERVAL &&
            _lockInterval <= _MAX_LOCK_INTERVAL
        ) {
            lockInterval = _lockInterval;
        } else {
            lockInterval = _DEFAULT_LOCK_INTERVAL;
        }

        /* Calculate staek lock time. */
        // NOTE: This will be applied to the token owner.
        uint staekLockTime = block.number
            .add(lockInterval);

        /* Validate debt power. */
        if (_debtPower == 0 || _debtPower > lockInterval) {
            revert('Oops! You entered an INVALID debt power.');
        }

        /* Calculate debt lock time. */
        uint debtLockTime = block.number
            .add(lockInterval.div(_debtPower));

        /* Initialize staekhouse. */
        // NOTE: Either a STAEKer OR a provider can create a staekhouse.
        Staekhouse memory staekhouse = Staekhouse({
            token: _token,
            owner: msg.sender,
            isPrivate: _isPrivate,
            debtLimit: _debtLimit,
            debtPower: _debtPower,
            lockInterval: lockInterval
            // NOTE: mappings have to be skipped in memory.
            // staekLockTimes: staekLockTimes,
            // debtLockTimes: debtLockTimes,
            // balances: uint(0),
            // inceptions: uint(0),
            // collections: block.number,
        });

        /* Add new staekhouse. */
        _staekhouses[staekhouseId] = staekhouse;

        /* Set location. */
        _zer0netDb.setAddress(staekhouseId, address(this));

        /* Set block number. */
        // _zer0netDb.setUint(staekhouseId, block.number);

        /* Broadcast event. */
        emit Staeking(staekhouseId, _token);
    }

    /**
     * Add (Token) Manager
     */
    function addManager(
        address _token,
        address _tokenManager
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _tokenManager,
            '.has.auth.for.',
            _token
        ));

        /* Set value to Zer0net Db. */
        _zer0netDb.setBool(hash, true);

        /* Return success. */
        return true;
    }

    /**
     * Remove (Token) Manager
     */
    function removeManager(
        address _token,
        address _tokenManager
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _tokenManager,
            '.has.auth.for.',
            _token
        ));

        /* Set value to Zer0net Db. */
        _zer0netDb.setBool(hash, false);

        /* Return success. */
        return true;
    }

    /**
     * Staek Up
     *
     * Provides support for "manual" staek deposits (from either a user
     * or a previous generation of a staekhouse sweeping its balance).
     *
     * NOTE: Required pre-allowance/approval is required in order
     *       to successfully complete the transfer.
     */
    function staekUp(
        bytes32 _staekhouseId,
        uint _tokens,
        address _staekholder,
        uint _staek,
        uint _expires,
        uint _nonce,
        bytes _signature
    ) external returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Transfer the ERC-20 tokens into Staek(house) Factory account. */
        // NOTE: This is performed first to prevent re-entry attack.
        _zeroCache().transfer(
            staekhouse.token,
            msg.sender,
            address(this),
            _tokens,
            _staekholder,
            _staek,
            _expires,
            _nonce,
            _signature
        );

        /* Increase staekhouse balance. */
        staekhouse.balances[msg.sender] =
            staekhouse.balances[msg.sender].add(_tokens);

        /* Broadcast event. */
        emit StaekUp(_staekhouseId, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Staek Down (Tokens Decrease)
     */
    function staekDown(
        bytes32 _staekhouseId,
        uint _tokens
    ) external returns (bool success) {
        /* Staek down. */
        return _staekDown(
            _staekhouseId,
            msg.sender,
            _tokens
        );
    }

    // TODO Add relayer option.

    /**
     * Staek Down (Tokens Decrease)
     *
     * NOTE: Transfers occur exclusively via the ZeroCache wallet.
     */
    function _staekDown(
        bytes32 _staekhouseId,
        address _owner,
        uint _tokens
    ) private returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Validate staek balance. */
        if (staekhouse.balances[_owner] < _tokens) {
            revert('Oops! You DO NOT have enough staek.');
        }

        /* Validate withdrawal permission. */
        if (staekhouse.debtLockTimes[_owner] < block.number) {
            revert('Oops! This staek is still TIME LOCKED.');
        }

        /* Decrease staekhouse balance. */
        staekhouse.balances[_owner] =
            staekhouse.balances[_owner].sub(_tokens);

        /* Transfer the ERC-20 tokens back to owner. */
        // NOTE: This is performed last to prevent re-entry attack.
        _zeroCache().transfer(
            _owner,
            staekhouse.token,
            _tokens
        );

        /* Broadcast event. */
        emit StaekDown(_staekhouseId, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Debt Collection (For Public)
     */
    function debtCollect(
        bytes32 _staekhouseId,
        address _staeker,
        uint _tokens
    ) external onlyTokenProvider(_staekhouseId) returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Validate staek balance. */
        if (staekhouse.balances[_staeker] < _tokens) {
            revert('Oops! You DO NOT have enough staek.');
        }

        /* Retrieve current lock cycle. */
        uint lockCycle = getLockCycle(_staekhouseId, _staeker);

        /* Add tokens to this cycle's collections balance. */
        staekhouse.collections[lockCycle][_staeker] =
            staekhouse.collections[lockCycle][_staeker].add(_tokens);

        /* Validate debt permission. */
        if (staekhouse.collections[lockCycle][_staeker] > staekhouse.debtLimit) {
            revert('Oops! You are OVER your collections limit for this cycle.');
        }

        /* Decrease staekhouse balance. */
        staekhouse.balances[_staeker] =
            staekhouse.balances[_staeker].sub(_tokens);

        /* Transfer the ERC-20 tokens back to owner. */
        // NOTE: This is performed last to prevent re-entry attack.
        _zeroCache().transfer(
            msg.sender,
            staekhouse.token,
            _tokens
        );

        /* Return success. */
        return true;
    }

    /**
     * Staek Extension
     *
     * NOTE: Calculated based on "previous lock" time.
     */
    function staekExtension(
        bytes32 _staekhouseId
    ) external returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Validate owner. */
        if (msg.sender != staekhouse.owner) {
            revert('Oops! You are NOT authorized here.');
        }

        /* Calculate "extended" staek lock time. */
        uint staekLockTime = staekhouse.staekLockTimes[msg.sender]
            .add(staekhouse.lockInterval);

        /* Set updated STAEK lock time. */
        _setStaekTTL(
            _staekhouseId,
            msg.sender,
            staekLockTime
        );

        /* Broadcast event. */
        emit Renewal(
            _staekhouseId,
            msg.sender
        );

        /* Return success. */
        return true;
    }

    /**
     * Staek Renewal
     *
     * NOTE: Calculated based on "current block" time.
     */
    function staekRenewal(
        bytes32 _staekhouseId
    ) external returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Validate owner. */
        if (msg.sender != staekhouse.owner) {
            revert('Oops! You are NOT authorized here.');
        }

        /* Calculate "renewed" staek lock time. */
        uint staekLockTime = block.number
            .add(staekhouse.lockInterval);

        /* Set updated STAEK lock time. */
        _setStaekTTL(
            _staekhouseId,
            msg.sender,
            staekLockTime
        );

        /* Broadcast event. */
        emit Renewal(
            _staekhouseId,
            msg.sender
        );

        /* Return success. */
        return true;
    }

    /**
     * Debt (Provider) Extension
     *
     * NOTE: Calculated based on "previous lock" time.
     */
    function debtExtension(
        bytes32 _staekhouseId,
        address _staeker
    ) external onlyTokenProvider(_staekhouseId) returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Calculate "extended" debt lock time. */
        uint debtLockTime = staekhouse.debtLockTimes[_staeker]
            .add(staekhouse.lockInterval.div(staekhouse.debtPower));

        /* Set updated lock time. */
        _setDebtTTL(
            _staekhouseId,
            _staeker,
            debtLockTime
        );

        /* Broadcast event. */
        emit Renewal(
            _staekhouseId,
            msg.sender
        );

        /* Return success. */
        return true;
    }

    /**
     * Debt (Provider) Renewal
     *
     * NOTE: Calculated based on "current block" time.
     */
    function debtRenewal(
        bytes32 _staekhouseId,
        address _staeker
    ) external onlyTokenProvider(_staekhouseId) returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

        /* Calculate "renewed" debt lock time. */
        uint debtLockTime = block.number
            .add(staekhouse.lockInterval.div(staekhouse.debtPower));

        /* Set updated lock time. */
        _setDebtTTL(
            _staekhouseId,
            _staeker,
            debtLockTime
        );

        /* Broadcast event. */
        emit Renewal(
            _staekhouseId,
            msg.sender
        );

        /* Return success. */
        return true;
    }

    /**
     * Migrate
     *
     * Transfers total balance of an ERC-20 token to the latest
     * Staekhouse contract.
     *
     * NOTE: This MUST be executed by each individual token (manager),
     *       but ONLY necessary if/when updating the contract address
     *       (e.g. in a web-based DApp).
     */
    function migrate(
        bytes32 _staekhouseId
    ) external onlyStaekhouseOwner(_staekhouseId) returns (
        bool success
    ) {
        // TODO Add migration code.

        /* Broadcast event. */
        emit Migrate(_staekhouseId);

        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * Get Lock Cycle
     *
     * Returns the current generation (of the lock cycle).
     */
    function getLockCycle(
        bytes32 _staekhouseId,
        address _staeker
    ) public view returns (uint generation) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Calculate number of elapsed blocks. */
        uint blocksElapsed = block.number
            .sub(staekhouse.inceptions[_staeker]);

        /* Calculate current generation. */
        generation = uint(blocksElapsed.div(staekhouse.lockInterval));
    }

    /**
     * (Get) Balance Of (For Private)
     */
    function balanceOf(
        bytes32 _staekhouseId
    ) public view returns (uint balance) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve balance. */
        balance = staekhouse.balances[staekhouse.owner];
    }

    /**
     * (Get) Balance Of (For Public)
     */
    function balanceOf(
        bytes32 _staekhouseId,
        address _owner
    ) public view returns (uint balance) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve balance. */
        balance = staekhouse.balances[_owner];
    }

    /**
     * Get Staekhouse
     *
     * Retrieves the location of the Staek Factory currently holding the
     * staek balance for the specified `_staekhouseId`.
     *
     * Also retrieves ALL configuration details for the staekhouse.
     *
     * NOTE: Service providers can request the `_staekhouseId` to
     *       verify proof of compliance to the service term agreement.
     */
    function getStaekhouse(
        bytes32 _staekhouseId,
        address _staeker
    ) external view returns (
        address factory,
        address token,
        address owner,
        uint staekLockTime,
        uint debtLockTime,
        uint debtLimit,
        uint lockInterval,
        uint balance
    ) {
        /* Retrieve (location of) factory. */
        factory = _zer0netDb.getAddress(_staekhouseId);

        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Set token. */
        token = staekhouse.token;

        /* Set owner. */
        owner = staekhouse.owner;

        /* Set staek lock time. */
        staekLockTime = staekhouse.staekLockTimes[_staeker];

        /* Set debt (provider) lock time. */
        debtLockTime = staekhouse.debtLockTimes[_staeker];

        /* Set debt limit. */
        debtLimit = staekhouse.debtLimit;

        /* Set lock interval. */
        lockInterval = staekhouse.lockInterval;

        /* Set balance. */
        balance = staekhouse.balances[_staeker];
    }

    /**
     * Get Staek Time-To-Live
     *
     * Block number to re-enable owner's access to execute on-chain,
     * staekhouse commands.
     */
    function getStaekTTL(
        bytes32 _staekhouseId,
        address _staeker
    ) public view returns (uint ttl) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve TTL. */
        ttl = staekhouse.staekLockTimes[_staeker];
    }

    /**
     * Get Debt Time-To-Live
     *
     * Block number to re-enable provider's access to execute on-chain,
     * staekhouse commands.
     */
    function getDebtTTL(
        bytes32 _staekhouseId,
        address _staeker
    ) public view returns (uint ttl) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve TTL. */
        ttl = staekhouse.debtLockTimes[_staeker];
    }

    /**
     * Get Revision (Number)
     */
    function getRevision() public view returns (uint) {
        return _revision;
    }


    /***************************************************************************
     *
     * SETTERS
     *
     */

    /**
     * Set Staek Time-To-Live
     *
     * Set the block number for the owner's next TTL.
     */
    function _setStaekTTL(
        bytes32 _staekhouseId,
        address _staeker,
        uint _lockTime
    ) private returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Set TTL. */
        staekhouse.staekLockTimes[_staeker] = _lockTime;

        /* Return success. */
        return true;
    }

    /**
     * Set Debt Time-To-Live
     *
     * Set the block number for the service provider's next TTL.
     */
    function _setDebtTTL(
        bytes32 _staekhouseId,
        address _staeker,
        uint _lockTime
    ) private returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Set TTL. */
        staekhouse.debtLockTimes[_staeker] = _lockTime;

        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * INTERFACES
     *
     */

    /**
     * Supports Interface (EIP-165)
     *
     * (see: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-165.md)
     *
     * NOTE: Must support the following conditions:
     *       1. (true) when interfaceID is 0x01ffc9a7 (EIP165 interface)
     *       2. (false) when interfaceID is 0xffffffff
     *       3. (true) for any other interfaceID this contract implements
     *       4. (false) for any other interfaceID
     */
    function supportsInterface(
        bytes4 _interfaceID
    ) external pure returns (bool) {
        /* Initialize constants. */
        bytes4 InvalidId = 0xffffffff;
        bytes4 ERC165Id = 0x01ffc9a7;

        /* Validate condition #2. */
        if (_interfaceID == InvalidId) {
            return false;
        }

        /* Validate condition #1. */
        if (_interfaceID == ERC165Id) {
            return true;
        }

        // TODO Add additional interfaces here.

        /* Return false (for condition #4). */
        return false;
    }

    /**
     * ECRecovery Interface
     */
    function _ecRecovery() private view returns (
        ECRecovery ecrecovery
    ) {
        /* Initialize hash. */
        bytes32 hash = keccak256('aname.ecrecovery');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        ecrecovery = ECRecovery(aname);
    }

    /**
     * ZeroCache Interface
     *
     * Retrieves the current ZeroCache interface,
     * using the aname record from Zer0netDb.
     */
    function _zeroCache() private view returns (
        ZeroCacheInterface zeroCache
    ) {
        /* Initialize hash. */
        bytes32 hash = keccak256('aname.zerocache');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        zeroCache = ZeroCacheInterface(aname);
    }


    /***************************************************************************
     *
     * UTILITIES
     *
     */

    /**
     * Convert Bytes to Bytes32
     */
    function _bytesToBytes32(
        bytes _data
    ) private pure returns (bytes32 result) {
        /* Loop through each byte. */
        for (uint i = 0; i < 32; i++) {
            /* Shift bytes onto result. */
            result |= bytes32(_data[i] & 0xFF) >> (i * 8);
        }
    }

    /**
     * Transfer Any ERC20 Token
     *
     * @notice Owner can transfer out any accidentally sent ERC20 tokens.
     *
     * @dev Provides an ERC20 interface, which allows for the recover
     *      of any accidentally sent ERC20 tokens.
     */
    function transferAnyERC20Token(
        address _tokenAddress,
        uint _tokens
    ) public onlyOwner returns (bool success) {
        return ERC20Interface(_tokenAddress).transfer(owner, _tokens);
    }
}
