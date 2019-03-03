pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroDelta - ZeroCache (DEX) Decentralized Exchange.
 *
 * Version 19.3.1
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
    function transfer(address _token, address _from, address _to, uint _tokens, address _staekholder, uint _staek, uint _expires, uint _nonce, bytes _signature) external returns (bool success);
}


/*******************************************************************************
 *
 * @notice ZeroDelta
 *
 * @dev Decentralized Exchange (DEX) exclusively for use with ZeroCache.
 */
contract ZeroDelta is Owned {
    using SafeMath for uint;

    /* Initialize predecessor contract. */
    address private _predecessor;

    /* Initialize successor contract. */
    address private _successor;

    /* Initialize revision number. */
    uint private _revision;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /**
     * Orders
     *
     * Map of MAKER accounts, which then maps on-chain orders
     * to their authorized signatures.
     *
     * Since the exchange relies exclusively on ZeroCache as its
     * token repository, two (2) signatures are required to
     * successfully complete a trade:
     *
     *     1. Order Signature - validates the authority given for
     *        the parameters of the trade.
     *
     *     2. Transfer Signature - validates the authority given for
     *        a ZeroCache token transfer, after an order has been
     *        matched with a TAKER.
     */
    mapping (address => mapping (bytes32 => bytes)) private _orders;

    /**
     * Order Fills
     *
     * Mapping of user accounts to mapping of order hashes to uints.
     *
     * NOTE: Amount of order that has been filled.
     */
    mapping (address => mapping (bytes32 => uint)) private _orderFills;

    /* Set maximum order expiration time. */
    uint private _MAX_ORDER_EXPIRATION = 10000;

    event Cancel(
        bytes32 indexed market,
        address maker,
        address tokenGet,
        uint amountGet,
        address tokenGive,
        uint amountGive,
        uint expires,
        uint nonce
    );

    event Order(
        bytes32 indexed market,
        address maker,
        address tokenGet,
        uint amountGet,
        address tokenGive,
        uint amountGive,
        uint expires,
        uint nonce
    );

    event Trade(
        bytes32 indexed market,
        address maker,
        address taker,
        address staekholder,
        uint staek,
        address tokenGet,
        uint amountGet,
        address tokenGive,
        uint amountGive
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Set predecessor address. */
        _predecessor = 0x0;

        /* Verify predecessor address. */
        if (_predecessor != 0x0) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = ZeroDelta(_predecessor).getRevision();

            /* Set (current) revision number. */
            _revision = lastRevision + 1;
        }

        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        // _zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);
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
     * (On-chain) Order
     *
     * Allows a market maker to place a new trade request on-chain.
     *
     * NOTE: Required to support fully decentralized (no 3rd-party)
     *       token transactions.
     */
    function order(
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce
    ) external {
        /* Initialize (market) maker. */
        address maker = msg.sender;

        /* Validate expires. */
        if (_expires > block.number.add(_MAX_ORDER_EXPIRATION)) {
            revert('Oops! You entered an INVALID expiration.');
        }

        /* Initailize expiration. */
        uint expiration = 0;

        /* Set expiration. */
        if (_expires == 0) {
            /* Auto-set to max value. */
            expiration = block.number.add(_MAX_ORDER_EXPIRATION);
        } else {
            expiration = _expires;
        }

        /* Initailize nonce. */
        uint nonce = 0;

        /* Set nonce. */
        if (_nonce == 0) {
            /* Auto-set to current timestamp (seconds since unix epoch). */
            nonce = block.timestamp;
        } else {
            nonce = _nonce;
        }

        /* Calculate order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            expiration,
            nonce
        ));

        /* Set order (exists) flag. */
        _orders[maker][orderHash] = true;

        /* Initialize market. */
        bytes32 market = keccak256(abi.encodePacked(
            _tokenGet, _tokenGive));

        /* Broadcast event. */
        emit Order(
            market,
            maker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            expiration,
            nonce
        );
    }

    /**
     * Cancel (On-chain) Order
     *
     * Allows market makers to discontinue a previously placed
     * on-chain order.
     *
     * NOTE: This procedure disables an active order by FILLING
     *       the available volume to the order's FULL capacity;
     *       thereby reducing the avaiable trade volume to ZERO.
     */
    function cancelOrder(
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        bytes _makerSig
    ) external {
        /* Initialize (market) maker. */
        address maker = msg.sender;

        /* Calculate order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        /* Retrieve authorized maker. */
        address authorizedMaker =
            _ecRecovery().recover(keccak256(abi.encodePacked(
                '\x19Ethereum Signed Message:\n32', orderHash)),
                _makerSig
            );

        /* Validate maker signature. */
        if (authorizedMaker != maker) {
            revert('Oops! Your request is NOT authorized.');
        }

        /* Validate order. */
        if (!_orders[maker][orderHash]) {
            revert('Oops! That order DOES NOT exist.');
        }

        /* Fill order. */
        // NOTE: Removes the availability of ALL tokens for trade.
        _orderFills[maker][orderHash] = _amountGet;

        /* Initialize market. */
        bytes32 market = keccak256(abi.encodePacked(
            _tokenGet, _tokenGive));

        /* Broadcast event. */
        emit Cancel(
            market,
            maker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        );
    }

    /**
     * (On-chain <> On-chain) Trade Simulation
     *
     * Validates each of the trade/order parameters and returns a
     * success value, based on the result of an "actual" trade
     * occuring on the network at that (current block) time.
     *
     * NOTE: A successful result DOES NOT guarantee that the trade
     *       will be successful in subsequent blocks (as available
     *       volumes can change due to external token activites).
     */
    function tradeSimulation(
        address _maker,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        uint _amount,
        bytes _signature
    ) external view returns (bool success) {
        /* Initialize success. */
        success = true;

        /* Retrieve available (on-chain) volume. */
        uint availableVolume = getAvailableVolume(
            _maker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        );

        /* Validate available (on-chain) volume. */
        if (_amount > availableVolume) {
            return false;
        }
    }

    /**
     * (On-chain <> On-chain) Trade
     *
     * Executed 100% on-chain by both the MAKER and TAKER,
     * which allows for a FULLY decentralized trade experience.
     *
     * 1. Maker creates an on-chain `order` request, specifying
     *    their desired trade parameters.
     *
     * 2. Taker executes an on-chain transaction to fill any available
     *    volume from the maker's active order.
     *
     * NOTE: The is the MOST inefficient, timely, and costly of all the
     *       available trade procedures. However, this trade option
     *       WILL ALWAYS serve as the exchange's DEFAULT recommendation,
     *       as it requires ZERO intervention from ANY centralized
     *       (or 3rd-party) service(s); guaranteeing the MAXIMUM safety
     *       and security to both the maker and taker of the transaction.
     */
    function trade(
        address _maker,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        uint _amount
    ) external returns (bool success) {
        /* Initialize taker. */
        address taker = msg.sender;

        /* Retrieve available volume. */
        uint availableVolume = getAvailableVolume(
            _maker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        );

        /* Validate available (trade) volume. */
        if (_amount > availableVolume) {
            revert('Oops! Amount requested EXCEEDS available volume.');
        }

        /* Calculate order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        /* Validate order. */
        if (!_orders[_maker][orderHash]) {
            revert('Oops! That order DOES NOT exist.');
        }

        /* Add volume to reduce remaining order availability. */
        _orderFills[_maker][orderHash] =
            _orderFills[_maker][orderHash].add(_amount);

        /* Request atomic trade. */
        _trade(
            _maker,
            taker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _amount
        );

        /* Return success. */
        return true;
    }

    /**
     * (On-chain <> Off-chain) RELAYED | MARKET Trade
     *
     * Allows for ETH-less on-chain order fulfillment for takers.
     */
    function trade(
        address _maker,
        address _taker,
        bytes _takerSig,
        address _staekholder,
        uint _staek,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce,
        uint _amount
    ) external returns (bool success) {
        /* Retrieve available volume. */
        uint availableVolume = getAvailableVolume(
            _maker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        );

        /* Validate available (trade) volume. */
        if (_amount > availableVolume) {
            revert('Oops! Amount requested EXCEEDS available volume.');
        }

        /* Calculate order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        /* Validate maker. */
        bytes32 makerSig = keccak256(abi.encodePacked(
            '\x19Ethereum Signed Message:\n32', orderHash));

        /* Calculate trade hash. */
        bytes32 tradeHash = keccak256(abi.encodePacked(
            _maker,
            orderHash,
            _staekholder,
            _staek,
            _amount
        ));

        /* Validate maker. */
        bytes32 takerSig = keccak256(abi.encodePacked(
            '\x19Ethereum Signed Message:\n32', tradeHash));

        /* Retrieve authorized taker. */
        address authorizedTaker = _ecRecovery().recover(
            takerSig, _takerSig);

        /* Validate taker. */
        if (authorizedTaker != _taker) {
            revert('Oops! Taker signature is NOT valid.');
        }

        /* Add volume to reduce remaining order availability. */
        _orderFills[_maker][orderHash] =
            _orderFills[_maker][orderHash].add(_amount);

        /* Request atomic trade. */
        _trade(
            _maker,
            _taker,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _amount
        );

        /* Return success. */
        return true;
    }

    /**
     * (Off-chain <> Off-chain) Trade
     *
     * Utilizes a CENTRALIZED order book to manage off-chain trades.
     *
     * 1. Maker provides a signed `orderHash` along with desired
     *    order/trade parameters.
     *
     * 2. Taker provides a signed `tradeHash` along with desired
     *    trade/fulfillment parameters.
     */
    function trade(
        address _maker,
        bytes _makerSig,
        address _taker,
        bytes _takerSig,
        address _staekholder,
        uint _staek,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _amountTaken,
        uint _expires,
        uint _nonce
    ) external returns (bool success) {
        /* Calculate order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        /* Validate maker. */
        bytes32 makerSig = keccak256(abi.encodePacked(
            '\x19Ethereum Signed Message:\n32', orderHash));

        /* Retrieve authorized maker. */
        address authorizedMaker = _ecRecovery().recover(
            makerSig, _makerSig);

        /* Validate maker. */
        if (authorizedMaker != _maker) {
            revert('Oops! Maker signature is NOT valid.');
        }

        /* Calculate trade hash. */
        bytes32 tradeHash = keccak256(abi.encodePacked(
            _maker,
            orderHash,
            _staekholder,
            _staek,
            _amountTaken
        ));

        /* Validate maker. */
        bytes32 takerSig = keccak256(abi.encodePacked(
            '\x19Ethereum Signed Message:\n32', tradeHash));

        /* Retrieve authorized taker. */
        address authorizedTaker = _ecRecovery().recover(
            takerSig, _takerSig);

        /* Validate taker. */
        if (authorizedTaker != _taker) {
            revert('Oops! Taker signature is NOT valid.');
        }

        /* Request atomic trade. */
        _trade(
            _maker,
            _makerSig,
            _taker,
            _takerSig,
            _staekholder,
            _staek,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _amountTaken,
            _expires,
            _nonce
        );

        /* Return success. */
        return true;
    }

    /**
     * (Off-chain <> Off-chain) RELAYED | MARKET Trade
     *
     * Allows a taker to fill an order at the BEST market price.
     *
     * NOTE: This will support the ability to execute MULTIPLE
     *       trades (on a taker's behalf), while insuring that
     *       the authorized staekholder is limited in the volume
     *       they can trade (on a taker's behalf).
     */
    // function trade(
    //     address _maker,
    //     bytes _makerSig,
    //     address _taker,
    //     bytes _takerSig,
    //     address _staekholder,
    //     uint _staek,
    //     address _tokenGet,
    //     uint _amountGet,
    //     address _tokenGive,
    //     uint _amountGive,
    //     uint _amountTaken,
    //     uint _expires,
    //     uint _nonce
    // ) external returns (bool success) {
    //     /* Validate boost fee and pay (if necessary). */
    //     // if (_staekholder != 0x0 && _staek > 0) {
    //     //     _addStaek(_taker, _staekholder, _staek);
    //     // }

    //     /* Request OFF-CHAIN <> OFF-CHAIN trade. */
    //     trade(
    //         _maker,
    //         _makerSig,
    //         _taker,
    //         _takerSig,
    //         _staekholder,
    //         _staek,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _amountTaken,
    //         _expires,
    //         _nonce
    //     );

    //     /* Return success. */
    //     return true;
    // }

    /**
     * (Atomic) Trade
     *
     * Executes an atomic trade between the maker and taker.
     */
    function _trade(
        address _maker,
        bytes _makerSig,
        address _taker,
        bytes _takerSig,
        address _staekholder,
        uint _staek,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _amountTaken,
        uint _expires,
        uint _nonce
    ) private returns (bool success) {
        /* Calculate the (payment) amount for MAKER. */
        uint paymentAmount = _amountGive.mul(_amountTaken).div(_amountGet);

        /* Transer tokens to MAKER. */
        // WARNING Do this BEFORE TAKER transfer to safeguard against
        // a re-entry attack.
        _zeroCache().transfer(
            _tokenGet,
            _taker,
            _maker,
            paymentAmount,
            _staekholder,
            _staek,
            _expires,
            _nonce,
            _takerSig
        );

        /* Transfer tokens to TAKER. */
        // WARNING This MUST be the LAST transfer to safeguard against
        // a re-entry attack.
        _zeroCache().transfer(
            _tokenGive,
            _maker,
            _taker,
            _amountTaken,
            _staekholder,
            _staek,
            _expires,
            _nonce,
            _makerSig
        );

        /* Initialize market. */
        bytes32 market = keccak256(abi.encodePacked(
            _tokenGet, _tokenGive));

        /* Broadcast event. */
        emit Trade(
            market,
            _maker,
            _taker,
            _staekholder,
            _staek,
            _tokenGet,
            _amountTaken,
            _tokenGive,
            paymentAmount
        );

        /* Return success. */
        return true;
    }


    /***************************************************************************
     *
     * GETTERS
     *
     */

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

    /**
     * Get Amount Filled
     *
     * Returns the remaining balance available for on-chain trading.
     */
    function getAmountFilled(
        address _maker,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce
    ) external view returns (uint filled) {
        /* Calculate order hash. */
        bytes32 orderHash = keccak256(abi.encodePacked(
            this,
            _tokenGet,
            _amountGet,
            _tokenGive,
            _amountGive,
            _expires,
            _nonce
        ));

        /* Retrieve filled. */
        filled = _orderFills[_maker][orderHash];
    }

    /**
     * Get Available (Order) Volume
     */
    function getAvailableVolume(
        address _maker,
        address _tokenGet,
        uint _amountGet,
        address _tokenGive,
        uint _amountGive,
        uint _expires,
        uint _nonce
    ) public view returns (uint balance) {
        /* Validate expiration. */
        if (block.number > _expires) {
            balance = 0;
        } else {
            /* Calculate order hash. */
            bytes32 orderHash = keccak256(abi.encodePacked(
                this,
                _tokenGet,
                _amountGet,
                _tokenGive,
                _amountGive,
                _expires,
                _nonce
            ));

            /* Retrieve maker balance from ZeroCache. */
            uint makerBalance = _zeroCache().balanceOf(_tokenGive, _maker);

            /* Calculate order (trade) balance. */
            uint orderBalance = _amountGet.sub(_orderFills[_maker][orderHash]);

            /* Calculate maker (trade) balance. */
            uint tradeBalance = makerBalance.mul(_amountGet).div(_amountGive);

            /* Validate available balance. */
            if (orderBalance < tradeBalance) {
                balance = orderBalance;
            } else {
                balance = tradeBalance;
            }
        }
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
        /* Initailze hash. */
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
        /* Initailze hash. */
        bytes32 hash = keccak256('aname.zerocache');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        zeroCache = ZeroCacheInterface(aname);
    }

    /**
     * ZeroGold Interface
     *
     * Retrieves the current ZeroGold interface,
     * using the aname record from Zer0netDb.
     */
    function _zeroGold() private view returns (
        ERC20Interface zeroGold
    ) {
        /* Initailze hash. */
        // NOTE: ERC tokens are case-sensitive.
        bytes32 hash = keccak256('aname.0GOLD');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        zeroGold = ERC20Interface(aname);
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
