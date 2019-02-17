pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * StaekFactory - Staek(house) Factory for ERC-20 Staek(-ing) Management
 *
 *                Token Managers can create a new staekhouse to house and manage
 *                their ERC20-compatible tokens.
 *
 * Version 19.2.17
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
 * @dev Creates individual staekhouses used for managing staeking
 *      of ERC-20 tokens.
 */
contract StaekFactory is Owned {
    using SafeMath for uint;

    /* Initialize version number. */
    uint public version;

    /* Initialize predecessor contract. */
    address public predecessor;

    /* Initialize successor contract. */
    address public successor;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    struct Staekhouse {
        bytes32 id;
        address owner;
        uint lockTime;
    }

    /* Initialize balances. */
    mapping(bytes32 => mapping(address => uint)) private _balances;

    event Example(
        address indexed primary,
        address secondary,
        bytes data
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        // zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);
        _zer0netDb = Zer0netDbInterface(0x4C2f68bCdEEB88764b1031eC330aD4DF8d6F64D6); // ROPSTEN
    }

    /**
     * @dev Only allow access to an authorized Zer0net administrator.
     */
    modifier onlyAuthBy0Admin() {
        /* Verify write access is only permitted to authorized accounts. */
        require(_zer0netDb.getBool(keccak256(
            abi.encodePacked(msg.sender, '.has.auth.for.staek.factory'))) == true);

        _;      // function code is inserted here
    }

    /**
     * (Get) Balance Of
     */
    function balanceOf(
        bytes32 _staekhouse,
        address _owner
    ) public view returns (uint balance) {
        /* Set balance. */
        balance = _balances[_staekhouse][_owner];
    }

    /**
     * Add Staekhouse
     *
     * Token managers can create and manage a new staekhouse
     * exclusively for their ERC20-compatible token.
     */
    function _addStaekhouse(
        address _token
    ) {

    }

    /**
     * Remove Staekhouse
     *
     * NOTE: Staekhouses are currently permanent, therefore
     *       this function is un-implemented.
     */
    // function _removeStaekhouse(bytes32 _staekhouse);

    /**
     * Add Authorized (User / Contract)
     *
     * NOTE: Restricted to the Staekhouse owner ONLY.
     */
    function _addAuth(
        bytes32 _staekhouse,
        address _authorized
    ) returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _authorized, '.has.auth.for.', _staekhouse));

        /* Return success. */
        return true;
    }

    /**
     * Remove Authorized (User / Contract)
     *
     * NOTE: Restricted to the Staekhouse owner ONLY.
     */
    function _removeAuth(
        bytes32 _staekhouse,
        address _authorized
    ) {

    }

    /**
     * Staek Up (Increase)
     *
     * NOTE: Transfers occur exclusively via the ZeroCache wallet.
     */
    function _StaekUp(
        bytes32 _staekhouse,
        uint _staekAmount
    ) private returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            msg.sender,
            '.staek.for.',
            _staekhouse
        ));

        /* Retrieve value from Zer0net Db. */
        uint currentStaek = _zer0netDb.getUint(hash);

        /* Update db. */
        _zer0netDb.setUint(hash, currentStaek.add(_staekAmount));

        /* Return success. */
        return true;
    }

    /**
     * Staek Down (Decrease)
     *
     * NOTE: Transfers occur exclusively via the ZeroCache wallet.
     */
    function _StaekDown(
        bytes32 _staekhouse,
        uint _staekAmount
    ) private returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            msg.sender,
            '.staek.for.',
            _staekhouse
        ));

        /* Retrieve value from Zer0net Db. */
        uint currentStaek = _zer0netDb.getUint(hash);

        /* Validate balance. */
        if (currentStaek < _staekAmount) {
            revert('Oops! You DO NOT have enough staek.');
        }

        /* Update db. */
        _zer0netDb.setUint(hash, currentStaek.sub(_staekAmount));

        /* Return success. */
        return true;
    }

    /**
     * Sweep
     *
     * Transfers total balance of an ERC-20 token to the latest
     * Staekhouse contract.
     *
     * NOTE: This MUST be executed by each individual token (manager),
     *       only when updating the contract address in their DApp.
     */
    function _sweep(
        bytes32 _staekhouse
    ) {

    }

    /**
     * THIS CONTRACT DOES NOT ACCEPT DIRECT ETHER
     */
    function () public payable {
        /* Cancel this transaction. */
        revert('Oops! Direct payments are NOT permitted here.');
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
        address tokenAddress, uint tokens
    ) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
