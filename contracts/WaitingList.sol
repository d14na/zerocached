pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * WaitingList - Candidate tracking system with on-chain process management.
 *               Notification broadcasts of ALL events.
 *
 *               PLEASE NOTE:
 *               ------------
 *
 *               This a heavily biased scheme, where selection favor is 50/50
 *               given to the candidate with the largest staekholding.
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
 * @notice Waiting List is a semi-democratic, fully transparent, candidate
 *         review system.
 *
 * @dev Favor is given to the hightst bidder during selection process.
 */
contract WaitingList is Owned {
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
    string private _namespace = 'waiting.list';

    /* Initialize candidate statuses. */
    enum CandidateStatus {
        APPROVED,
        PENDING,
        ONHOLD,
        REJECTED
    }

    /**
     * Candidate Structure
     *
     * token     - ANY ZeroCache-integrated token.
     * manager   - Account of the "official" candidate manager.
     * balance   - Total amount of tokens currently STAEKed for this candidate.
     * balances  - Map of supporters individual STAEKs for this candidate.
     * status    - Current status of this candidate.
     * createdAt - Creation date/time of the candidate's request.
     */
    struct Candidate {
        address token;
        address manager;
        uint balance;
        mapping(address => uint) balances;
        CandidateStatus status;
        uint createdAt;
    }

    /* Initialize candidates. */
    mapping(bytes32 => Candidate) private _candidates;

    event Approved(
        bytes32 indexed candidateId,
        string comments
    );

    event CandidateAdded(
        bytes32 indexed candidateId,
        address _token,
        string application
    );

    event CandidateSelected(
        bytes32 candidateId,
        uint candidateIndex,
        bytes32[] candidates
    );

    event Rejected(
        bytes32 indexed candidateId,
        string reason
    );

    event SupportAdded(
        bytes32 indexed candidateId,
        address owner,
        uint tokens
    );

    event SupportShifted(
        bytes32 indexed candidateId,
        address owner,
        uint tokens
    );

    event SupportWithdrawn(
        bytes32 indexed candidateId,
        address owner,
        uint tokens
    );

    event Update(
        bytes32 indexed candidateId,
        string comments
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
            uint lastRevision = WaitingList(_predecessor).getRevision();

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
     * Add New Candidate
     *
     * NOTE: Currently the only Listing option that can be requested is for
     *       "official" inclusion to ZeroCache.
     */
    function addCandidate(
        address _manager,
        address _token,
        string _application
    ) external payable returns (bytes32 candidateId) {

        /* Set last block hash. */
        bytes32 lastBlockHash = blockhash(block.number - 1);

        /* Generate candidate id. */
        candidateId = keccak256(abi.encodePacked(
            _namespace, '.',
            msg.sender, '.',
            _token, '.',
            lastBlockHash
        ));

        /* Initialize candidate. */
        Candidate memory candidate = Candidate({
            token: _token,
            manager: _manager,
            balance: uint(0),
            status: CandidateStatus.PENDING,
            createdAt: block.timestamp
        });

        /* Add new candidate. */
        _candidates[candidateId] = candidate;

        /* Set location. */
        _zer0netDb.setAddress(candidateId, address(this));

        /* Set block number. */
        _zer0netDb.setUint(candidateId, block.number);

        /* Broadcast event. */
        emit CandidateAdded(
            candidateId,
            _token,
            _application
        );
    }

    /**
     * Select Next Candidate
     *
     * Chooses "randomly" from the provided pool of pre-qualified
     * candidates. Favor is given to the TOP STAEKholder, with a
     * 50/50 chance of being selected.
     */
    function selectNextCandidate(
        bytes32[] _prequalified
    ) external view returns (
        uint selectionIndex,
        uint favoriteIndex,
        uint randomPick,
        uint candidateIndex,
        bytes32 candidate
    ) {
        /* Retrieve last block number. */
        // NOTE: This is the MAX value we can calculate (eg. 7,106,968)
        uint lastBlockNum = block.number;

        /* Generate a hash of ALL pre-qualified candidates. */
        // NOTE: This hash is salted by last block number.
        bytes32 selectionHash = keccak256(abi.encodePacked(
            lastBlockNum, _prequalified));

        /* Calculate a random index. */
        // NOTE: This supposedly no longer works in v0.5.
        selectionIndex = uint(selectionHash);

        /* Retrieve number of pre-qualified candidates. */
        uint numCandidates = _prequalified.length;

        /* Calculate a random pick. */
        // NOTE: This selection excludes the TOP (STAEK) pick
        randomPick = (selectionIndex % (numCandidates - 1)) + 1;

        /* Generate a hash of ALL candidates. */
        // NOTE: This hash is salted by last block number.
        bytes32 favoriteHash = keccak256(abi.encodePacked(
            lastBlockNum + 1, _prequalified));

        /* Calculate a favorite (staek) index. */
        // NOTE: This supposedly no longer works in v0.5.
        favoriteIndex = uint(favoriteHash);

        /* Selection based on block number is EVEN or ODD. */
        if (favoriteIndex % 2 == 0) {
            // NOTE: Favor given to the TOP (STAEK) pick
            candidateIndex = 0;
        } else {
            // NOTE: Uses the randomly selected pick
            candidateIndex = randomPick;
        }

        /* Assign next candidate. */
        candidate = _prequalified[candidateIndex];

        // TODO Broadcast this event as a proof of transparency
        //      in selection process.

        /* Broadcast event. */
        // emit Candidate(
        //     candidate,
        //     candidateIndex,
        //     _candidatePool
        // );
    }

    /**
     * Add Support
     */
    function addSupport(
        bytes32 _candidateId,
        uint _tokens,
        address _staekholder,
        uint _staek,
        uint _expires,
        uint _nonce,
        bytes _signature
    ) external returns (bool success) {
        /* Retrieve candidate. */
        Candidate storage candidate = _candidates[_candidateId];

        /* Transfer the ERC-20 tokens into Waiting List account. */
        // NOTE: This is performed first to prevent re-entry attack.
        _zeroCache().transfer(
            candidate.token,
            msg.sender,
            address(this),
            _tokens,
            _staekholder,
            _staek,
            _expires,
            _nonce,
            _signature
        );

        /* Increase total candidate balance. */
        candidate.balance = candidate.balance.add(_tokens);

        /* Increase supporter's balance. */
        candidate.balances[msg.sender] =
            candidate.balances[msg.sender].add(_tokens);

        /* Broadcast event. */
        emit SupportAdded(_candidateId, msg.sender, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Shift Support
     */
    function shiftSupport(
        bytes32 _shiftFrom,
        bytes32 _shiftTo,
        uint _tokens
    ) external returns (bool success) {
        /* Retrieve SHIFT FROM candidate. */
        Candidate storage shiftFrom = _candidates[_shiftFrom];

        /* Retrieve SHIFT TO candidate. */
        Candidate storage shiftTo = _candidates[_shiftTo];

        /* Decrease SHIFT FROM total candidate balance. */
        shiftFrom.balance = shiftFrom.balance.sub(_tokens);

        /* Decrease SHIFT FROM supporter's balance. */
        shiftFrom.balances[msg.sender] =
            shiftFrom.balances[msg.sender].sub(_tokens);

        /* Increase SHIFT TO total candidate balance. */
        shiftTo.balance = shiftTo.balance.add(_tokens);

        /* Increase SHIFT TO supporter's balance. */
        shiftTo.balances[msg.sender] =
            shiftTo.balances[msg.sender].add(_tokens);

        /* Return success. */
        return true;
    }

    /**
     * Withdraw Support
     */
    function withdrawSupport(
        bytes32 _candidateId,
        uint _tokens
    ) external returns (bool success) {
        /* Retrieve candidate. */
        Candidate storage candidate = _candidates[_candidateId];

        /* Validate supporter's balance. */
        if (_tokens > candidate.balances[msg.sender]) {
            revert('Oops! You DO NOT have enough tokens.');
        }

        /* Decrease total candidate balance. */
        candidate.balance = candidate.balance.sub(_tokens);

        /* Decrease supporter's balance. */
        candidate.balances[msg.sender] =
            candidate.balances[msg.sender].sub(_tokens);

        /* Transfer the ERC-20 tokens to the original owner. */
        // NOTE: This is performed last to prevent re-entry attack.
        _zeroCache().transfer(
            msg.sender,
            candidate.token,
            _tokens
        );

        /* Broadcast event. */
        emit SupportWithdrawn(_candidateId, msg.sender, _tokens);

        /* Return success. */
        return true;
    }

    function approve(
        bytes32 _candidateId,
        string _comments
    ) external returns (bool success) {
        /* Broadcast event. */
        emit Approved(_candidateId, _comments);

        /* Return success. */
        return true;
    }

    function reject(
        bytes32 _candidateId,
        string _reason
    ) external returns (bool success) {
        /* Broadcast event. */
        emit Rejected(_candidateId, _reason);

        /* Return success. */
        return true;
    }

    function update(
        bytes32 _candidateId,
        string _comments
    ) external returns (bool success) {
        /* Broadcast event. */
        emit Update(_candidateId, _comments);

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
        bytes32 _candidateId
    ) public view returns (uint balance) {
        /* Retrieve candidate. */
        Candidate memory candidate = _candidates[_candidateId];

        /* Retrieve balance. */
        balance = candidate.balance;
    }

    /**
     * (Get) Balance Of
     */
    function balanceOf(
        bytes32 _candidateId,
        address _owner
    ) public view returns (uint balance) {
        /* Retrieve candidate. */
        Candidate storage candidate = _candidates[_candidateId];

        /* Retrieve balance. */
        balance = candidate.balances[_owner];
    }

    /**
     * Get Candidate (Metadata)
     *
     * Retrieves the location and block number of the bin data
     * stored for the specified `_candidateId`.
     *
     * NOTE: DApps can then read the `CandidateAdded` event from the Ethereum
     *       Event Log, at the specified point, to recover the stored metadata.
     */
    function getCandidate(
        bytes32 _candidateId
    ) external view returns (
        address location,
        uint blockNum
    ) {
        /* Retrieve location. */
        location = _zer0netDb.getAddress(_candidateId);

        /* Retrieve block number. */
        blockNum = _zer0netDb.getUint(_candidateId);
    }

    /**
     * Get Revision (Number)
     */
    function getRevision() public view returns (uint) {
        return _revision;
    }

    /**
     * Get Predecessor (Address)
     */
    function getPredecessor() public view returns (address) {
        return _predecessor;
    }

    /**
     * Get Successor (Address)
     */
    function getSuccessor() public view returns (address) {
        return _successor;
    }


    /***************************************************************************
     *
     * SETTERS
     *
     */

    /**
     * Set Successor
     *
     * This is the contract address that replaced this current instnace.
     */
    function setSuccessor(
        address _newSuccessor
    ) onlyAuthBy0Admin external returns (bool success) {
        /* Set successor contract. */
        _successor = _newSuccessor;

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
