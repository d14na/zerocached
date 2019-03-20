pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * StaekFactory - Staek(house) Factory for ERC-20 Staek(-ing) Management
 *
 *                *** Restricted to Token Managers w/ ZeroCache Integration ***
 *                    ( see WaitingList.sol for more info )
 *
 *                Offers users the ability to create & manage their own
 *                staekhouse(s) for ANY ERC20-compatible token they choose.
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
 * Version 19.3.20
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
     * Initialize Staekhouse Structure
     *
     * token            - ANY ZeroCache-integrated token.
     * owner            - The token owner.
     * ownerLockTime    - Places time limit on the owner's withdrawal(s).
     * providerLockTime - Places time limit on the provider's withdrawal(s).
     * debtLimit        - Maximum debt (withdrawal) amount (per debt cycle).
     * lockInterval     - Block number owners and providers allow transfers.
     * staek            - Quanity of tokens being STAEKed.
     */
    struct Staekhouse {
        address token;
        address owner;
        uint ownerLockTime;
        uint providerLockTime;
        uint debtLimit;
        uint lockInterval;
        uint balance;
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

    event Withdrawal(
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
    modifier onlyTokenManager(
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
        uint _debtPower
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

        /* Calculate owner lock time. */
        uint ownerLockTime = lockInterval.add(block.number);

        /* Validate debt power. */
        if (_debtPower == 0 || _debtPower > ownerLockTime) {
            revert('Oops! You entered an INVALID debt power.');
        }

        /* Calculate provider lock time. */
        uint providerLockTime = ownerLockTime.div(_debtPower);

        /* Initialize staekhouse. */
        Staekhouse memory staekhouse = Staekhouse({
            token: _token,
            owner: msg.sender,
            ownerLockTime: ownerLockTime,
            providerLockTime: providerLockTime,
            debtLimit: _debtLimit,
            lockInterval: lockInterval,
            balance: uint(0)
        });

        /* Add new staekhouse. */
        _staekhouses[staekhouseId] = staekhouse;

        /* Set location. */
        _zer0netDb.setAddress(staekhouseId, address(this));

        /* Set block number. */
        _zer0netDb.setUint(staekhouseId, block.number);

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
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

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
        staekhouse.balance = staekhouse.balance.add(_tokens);

        /* Broadcast event. */
        emit StaekUp(_staekhouseId, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Staek Down (Tokens Decrease)
     *
     * NOTE: Transfers occur exclusively via the ZeroCache wallet.
     */
    function staekDown(
        bytes32 _staekhouseId,
        uint _tokens
    ) external returns (uint staek) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _staekhouseId,
            '.balance'
        ));

        /* Retrieve value from Zer0net Db. */
        staek = _zer0netDb.getUint(hash);

        /* Validate staek balance. */
        if (staek < _tokens) {
            revert('Oops! You DO NOT have enough staek.');
        }

        /* Re-calculate staek. */
        staek = staek.sub(_tokens);

        /* Set value to Zer0net Db. */
        _zer0netDb.setUint(hash, staek);

        /* Retrieve staekhouse token. */
        address token = _staekhouses[_staekhouseId].token;

        /* Transfer the ERC-20 tokens back to owner. */
        // NOTE: This is performed last to prevent re-entry attack.
        _zeroCache().transfer(
            msg.sender,
            token,
            _tokens
        );
    }

    /**
     * Owner Renewal
     */
    function ownerRenewal(
        bytes32 _staekhouseId
    ) external returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

        /* Validate owner. */
        if (msg.sender != staekhouse.owner) {
            revert('Oops! You are NOT authorized here.');
        }

        /* Calculate new owner lock time. */
        uint newOwnerLockTime = staekhouse.ownerLockTime
            .add(staekhouse.lockInterval);

        /* Set updated lock time. */
        _setOwnerTTL(_staekhouseId, newOwnerLockTime);

        /* Broadcast event. */
        emit Renewal(_staekhouseId, msg.sender);

        /* Return success. */
        return true;
    }

    /**
     * Provider Renewal
     */
    function providerRenewal(
        bytes32 _staekhouseId
    ) external onlyTokenManager(_staekhouseId) returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

        /* Calculate new provider lock time. */
        uint newProviderLockTime = staekhouse.providerLockTime
            .add(staekhouse.lockInterval);

        /* Set updated lock time. */
        _setProviderTTL(_staekhouseId, newProviderLockTime);

        /* Broadcast event. */
        emit Renewal(_staekhouseId, msg.sender);

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
    ) external onlyStaekhouseOwner(_staekhouseId) view returns (
        bool success
    ) {
        /* Return success. */
        return true;
    }

    /**
     * Withdraw
     */
    function withdraw(
        bytes32 _staekhouseId,
        uint _tokens
    ) external returns (bool success) {
        /* Return success. */
        return true;
    }

    /**
     * Collect Debt
     */
    function collectDebt(
        bytes32 _staekhouseId,
        uint _tokens
    ) external onlyTokenManager(_staekhouseId) returns (bool success) {
        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * (Get) Balance Of
     */
    function balanceOf(
        bytes32 _staekhouseId
    ) public view returns (uint balance) {
        /* Retrieve staekhouse. */
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve balance. */
        balance = staekhouse.balance;
    }

    /**
     * Get Staekhouse (Metadata)
     *
     * Retrieves the location and block number of the bin data
     * stored for the specified `_staekhouseId`.
     *
     * NOTE: DApps can then read the `Staeking` event from the Ethereum
     *       Event Log, at the specified point, to recover the stored metadata.
     */
    function _getStaekhouse(
        bytes32 _staekhouseId
    ) private view returns (
        address location,
        uint blockNum
    ) {
        /* Retrieve location. */
        location = _zer0netDb.getAddress(_staekhouseId);

        /* Retrieve block number. */
        blockNum = _zer0netDb.getUint(_staekhouseId);
    }

    /**
     * Get Owner Time-To-Live
     *
     * Block number to re-enable owner's access to execute on-chain,
     * staekhouse commands.
     */
    function getOwnerTTL(
        bytes32 _staekhouseId
    ) public view returns (uint ttl) {
        /* Retrieve staekhouse. */
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve TTL. */
        ttl = staekhouse.ownerLockTime;
    }

    /**
     * Get Provider Time-To-Live
     *
     * Block number to re-enable provider's access to execute on-chain,
     * staekhouse commands.
     */
    function getProviderTTL(
        bytes32 _staekhouseId
    ) public view returns (uint ttl) {
        /* Retrieve staekhouse. */
        Staekhouse memory staekhouse = _staekhouses[_staekhouseId];

        /* Retrieve TTL. */
        ttl = staekhouse.providerLockTime;
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
     * Set Owner Time-To-Live
     *
     * Set the block number for the owner's next TTL.
     */
    function _setOwnerTTL(
        bytes32 _staekhouseId,
        uint _lockTime
    ) private returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Set TTL. */
        staekhouse.ownerLockTime = _lockTime;

        /* Return success. */
        return true;
    }

    /**
     * Set Provider Time-To-Live
     *
     * Set the block number for the service provider's next TTL.
     */
    function _setProviderTTL(
        bytes32 _staekhouseId,
        uint _lockTime
    ) private returns (bool success) {
        /* Retrieve staekhouse. */
        Staekhouse storage staekhouse = _staekhouses[_staekhouseId];

        /* Set TTL. */
        staekhouse.providerLockTime = _lockTime;

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
