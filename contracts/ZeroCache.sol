pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroCache - (AmTrust) is the first installment of an experimental
 *             meta-currency/smart wallet (backed by a federated network of
 *             contract/daemon nodes) powering the nascent community of
 *             Zer0net-sponsored products & services.
 *
 * Version 19.1.15
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
 * WrapperInterface
 *
 * Contract function to receive approval and execute function in one call
 * (borrowed from MiniMeToken)
 */
contract WrapperInterface {
    function() public payable;
    function deposit() public payable ;
    function withdraw(uint wad) public;
    function totalSupply() public view returns (uint);
    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(address src, address dst, uint wad) public returns (bool);

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);
}

/*******************************************************************************
 *
 * ECRecovery
 *
 * Contract function to validate signature of pre-approved token transfers.
 * (borrowed from LavaWallet)
 */
library ECRecovery {
    /**
     * @dev Recover signer address from a message by using their signature
     *
     * @param hash bytes32 The hash of the signed message.
     * @param sig bytes The signature generated using web3.eth.sign().
     */
    function recover(bytes32 hash, bytes sig) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // NOTE: Check the signature length.
        if (sig.length != 65) {
            return (address(0));
        }

        // NOTE: Divide the signature in r, s and v variables.
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        // NOTE: Version of signature should be 27 or 28,
        //       but 0 and 1 are also possible versions.
        if (v < 27) {
            v += 27;
        }

        // NOTE: If the version is correct, return the signer address.
        if (v != 27 && v != 28) {
            return (address(0));
        } else {
            return ecrecover(hash, v, r, s);
        }
    }
}


/*******************************************************************************
 *
 * @notice ZeroCache DOES NOT HOLD ANY "OFFICIAL" AFFILIATION with ZeroNet Core,
 *         ZeroNet.io nor any of its brands and affiliates.
 *
 *         ZeroCache IS THE "OFFICIAL" META-CURRENCY OF THE GROWING COMMUNITY
 *         OF ZER0NET-SPONSORED PRODUCTS AND SERVICES.
 *
 * @dev In conjunction with the ZeroCache Daemon, this contract manages the
 *      ability to dynamically allocate the assets of a "smart" crypto wallet,
 *      in real-time, based  on a user's pre-selected financial profile.
 *
 *      Initial support for the following cryptos:
 *          - Ethereum (ETH)   : Virtual machine gas/fuel
 *          - MakerDAO (DAI)   : Stable coin
 *          - ZeroGold (0GOLD) : Staek token
 */
contract ZeroCache is Owned {
    using SafeMath for uint;

    /* Initialize version name. */
    string public version;

    /* Initialize predecessor contract. */
    address public predecessor;

    /* Initialize successor contract. */
    address public successor;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface public zer0netDb;

    /* Initialize Wrapped ETH contract. */
    WrapperInterface public wethContract;

    /* Initialize account balances. */
    mapping(address => mapping (address => uint256)) balances;

    /* Initialize expired signature flags. */
    mapping(bytes32 => bool) expiredSignatures;

    event Deposit(
        address indexed token,
        address owner,
        uint tokens,
        bytes data
    );

    event Sweep(
        address indexed token,
        address owner,
        uint tokens
    );

    event Transfer(
        address indexed token,
        address sender,
        address receiver,
        uint tokens
    );

    event Withdraw(
        address indexed token,
        address owner,
        uint tokens
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Set the version name. */
        version = 'AmTrust.v1';

        /* Set the predecessor contract. */
        predecessor = 0x0;

        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);

        /* Initialize Wrapped ETH contract. */
        // NOTE We hard-code the address here, since it should never change.
        // wethContract = WrapperInterface(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        wethContract = WrapperInterface(0xc778417E063141139Fce010982780140Aa0cD5Ab); // ROPSTEN
    }

    /**
     * @dev Only allow access to an authorized Zer0net administrator.
     */
    modifier onlyAuthBy0Admin() {
        /* Verify write access is only permitted to authorized accounts. */
        require(zer0netDb.getBool(keccak256(
            abi.encodePacked(msg.sender, '.has.auth.for.cache'))) == true);

        _;      // function code is inserted here
    }

    /***************************************************************************
     *
     * Get the token balance for account `tokenOwner`
     */
    function balanceOf(
        address _token,
        address _owner
    ) external constant returns (uint) {
        return balances[_token][_owner];
    }

    /**
     * Fallback (default)
     *
     * Accepts direct ETH transfers to be wrapped for owner into one of the
     * canonical Wrapped ETH contracts:
     *     - Mainnet : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
     *     - Ropsten : 0xc778417E063141139Fce010982780140Aa0cD5Ab
     *     - Kovan   : 0xd0A1E359811322d97991E03f863a0C30C2cF029C
     *     - Rinkeby : 0xc778417E063141139Fce010982780140Aa0cD5Ab
     * (source https://blog.0xproject.com/canonical-weth-a9aa7d0279dd)
     */
    function () public payable {
        /* DO NOT (re-)wrap incoming ETH from Wrapped ETH contract. */
        if (msg.sender != address(wethContract)) {
            _wrap();
        }
    }

    /**
     * Wrap
     *
     * Send Ether into this method. It gets wrapped and then deposited
     * in this contract as a token balance assigned to the sender.
     */
    function wrap() external payable returns (bool success) {
        return _wrap();
    }

    /**
     * Wrap (private)
     */
    function _wrap() private returns (bool) {
        /* Forward this payable ether into the wrapping contract. */
        bool success = address(wethContract).call
            .gas(200000)
            .value(msg.value)
            (abi.encodeWithSignature("deposit()"));

        /* Increase WETH balance by sent value. */
        balances[address(wethContract)][msg.sender] = balances[address(wethContract)][msg.sender].add(msg.value);

        /* Initialize empty data (for event log). */
        bytes memory data;

        /* Record to event log. */
        emit Deposit(address(wethContract), msg.sender, msg.value, data);

        return success;
    }

    /**
     * Unwrap
     */
    function unwrap(
        uint256 _tokens
    ) external returns (bool success) {
        return _unwrap(msg.sender, _tokens);
    }

    /**
     * Unwrap (Administrators ONLY)
     */
    function unwrap(
        address _owner,
        uint256 _tokens
    ) onlyAuthBy0Admin external returns (bool success) {
        return _unwrap(_owner, _tokens);
    }

    /**
     * Unwrap (private)
     *
     * When this contract has control of wrapped eth, this is a way to easily
     * withdraw it as ether if there is any Ether in the contract.
     */
    function _unwrap(
        address _owner,
        uint256 _tokens
    ) private returns (bool) {
        /* Decrease WETH balance by sent value. */
        balances[address(wethContract)][_owner] = balances[address(wethContract)][_owner].sub(_tokens);

        /* Withdraw ETH from Wrapper contract. */
        bool success = address(wethContract).call
            .gas(200000)
            (abi.encodeWithSignature("withdraw(uint256)", _tokens));

        /* Transfer "unwrapped" Ether (ETH) back to owner. */
        _owner.transfer(_tokens);

        /* Record to event log. */
        emit Withdraw(
            address(wethContract),
            address(_owner),
            _tokens
        );

        return success;
    }

    /**
     * Deposit
     *
     * Provides support for "manual" token deposits (from either a user
     * or a previous generation of ZeroCache sweeping its balance).
     *
     * NOTE: Required pre-allowance/approval is required in order
     *       to successfully complete the transfer.
     */
    function deposit(
        address _from,
        uint _tokens,
        address _token,
        bytes _data
    ) external returns (bool) {
        return _deposit(_from, _tokens, _token, _data);
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
    ) external returns (bool) {
        return _deposit(_from, _tokens, _token, _data);
    }

    /**
     * Deposit (private)
     *
     * NOTE: This function requires pre-approval from the token
     *       contract for the amount requested.
     */
    function _deposit(
        address _from,
        uint _tokens,
        address _token,
        bytes _data
    ) private returns (bool success) {
        /* Transfer the ERC-20 tokens into Cache. */
        ERC20Interface(_token).transferFrom(_from, address(this), _tokens);

        /* Increase the owner's cache balance. */
        balances[_token][_from] = balances[_token][_from].add(_tokens);

        /* Record to event log. */
        emit Deposit(_token, _from, _tokens, _data);

        /* Return success. */
        return true;
    }

    /**
     * Withdraw
     */
    function withdraw(
        address _token,
        uint _tokens
    ) external returns (bool success) {
        return _withdraw(msg.sender, _token, _tokens);
    }

    /**
     * Withdraw (Administrators ONLY)
     */
    function withdraw(
        address _owner,
        address _token,
        uint _tokens
    ) onlyAuthBy0Admin external returns (bool success) {
        return _withdraw(_owner, _token, _tokens);
    }

    /**
     * Withdraw (private)
     */
    function _withdraw(
        address _owner,
        address _token,
        uint _tokens
    ) private returns (bool success) {
        /* Validate available balance. */
        if (balances[_token][_owner] < _tokens) revert();

        /* Decrease owner's balanc by token amount. */
        balances[_token][_owner] = balances[_token][_owner].sub(_tokens);

        /* Transfer requested tokens to owner. */
        ERC20Interface(_token).transfer(_owner, _tokens);

        /* Record to event log. */
        emit Withdraw(_token, _owner, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Transfer
     *
     * Transfers the "specified" ERC-20 tokens held by the sender
     * to the receiver's account.
     */
    function transfer(
        address _to,
        address _token,
        uint _tokens
    ) external returns (bool success) {
        return _transfer(msg.sender, _to, _token, _tokens);
    }

    /**
     * Transfer
     *
     * NOTE: This transfer requires an off-chain (EC) signature,
     *       from the account holder, detailing the transaction.
     */
    function transfer(
        address _from,
        address _to,
        uint256 _tokens,
        address _token,
        uint256 _expires,
        uint256 _nonce,
        bytes _signature
    ) external returns (bool success) {
        /* Calculate the signature hash. */
        bytes32 sigHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n224",
            keccak256(abi.encodePacked(address(this))),
            keccak256(abi.encodePacked(_from)),
            keccak256(abi.encodePacked(_to)),
            keccak256(abi.encodePacked(_token)),
            keccak256(abi.encodePacked(_tokens)),
            keccak256(abi.encodePacked(_expires)),
            keccak256(abi.encodePacked(_nonce))
        ));

        /* Validate the expiration time. */
        if (block.number > _expires) revert();

        /* Validate signature expiration. */
        if (expiredSignatures[sigHash]) revert();

        /* Set expiration flag. */
        expiredSignatures[sigHash] = true;

        /* Retrieve the authorized account (address). */
        address authorizedAccount = ECRecovery.recover(sigHash, _signature);

        /* Validate the signer matches owner of the tokens. */
        if (_from != authorizedAccount) revert();

        /* Request token transfer. */
        return _transfer(_from, _to, _token, _tokens);
    }

    /**
     * Transfer (private)
     *
     * Transfers the "specified" ERC-20 tokens held by the sender
     * to the receiver's account.
     */
    function _transfer(
        address _sender,
        address _receiver,
        address _token,
        uint _tokens
    ) private returns (bool success) {
        /* Remove the transfer value from sender's balance. */
        balances[_token][_sender] = balances[_token][_sender].sub(_tokens);

        /* Add the transfer value to the receiver's balance. */
        balances[_token][_receiver] = balances[_token][_receiver].add(_tokens);

        /* Report the transfer. */
        emit Transfer(_token, _sender, _receiver, _tokens);

        /* Return success. */
        return true;
    }

    /**
     * Cancel
     *
     * Cancels a previously authorized/signed transfer request,
     * by invalidating the signature on-chain.
     */
    function cancel(
        address _to,
        uint256 _tokens,
        address _token,
        uint256 _expires,
        uint256 _nonce
    ) external returns (bool success) {
        /* Calculate the signature hash. */
        bytes32 sigHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            address(this),
            msg.sender,
            _to,
            _token,
            _tokens,
            _expires,
            _nonce
        ));

        /* Set expiration flag. */
        expiredSignatures[sigHash] = true;

        /* Return success. */
        return true;
    }

    /**
     * Sweep
     */
    function sweep(
        address _token,
        bool _preApproved
    ) external returns (bool success) {
        return _sweep(msg.sender, _token, _preApproved);
    }

    /**
     * Sweep (Administrators ONLY)
     */
    function sweep(
        address _owner,
        address _token,
        bool _preApproved
    ) onlyAuthBy0Admin external returns (bool success) {
        return _sweep(_owner, _token, _preApproved);
    }

    /**
     * Sweep (private)
     *
     * Allows for the full balance transfer of an individual token
     * from this instance into the latest instance of ZeroCache
     *
     * NOTE: Account value read from the Zer0net Db `zerocache.latest`.
     */
    function _sweep(
        address _owner,
        address _token,
        bool _preApproved
    ) private returns (bool success) {
        /* Retrieve available balance. */
        uint balance = balances[_token][_owner];

        /* Pull latest instance address from Zer0net Db. */
        address latestCache = zer0netDb.getAddress(
            keccak256('zerocache.latest'));

        /* Reduce owner's balance to zero. */
        // balances[_token][_owner] = 0;

        /* Initialize empty data (for event log). */
        bytes memory data;

        /* Transfer full balance to owner's account on the latest instance. */
        if (_preApproved) {
            ZeroCache(latestCache).deposit(_owner, balance, _token, data);
        } else {
            ApproveAndCallFallBack(_token).approveAndCall(_owner, balance, data);
        }

        // TODO If WETH, must first get allowance.

        /* Record to event log. */
        emit Sweep(_token, _owner, balance);

        /* Return success. */
        return true;
    }

    /**
     * Set Successor
     *
     * This is the contract address that replaced this current instnace.
     */
    function setSuccessor(
        address _successor
    ) onlyAuthBy0Admin external returns (bool success) {
        /* Set successor account. */
        successor = _successor;

        /* Return success. */
        return true;
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
    ) external onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
