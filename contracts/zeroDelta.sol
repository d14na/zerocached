pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroDelta - ZeroCache (DEX) Decentralized Exchange.
 *
 * Version 19.2.15
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
 * ZeroCache Interface
 */
contract ZeroCacheInterface {
    function transfer(
        address sender,
        address receiver,
        address token,
        uint256 tokens
    ) public returns (bool success);

    function transfer(
        address sender,
        address receiver,
        address token,
        uint256 tokens,
        uint256 nonce,
        bytes signature
    ) public returns (bool);

    function multiTransfer(
        address sender,
        address[] receiver,
        address[] token,
        uint256[] tokens
    ) public returns (bool success);

    function multiTransfer(
        address sender,
        address[] receiver,
        address[] token,
        uint256[] tokens,
        uint256[] nonce,
        bytes signature
    ) public returns (bool);
}


/*******************************************************************************
 *
 * @notice ZeroDelta
 *
 * @dev Decentralized Exchange (DEX) exclusively for use with ZeroCache.
 */
contract ZeroDelta is Owned {
    using SafeMath for uint;

    /* Initialize version name. */
    string public version;

    /* Initialize predecessor contract. */
    address public predecessor;

    /* Initialize successor contract. */
    address public successor;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /**
     * Orders
     *
     * Mapping of user accounts to mapping of order hashes to booleans.
     *
     * NOTE: true = submitted by user, equivalent to offchain signature
     */
    mapping (address => mapping (bytes32 => bool)) private _orders;

    /**
     * Order Fills
     *
     * Mapping of user accounts to mapping of order hashes to uints.
     *
     * NOTE: Amount of order that has been filled.
     */
    mapping (address => mapping (bytes32 => uint)) private _orderFills;

    event Cancel(
        address tokenGet,
        uint amountGet,
        address tokenGive,
        uint amountGive,
        uint expires,
        uint nonce,
        address user
    );

    event Order(
        address tokenGet,
        uint amountGet,
        address tokenGive,
        uint amountGive,
        uint expires,
        uint nonce,
        address user
    );

    event Trade(
        address tokenGet,
        uint amountGet,
        address tokenGive,
        uint amountGive,
        address get,
        address give
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
            abi.encodePacked(msg.sender, '.has.auth.for.zerodelta'))) == true);

        _;      // function code is inserted here
    }

    /**
     * Order
     */
    function order(
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce
    ) external {
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        _orders[msg.sender][orderHash] = true;

        emit Order(
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce,
            msg.sender
        );
    }

    /**
     * Cancel Order
     */
    function cancelOrder(
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        bytes _signature
    ) external {
        bytes32 hash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        if (!(
            _orders[msg.sender][hash] ||
            ECRecovery.recover(keccak256(abi.encodePacked(
                '\x19Ethereum Signed Message:\n32',
                hash
            )), _signature) == msg.sender)
        ) {
            revert('Oops!');
        }

        _orderFills[msg.sender][hash] = _amountGet;

        emit Cancel(
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce,
            msg.sender
        );
    }

    /**
     * Trade
     */
    function trade(
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        address _user,
        uint _amount,
        bytes _orderSignature,
        address _wallet
    ) external {
        /* Calculate encoded order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        bytes32 expectedSigHash = keccak256(abi.encodePacked(
            '\x19Ethereum Signed Message:\n32', orderHash));

        address recoveredSignatureSigner = ECRecovery.recover(
            expectedSigHash, _orderSignature);

        if (!(
            // NOTE: There is an on-chain order or an off-chain order.
            (_orders[_user][orderHash] || recoveredSignatureSigner == _user) &&
            block.number <= _expires &&
            _orderFills[_user][orderHash].add(_amount) <= _amountGet
        )) {
            revert('Oops!');
        }

        _trade(
            _wallet,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _user,
            _amount,
            orderHash
        );
    }

    /**
     * Trade
     */
    function _trade(
        address _wallet,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        address _user,
        uint _amount,
        bytes32 _orderHash
    ) private {
        /* Update order fills. */
        // WARNING Do this FIRST to safeguard against re-entry attack on the transfers below.
        _orderFills[_user][_orderHash] = _orderFills[_user][_orderHash].add(_amount);

        /* Calculate the (payment) amount for "maker". */
        uint paymentAmount = _amountGive.mul(_amount).div(_amountGet);

        /* Transer tokens to "maker". */
        // WARNING Do this BEFORE "taker" transfer to safeguard against a re-entry attack.
        if (!ZeroCacheInterface(_wallet).transfer(
            msg.sender,
            _user,
            _tokenGet,
            _amount
        )) {
            revert('Oops!');
        }

        /* Transfer tokens to "taker". */
        // WARNING This MUST be the LAST transfer to safeguard against a re-entry attack.
        if (!ZeroCacheInterface(_wallet).transfer(
            _user,
            msg.sender,
            _tokenGive,
            paymentAmount
        )) {
            revert('Oops!');
        }

        emit Trade(
            _tokenGet,
            _amount,
            _tokenGive,
            paymentAmount,
            _user,
            msg.sender
        );
    }

    /**
     * (Get) Amount Filled
     */
    function amountFilled(
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        address _user
    ) external view returns (uint) {
        bytes32 hash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        return _orderFills[_user][hash];
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
