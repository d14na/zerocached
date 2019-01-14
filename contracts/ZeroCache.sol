pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroCache - (AmTrust) is the very first installment to the experimental
 *             meta-currency/smart wallet contract/daemon powering the
 *             nascent community of Zer0net-sponsored products & services.
 *
 * Version 19.1.13
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


//wEth interface
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

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface public zer0netDb;

    /* Initialize Wrapped ETH contract. */
    WrapperInterface public wethContract;

    /**
     * In-Use
     *
     * Has this cache ever been used by this account?
     */
    mapping(address => bool) inUse;

    /**
     * Balances
     *
     * Account balances.
     */
    mapping(address => mapping (address => uint256)) balances;

     //like orderFills in lavadex..
     //how much of the offchain sig approval has been 'drained' or used up
     /* mapping (address => mapping (bytes32 => uint)) public signatureApprovalDrained; //mapping of user accounts to mapping of order hashes to uints (amount of order that has been filled) */


    // deprecated
    mapping(bytes32 => uint256) burnedSignatures;


    event Deposit(
        address indexed token,
        address owner,
        uint tokens,
        bytes data
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

        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);

        /* Initialize Wrapped ETH contract. */
        // NOTE We hard-code the address here, since it should never change.
        // wethContract = WrapperInterface(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // MAINNET
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

    // send Ether into this method, it gets wrapped and then deposited in this contract as a token balance assigned to the sender
    function wrap() public payable {
        /* Forward this payable ether into the wrapping contract. */
        wethContract.deposit.value(msg.value);

        /* Transfer the tokens from the wrapping contract to here. */
        // wethContract.transfer(address(this), msg.value);

        /* Increase WETH balance by sent value. */
        balances[address(wethContract)][msg.sender] = balances[address(wethContract)][msg.sender].add(msg.value);

        /* Initialize empty data (for event log). */
        bytes memory data;

        /* Record to event log. */
        emit Deposit(address(wethContract), msg.sender, msg.value, data);
    }

    function test(uint _tokens) public {
        wethContract.deposit.value(_tokens);
    }
    function test2(uint _tokens) payable public {
        wethContract.deposit.value(_tokens);
    }
    function test3(uint _tokens) public {
        // wethContract.transfer(address(this), _tokens);
        address(wethContract).call.gas(200000).value(_tokens);
    }
    function test4(uint _tokens) payable public {
        wethContract.deposit.gas(200000).value(_tokens);
    }
    function test5(uint _tokens) payable public returns (bool) {
        return address(wethContract).call.gas(1000000).value(_tokens)(abi.encodeWithSignature("deposit()"));
    }

    function unwrap(uint256 _tokens) public {
        _unwrap(msg.sender, _tokens);
    }

    function unwrap(address _owner, uint256 _tokens) onlyAuthBy0Admin public {
        _unwrap(_owner, _tokens);
    }

    /**
     * Unwrap
     *
     * When this contract has control of wrapped eth, this is a way to easily
     * withdraw it as ether if there is any Ether in the contract.
     */
    function _unwrap(address _owner, uint256 _tokens) private {
        /* Decrease WETH balance by sent value. */
        balances[address(wethContract)][_owner] = balances[address(wethContract)][_owner].sub(_tokens);

        /* Withdraw ETH from Wrapper contract. */
        wethContract.withdraw(_tokens);

        /* Transfer "unwrapped" Ether (ETH) back to owner. */
        msg.sender.transfer(_tokens);

        /* Record to event log. */
        emit Withdraw(
            address(wethContract),
            address(_owner),
            _tokens
        );
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
    ) public returns (bool) {
        return deposit(_from, _tokens, _token, _data);
    }

    /**
     * Deposit
     *
     * NOTE: This function requires pre-approval from the token
     *       contract for the amount requested.
     */
    function deposit(
        address _from,
        uint _tokens,
        address _token,
        bytes _data
    ) public returns (bool success) {
        /* Transfer the ERC-20 tokens into Cache. */
        ERC20Interface(_token).transferFrom(_from, address(this), _tokens);

        /* Increase the owner's cache balance. */
        balances[_token][_from] = balances[_token][_from].add(_tokens);

        /* Record to event log. */
        emit Deposit(_token, _from, _tokens, _data);

        /* Return success. */
        return true;
    }

    function withdraw(address _token, uint _tokens) public returns (bool) {
        if (balances[_token][msg.sender] < _tokens) revert();

        balances[_token][msg.sender] = balances[_token][msg.sender].sub(_tokens);

        ERC20Interface(_token).transfer(msg.sender, _tokens);

        emit Withdraw(_token, msg.sender, _tokens);

        return true;
    }


    /***************************************************************************
     *
     * Get the token balance for account `tokenOwner`
     */
    function balanceOf(
        address _token,
        address _owner
    ) public constant returns (uint) {
        return balances[_token][_owner];
    }

    /**
     * Transfer
     *
     * Transfers the "specified" ERC-20 tokens held by the sender
     * to the receiver's account.
     */
    function transfer(
        address _from,
        address _token,
        uint _tokens
    ) public returns (bool success) {
        /* Remove the transfer value from sender's balance. */
        balances[_token][msg.sender] = balances[_token][msg.sender].sub(_tokens);

        /* Add the transfer value to the receiver's balance. */
        balances[_token][_from] = balances[_token][_from].add(_tokens);

        /* Report the transfer. */
        emit Transfer(_token, msg.sender, _from, _tokens);

        /* Return success. */
        return true;
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
