pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * StaekFactory - Staek(house) Factory for ERC-20 Staek(-ing) Management
 *
 *                Token Managers with ZeroCache support for their tokens can
 *                create a new staekhouse to hold and manage their
 *                ERC20-compatible tokens.
 *
 * Version 19.3.19
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
 * @notice Staek(house) Factory
 *
 * @dev Allows token managers with ZeroCache compatability for their tokens to
 *      creates individual staekhouses. Staekhouses allow your users to staek
 *      your token for use with:
 *          - Premium Service Offerings
 *          - Access Restrictions
 *          - Voting & Governance
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
     * Initialize Staekhouse
     *
     * token - Any ERC20-compatible token.
     * lockInterval - Time for owners and providers to wait
     *                between transfers.
     * owner - The token manager.
     * ownerLockTime - Places a limit on the owner's "first"
     *                 withdrawal.
     * providerDebitLimit - limits debit amount (per debit cycle)
     * providerDebitRate - limits debit percentage (per debit cycle)
     * providerLockTime - debit (transfer) wait cycle
     */
    struct Staekhouse {
        address token;
        address owner;
        uint ownerLockTime;
        uint providerDebitLimit;
        uint providerDebitRate;
        uint providerLockTime;
        uint lockInterval;
    }

    /* Initialize balances. */
    mapping(bytes32 => mapping(address => uint)) private _balances;

    /* Initialize staekhouses. */
    mapping(bytes32 => Staekhouse) private _staekhouses;

    /* Initialize default lock interval. */
    // NOTE: 1,000 blocks is approximately 4 hours.
    uint _DEFAULT_LOCK_INTERVAL = 1000;

    /* Initialize maximum lock interval. */
    // NOTE: 17,250 blocks is approximately 72 hours.
    uint _MAX_LOCK_INTERVAL = 17250;

    /* Initialize minimum lock interval. */
    // NOTE: 20 blocks is approximately 5 minutes.
    uint _MIN_LOCK_INTERVAL = 20;

    /* Initialize default blocks per generation. */
    // FIXME this is temporary FOR DEV
    uint _TEMP_BLOCKS_PER_GENERATION = 144;

    event Added(
        bytes32 staekhouseId,
        address token
    );

    event Migrate(
        bytes32 staekhouseId
    );

    event Renewal(
        bytes32 indexed staekhouseId,
        address owner
    );

    event StaekUp(
        bytes32 indexed staekhouseId,
        address owner,
        uint tokens
    );

    event StaekDown(
        bytes32 indexed staekhouseId,
        address owner,
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
    modifier onlyStaekhouseAuth(
        bytes32 _staekhouseId,
        address _authorized
    ) {
        /* Validate authorized address. */
        require(_zer0netDb.getBool(keccak256(abi.encodePacked(
            _authorized, '.has.auth.for.', _staekhouseId))) == true);

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
     * Token managers can create and manage a new staekhouse
     * exclusively for their ERC20-compatible token.
     *
     * Taxable Staekhouses
     * -------------------
     *
     * Token managers may DEBIT staeked tokens from owners, if the
     * `_allowDebit` flag is set to true. All DEBITs made are recorded
     * to the Ethereum Event Log.
     */
    function addStaekhouse(
        address _token,
        uint _lockInterval,
        uint _debitLimit,
        uint _debitRate
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

        /* Initialize lock time. */
        uint lockTime = lockInterval.add(block.number);

        /* Initialize staekhouse. */
        Staekhouse memory staekhouse = Staekhouse({
            token: _token,
            owner: msg.sender,
            ownerLockTime: lockTime,
            providerDebitLimit: _debitLimit,
            providerDebitRate: _debitRate,
            providerLockTime: lockTime,
            lockInterval: lockInterval
        });

        /* Add new staekhouse. */
        _staekhouses[staekhouseId] = staekhouse;

        /* Broadcast event. */
        emit Added(staekhouseId, _token);
    }

    /**
     * Remove Staekhouse
     *
     * NOTE: Staekhouses are currently permanent, therefore
     *       this function is un-implemented.
     */
    // function _removeStaekhouse(bytes32 _staekhouseId);

    /**
     * Set Authorized (User / Contract)
     *
     * NOTE: Restricted to the Staekhouse owner ONLY.
     */
    function setAuth(
        bytes32 _staekhouseId,
        address _authorized,
        bool _auth
    ) external returns (bool success) {
        // FIXME Must validate staekhouse OWNER ONLY.

        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _authorized, '.has.auth.for.', _staekhouseId));

        /* Set value to Zer0net Db. */
        _zer0netDb.setBool(hash, _auth);

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
        uint _tokens
    ) external returns (uint staek) {
        /* Retrieve token. */
        address token = _staekhouses[_staekhouseId].token;

        /* Return staek. */
        return _staekUp(_staekhouseId, token, msg.sender, _tokens);
    }

    /**
     * Receive Approval
     *
     * Will typically be called from `approveAndCall`.
     */
    function receiveApproval(
        address _from,
        uint _tokens,
        address _token,
        bytes _data
    ) public returns (bool success) {
        /* Validate that we have 32 bytes for the staekhouse id. */
        if (_data.length != 32) {
            revert('Oops! Please provide a valid staekhouse id.');
        }

        /* Retrieve the staekhouse id from the (data) payload. */
        bytes32 staekhouse = _bytesToBytes32(_data);

        /* Credit owner's staek for staekhouse id. */
        _staekUp(staekhouse, _token, _from, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Staek Up (Tokens Increase)
     *
     * NOTE: Transfers occur exclusively via the ZeroCache wallet.
     */
    function _staekUp(
        bytes32 _staekhouseId,
        address _token,
        address _owner,
        uint _tokens
    ) private returns (uint staek) {
        /* Update time-to-live. */
        // FIXME Pull blocks per generation from LIVE CONTRACT??
        _setTTL(_staekhouseId, _TEMP_BLOCKS_PER_GENERATION);

        /* Retrieve staekhouse token. */
        address token = _staekhouses[_staekhouseId].token;

        /* Validate token. */
        // NOTE: Used to validate `receiveApproval`.
        if (token != _token) {
            revert('Oops! That token is NOT supported in this staekhouse.');
        }

        // FIXME Restrict token transfer from ZeroCache wallet.

        /* Transfer the ERC-20 tokens into Staek(house) Factory. */
        // NOTE: This is performed first to prevent re-entry attack.
        ERC20Interface(token).transferFrom(
            _owner,
            address(this),
            _tokens
        );

        /* Initialize hash. */
        bytes32 hash;

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _owner,
            '.staek.for.',
            _staekhouseId
        ));

        /* Retrieve value from Zer0net Db. */
        staek = _zer0netDb.getUint(hash);

        /* Re-calculate staek. */
        staek = staek.add(_tokens);

        /* Set value to Zer0net Db. */
        _zer0netDb.setUint(hash, staek);

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _staekhouseId,
            '.total.staek'
        ));

        /* Retrieve value from Zer0net Db. */
        staek = _zer0netDb.getUint(hash);

        /* Re-calculate staek. */
        staek = staek.add(_tokens);

        /* Set value to Zer0net Db. */
        _zer0netDb.setUint(hash, staek);
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
        /* Update time-to-live. */
        // FIXME Pull blocks per generation from LIVE CONTRACT??
        _setTTL(_staekhouseId, _TEMP_BLOCKS_PER_GENERATION);

        /* Initialize hash. */
        bytes32 hash;

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _namespace, '.',
            msg.sender,
            '.staek.for.',
            _staekhouseId
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

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _staekhouseId,
            '.total.staek'
        ));

        /* Retrieve value from Zer0net Db. */
        staek = _zer0netDb.getUint(hash);

        /* Re-calculate staek. */
        staek = staek.sub(_tokens);

        /* Set value to Zer0net Db. */
        _zer0netDb.setUint(hash, staek);

        /* Retrieve staekhouse token. */
        address token = _staekhouses[_staekhouseId].token;

        // FIXME Restrict token transfer to ZeroCache wallet.

        /* Transfer the ERC-20 tokens back to owner. */
        // NOTE: This is performed last to prevent re-entry attack.
        ERC20Interface(token).transferFrom(
            address(this),
            msg.sender,
            _tokens
        );
    }

    /**
     * Staek Renewal
     */
    function staekRenewal(
        bytes32 _staekhouseId
    ) external returns (bool success) {
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


    /***************************************************************************
     *
     * GETTERS
     *
     */

    /**
     * (Get) Balance Of
     */
    function balanceOf(
        bytes32 _staekhouseId,
        address _owner
    ) public view returns (uint balance) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _owner,
            '.staek.for.',
            _staekhouseId
        ));

        /* Retrieve value from Zer0net Db. */
        balance = _zer0netDb.getUint(hash);
    }

    /**
     * Get Time-To-Live
     *
     * Block number to re-enable owner's access to execute on-chain,
     * staek'd Minado commands.
     */
    function getTTL(
        bytes32 _staekhouseId,
        address _owner
    ) public view returns (uint ttl) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _staekhouseId, '.',
            _owner,
            '.ttl'
        ));

        /* Retrieve value from Zer0net Db. */
        ttl = _zer0netDb.getUint(hash);
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
     * Set Time-To-Live
     *
     * Set the block number for the owner's next TTL.
     */
    function _setTTL(
        bytes32 _staekhouseId,
        uint _blocksPerGeneration
    ) private returns (uint ttl) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _namespace, '.',
            _staekhouseId, '.',
            msg.sender,
            '.ttl'
        ));

        /* Set TTL. */
        ttl = block.number + _blocksPerGeneration;

        /* Set value in Zer0net Db. */
        _zer0netDb.setUint(hash, ttl);
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
