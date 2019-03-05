pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroDelta - The Official ZeroCache (DEX) Decentralized Exchange
 *
 *             This is the first non-custodial blockchain exchange. ALL tokens
 *             are held securely in ZeroCache; and require authorized signatures
 *             of both the MAKER and TAKER for ANY and ALL token transfers.
 *
 * Version 19.3.4
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
     * Order Structure
     *
     * Stores the MAKER's desired trade parameters; along with their
     * ZeroCache transfer signature.
     *
     * NOTE: Transfer Signatures are required to move ANY funds within
     * the ZeroCache that come from a 3rd-party.
     */
    struct Order {
        address maker;
        bytes makerSig;
        address tokenRequest;
        uint amountRequest;
        address tokenOffer;
        uint amountOffer;
        uint expires;
        uint nonce;
        bool canPartialFill;
        uint amountFilled;
    }

    /**
     * Orders
     */
    mapping (bytes32 => Order) private _orders;

    /* Maximum order expiration time. */
    // NOTE: 10,000 blocks = ~1 3/4 days
    uint private _MAX_ORDER_EXPIRATION = 10000;

    event OrderCancel(
        bytes32 indexed marketId,
        bytes32 orderId
    );

    event OrderRequest(
        bytes32 indexed marketId,
        bytes32 orderId
    );

    event TradeComplete(
        bytes32 indexed marketId,
        bytes32 orderId,
        address taker,
        uint amountTaken
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
     * Allows a MARKET MAKER to place a new trade request on-chain.
     *
     * The maker's authorization signature is also stored on-chain,
     * which is required when fulfilling an order for a TAKER.
     *
     * Due to the "abolsute" security design of the ZeroCache; partial
     * fills can ONLY be supported by supplying 2x the order volume,
     * until the entire order has been FILLED. MAKERs can enable/disable
     * partial fills, by setting a flag.
     *
     * NOTE: Required to support fully decentralized (no 3rd-party)
     *       token transactions.
     */
    function createOrder(
        address _tokenRequest,
        uint _amountRequest,
        address _tokenOffer,
        uint _amountOffer,
        uint _expires,
        uint _nonce,
        bytes _makerSig,
        bool _canPartialFill
    ) external returns (bool success) {
        /* Initialize (market) maker. */
        address maker = msg.sender;

        /* Create new order request. */
        bytes32 orderId = _createOrderRequest(
            maker,
            _tokenRequest,
            _amountRequest,
            _tokenOffer,
            _amountOffer,
            _expires,
            _nonce
        );

        /* Build order. */
        Order memory order = Order(
            maker,
            _makerSig,
            _tokenRequest,
            _amountRequest,
            _tokenOffer,
            _amountOffer,
            _getExpiration(_expires),
            _getNonce(_nonce),
            _canPartialFill,
            0
        );

        /* Save order to storage. */
        _orders[orderId] = order;

        /* Retrieve market. */
        bytes32 marketId = _getMarket(_tokenRequest, _tokenOffer);

        /* Broadcast event. */
        emit OrderRequest(
            marketId,
            orderId
        );

        /* Return success. */
        return true;
    }

    /**
     * Create Order Request
     *
     * Will validate all parameters and return a new order id.
     *
     * NOTE: Order Id creation follows the scheme common in DEXs
     *       (eg. EtherDelta / ForkDelta).
     */
    function _createOrderRequest(
        address _maker,
        address _tokenRequest,
        uint _amountRequest,
        address _tokenOffer,
        uint _amountOffer,
        uint _expires,
        uint _nonce
    ) private view returns (bytes32 orderId) {
        /* Retrieve maker balance from ZeroCache. */
        uint makerBalance = _zeroCache().balanceOf(_tokenOffer, _maker);

        /* Validate MAKER token balance. */
        if (_amountOffer > makerBalance) {
            revert('Oops! Maker DOES NOT have enough tokens.');
        }

        /* Calculate order id. */
        orderId = keccak256(abi.encodePacked(
            address(this),
            _tokenRequest,
            _amountRequest,
            _tokenOffer,
            _amountOffer,
            _getExpiration(_expires),
            _getNonce(_nonce)
        ));
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
    // function cancelOrder(
    //     address _tokenGet,
    //     uint _amountGet,
    //     address _tokenGive,
    //     uint _amountGive,
    //     uint _expires,
    //     uint _nonce,
    //     bytes _transferSig
    // ) external {
    //     /* Initialize (market) maker. */
    //     address maker = msg.sender;

    //     /* Calculate transfer hash. */
    //     bytes32 transferHash = keccak256(abi.encodePacked(
    //         address(_zeroCache()),
    //         _tokenGive,
    //         maker,
    //         address(this),
    //         _tokens,
    //         _staekholder,
    //         _staek,
    //         _expires,
    //         _nonce
    //     ));

    //     /* Calculate order hash. */
    //     bytes32 orderHash = keccak256(abi.encodePacked(
    //         address(this),
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     ));

    //     /* Retrieve authorized maker. */
    //     address authorizedMaker =
    //         _ecRecovery().recover(keccak256(abi.encodePacked(
    //             '\x19Ethereum Signed Message:\n32', orderHash)),
    //             _makerSig
    //         );

    //     /* Validate maker signature. */
    //     if (authorizedMaker != maker) {
    //         revert('Oops! Your request is NOT authorized.');
    //     }

    //     /* Validate order. */
    //     if (!_orders[maker][orderHash]) {
    //         revert('Oops! That order DOES NOT exist.');
    //     }

    //     /* Fill order. */
    //     // NOTE: Removes the availability of ALL tokens for trade.
    //     _orderFills[maker][orderHash] = _amountGet;

    //     /* Initialize market. */
    //     bytes32 market = keccak256(abi.encodePacked(
    //         _tokenGet, _tokenGive));

    //     /* Broadcast event. */
    //     emit Cancel(
    //         market,
    //         maker,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     );
    // }

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
    // function tradeSimulation(
    //     address _maker,
    //     address _tokenGet,
    //     uint _amountGet,
    //     address _tokenGive,
    //     uint _amountGive,
    //     uint _expires,
    //     uint _nonce,
    //     uint _amount,
    //     bytes _signature
    // ) external view returns (bool success) {
    //     /* Initialize success. */
    //     success = true;

    //     /* Retrieve available (on-chain) volume. */
    //     uint availableVolume = getAvailableVolume(
    //         _maker,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     );

    //     /* Validate available (on-chain) volume. */
    //     if (_amount > availableVolume) {
    //         return false;
    //     }
    // }

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
    // function trade(
    //     address _maker,
    //     address _tokenGet,
    //     uint _amountGet,
    //     address _tokenGive,
    //     uint _amountGive,
    //     uint _expires,
    //     uint _nonce,
    //     uint _amount
    // ) external returns (bool success) {
    //     /* Initialize taker. */
    //     address taker = msg.sender;

    //     /* Retrieve available volume. */
    //     uint availableVolume = getAvailableVolume(
    //         _maker,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     );

    //     /* Validate available (trade) volume. */
    //     if (_amount > availableVolume) {
    //         revert('Oops! Amount requested EXCEEDS available volume.');
    //     }

    //     /* Calculate order hash. */
    //     bytes32 orderHash = keccak256(abi.encodePacked(
    //         address(this),
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     ));

    //     /* Validate order. */
    //     if (!_orders[_maker][orderHash]) {
    //         revert('Oops! That order DOES NOT exist.');
    //     }

    //     /* Add volume to reduce remaining order availability. */
    //     _orderFills[_maker][orderHash] =
    //         _orderFills[_maker][orderHash].add(_amount);

    //     /* Request atomic trade. */
    //     _trade(
    //         _maker,
    //         taker,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _amount
    //     );

    //     /* Return success. */
    //     return true;
    // }

    /**
     * (On-chain <> Off-chain) RELAYED | MARKET Trade
     *
     * Allows for ETH-less on-chain order fulfillment for takers.
     */
    // function trade(
    //     address _maker,
    //     address _taker,
    //     bytes _takerSig,
    //     address _staekholder,
    //     uint _staek,
    //     address _tokenGet,
    //     uint _amountGet,
    //     address _tokenGive,
    //     uint _amountGive,
    //     uint _expires,
    //     uint _nonce,
    //     uint _amount
    // ) external returns (bool success) {
    //     /* Retrieve available volume. */
    //     uint availableVolume = getAvailableVolume(
    //         _maker,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     );

    //     /* Validate available (trade) volume. */
    //     if (_amount > availableVolume) {
    //         revert('Oops! Amount requested EXCEEDS available volume.');
    //     }

    //     /* Calculate order hash. */
    //     bytes32 orderHash = keccak256(abi.encodePacked(
    //         address(this),
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     ));

    //     /* Validate maker. */
    //     bytes32 makerSig = keccak256(abi.encodePacked(
    //         '\x19Ethereum Signed Message:\n32', orderHash));

    //     /* Calculate trade hash. */
    //     bytes32 tradeHash = keccak256(abi.encodePacked(
    //         _maker,
    //         orderHash,
    //         _staekholder,
    //         _staek,
    //         _amount
    //     ));

    //     /* Validate maker. */
    //     bytes32 takerSig = keccak256(abi.encodePacked(
    //         '\x19Ethereum Signed Message:\n32', tradeHash));

    //     /* Retrieve authorized taker. */
    //     address authorizedTaker = _ecRecovery().recover(
    //         takerSig, _takerSig);

    //     /* Validate taker. */
    //     if (authorizedTaker != _taker) {
    //         revert('Oops! Taker signature is NOT valid.');
    //     }

    //     /* Add volume to reduce remaining order availability. */
    //     _orderFills[_maker][orderHash] =
    //         _orderFills[_maker][orderHash].add(_amount);

    //     /* Request atomic trade. */
    //     _trade(
    //         _maker,
    //         _taker,
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _amount
    //     );

    //     /* Return success. */
    //     return true;
    // }

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
    //     /* Calculate order hash. */
    //     bytes32 orderHash = keccak256(abi.encodePacked(
    //         address(this),
    //         _tokenGet,
    //         _amountGet,
    //         _tokenGive,
    //         _amountGive,
    //         _expires,
    //         _nonce
    //     ));

    //     /* Validate maker. */
    //     bytes32 makerSig = keccak256(abi.encodePacked(
    //         '\x19Ethereum Signed Message:\n32', orderHash));

    //     /* Retrieve authorized maker. */
    //     address authorizedMaker = _ecRecovery().recover(
    //         makerSig, _makerSig);

    //     /* Validate maker. */
    //     if (authorizedMaker != _maker) {
    //         revert('Oops! Maker signature is NOT valid.');
    //     }

    //     /* Calculate trade hash. */
    //     bytes32 tradeHash = keccak256(abi.encodePacked(
    //         _maker,
    //         orderHash,
    //         _staekholder,
    //         _staek,
    //         _amountTaken
    //     ));

    //     /* Validate maker. */
    //     bytes32 takerSig = keccak256(abi.encodePacked(
    //         '\x19Ethereum Signed Message:\n32', tradeHash));

    //     /* Retrieve authorized taker. */
    //     address authorizedTaker = _ecRecovery().recover(
    //         takerSig, _takerSig);

    //     /* Validate taker. */
    //     if (authorizedTaker != _taker) {
    //         revert('Oops! Taker signature is NOT valid.');
    //     }

    //     /* Request atomic trade. */
    //     _trade(
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
     *
     * We TEMPORARILY transfer pre-authorized `amountGive` quantity
     * of the MAKER's tokens here from their ZeroCache; we fill
     * `amountTaken` of the TAKER's trade request; and then return the
     * unused balance (if any) back to the MAKER.
     *
     * NOTE: Due to limitations in ZeroCache design security; it is required
     *       that a MAKER keep 2x their `amountGive` to ensure the ability
     *       to fill their entire order volume.
     */
    function _trade(
        bytes32 _orderId,
        address _taker,
        bytes _takerSig,
        uint _amountTaken,
        address _staekholder,
        uint _staek
    ) private returns (bool success) {
        /* Retrieve order details. */
        (
            address maker,
            bytes memory makerSig,
            address tokenRequest,
            uint amountRequest,
            address tokenOffer,
            uint amountOffer,
            uint expires,
            uint nonce,
            bool canPartialFill,
            uint amountFilled
        ) = getOrder(_orderId);

        /* Validate permission to partial fill. */
        if (!canPartialFill && amountOffer != _amountTaken) {
            revert('Oops! You CANNOT partial fill this order.');
        }

        /* Calculate new fill amount. */
        uint newFillAmount = amountFilled.add(_amountTaken);

        /* Set amount filled. */
        _setAmountFilled(_orderId, newFillAmount);

        /* Calculate the (payment) amount for MAKER. */
        uint paymentAmount = amountOffer.mul(_amountTaken).div(amountRequest);

        /* Transer tokens from MAKER to ZeroDelta. */
        _zeroCache().transfer(
            tokenOffer,
            maker,
            address(this),
            amountOffer,
            address(0x0),
            0,
            expires,
            nonce,
            makerSig
        );

        /* Transfer unneeded balance back to MAKER. */
        if (amountOffer > _amountTaken) {
            _zeroCache().transfer(
                maker,
                tokenOffer,
                amountOffer.sub(_amountTaken)
            );
        }

        /* Transer (payment) tokens from TAKER to MAKER. */
        // WARNING Do this BEFORE TAKER transfer to safeguard against
        // a re-entry attack.
        // NOTE: Allows for a staekholder, to expedite the transfer.
        _zeroCache().transfer(
            tokenRequest,
            _taker,
            maker,
            paymentAmount,
            _staekholder,
            _staek,
            expires,
            nonce,
            _takerSig
        );

        /* Transfer tokens from ZeroDelta to TAKER. */
        // WARNING This MUST be the LAST transfer to safeguard against
        // a re-entry attack.
        // NOTE: This reduces ZeroDelta's token holdings back to ZERO.
        _zeroCache().transfer(
            _taker,
            tokenOffer,
            _amountTaken
        );

        /* Initialize market. */
        bytes32 market = keccak256(abi.encodePacked(
            tokenRequest, tokenOffer));

        /* Broadcast event. */
        emit TradeComplete(
            market,
            _orderId,
            _taker,
            _amountTaken
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
     * Get Market
     *
     * "Officially" Supported ZeroGold Markets
     * ---------------------------------------
     *
     * 1. 0GOLD / 0xBTC     ZeroGold / 0xBitcoin Token
     * 2. 0GOLD / DAI       ZeroGold / MakerDAO Dai
     * 3. 0GOLD / WBTC      ZeroGold / Wrapped Bitcoin
     * 4. 0GOLD / WETH      ZeroGold / Wrapped Ethereum
     *
     * "Officially" Supported MakerDAO Dai Markets
     * -------------------------------------------
     *
     * 1. 0GOLD / DAI               ZeroGold / MakerDAO Dai
     * 2. 0xBTC / DAI        0xBitcoin Token / MakerDAO Dai
     * 3.  WBTC / DAI        Wrapped Bitcoin / MakerDAO Dai
     * 4.  WETH / DAI       Wrapped Ethereum / MakerDAO Dai
     *
     * NOTE: ZeroGold will serve as the "official" base token.
     *       MakerDAO Dai will serve as the "official" quote token.
     */
    function _getMarket(
        address _tokenRequest,
        address _tokenOffer
    ) private view returns (bytes32 market) {
        /* Set DAI address. */
        address daiAddress = _dai();

        /* Set ZeroGold address. */
        address zgAddress = _zeroGold();

        /* Initialize base token. */
        address baseToken = 0x0;

        /* Initailize quote token. */
        address quoteToken = 0x0;

        /* Set ZeroGold as base token. */
        if (_tokenRequest == zgAddress || _tokenOffer == zgAddress) {
            baseToken = zgAddress;
        }

        /* Set ZeroGold as base token. */
        if (_tokenRequest == daiAddress || _tokenOffer == daiAddress) {
            quoteToken = daiAddress;
        }

        /* Validate market pair. */
        if (baseToken == 0x0 && quoteToken == 0x0) {
            revert('Oops! That market is NOT currently supported.');
        }

        // TODO Allow a Base Token to be set, in the case of a non-ZeroGold trade;
        //      however DAI is required to be pre-set as the quote token.

        /* Validate/set quote token. */
        if (quoteToken == 0x0) {
            if (baseToken == _tokenRequest) {
                quoteToken = _tokenOffer;
            } else {
                quoteToken = _tokenRequest;
            }
        }

        /* Validate/set base token. */
        if (baseToken == 0x0) {
            if (quoteToken == _tokenRequest) {
                baseToken = _tokenOffer;
            } else {
                baseToken = _tokenRequest;
            }
        }

        /* Calculate market id. */
        market = keccak256(abi.encodePacked(
            baseToken, quoteToken));
    }

    /**
     * Get Order
     *
     * Retrieves the FULL details of an order.
     */
    function getOrder(
        bytes32 _orderId
    ) public view returns (
        address maker,
        bytes makerSig,
        address tokenRequest,
        uint amountRequest,
        address tokenOffer,
        uint amountOffer,
        uint expires,
        uint nonce,
        bool canPartialFill,
        uint amountFilled
    ) {
        /* Retrieve order. */
        Order memory order = _orders[_orderId];

        /* Retrieve maker. */
        maker = order.maker;

        /* Retrieve maker signature. */
        makerSig = order.makerSig;

        /* Retrieve token requested. */
        tokenRequest = order.tokenRequest;

        /* Retrieve amount requested. */
        amountRequest = order.amountRequest;

        /* Retrieve token offered. */
        tokenOffer = order.tokenOffer;

        /* Retrieve amount offered. */
        amountOffer = order.amountOffer;

        /* Retrieve expiration. */
        expires = order.expires;

        /* Retrieve nonce. */
        nonce = order.nonce;

        /* Retrieve partial fill flag. */
        canPartialFill = order.canPartialFill;

        /* Retrieve amount (has been) filled. */
        amountFilled = order.amountFilled;
    }

    /**
     * Get Available (Order) Volume
     */
    function getAvailableVolume(
        bytes32 _orderId
    ) public view returns (uint availableVolume) {
        /* Retrieve order. */
        (
            address maker,
            bytes memory makerSig,
            address tokenRequest,
            uint amountRequest,
            address tokenOffer,
            uint amountOffer,
            uint expires,
            uint nonce,
            bool canPartialFill,
            uint amountFilled
        ) = getOrder(_orderId);

        /* Validate expiration. */
        if (block.number > expires) {
            availableVolume = 0;
        } else {
            /* Retrieve maker balance from ZeroCache. */
            uint makerBalance = _zeroCache().balanceOf(tokenOffer, maker);

            /* Calculate order (trade) balance. */
            uint orderBalance = amountRequest.sub(amountFilled);

            /* Calculate maker (trade) balance. */
            uint tradeBalance = makerBalance.mul(amountRequest).div(amountOffer);

            /* Validate available volume. */
            if (orderBalance < tradeBalance) {
                availableVolume = orderBalance;
            } else {
                availableVolume = tradeBalance;
            }
        }
    }

    /**
     * Get Expiration
     */
    function _getExpiration(
        uint _expires
    ) private view returns (uint expiration) {
        /* Validate expiration. */
        if (_expires > block.number.add(_MAX_ORDER_EXPIRATION)) {
            revert('Oops! You entered an INVALID expiration.');
        }

        /* Set expiration. */
        if (_expires == 0) {
            /* Auto-set to max value. */
            expiration = block.number.add(_MAX_ORDER_EXPIRATION);
        } else {
            expiration = _expires;
        }
    }

    /**
     * Get Nonce
     */
    function _getNonce(
        uint _nonce
    ) private view returns (uint nonce) {
        /* Set nonce. */
        if (_nonce == 0) {
            /* Auto-set to current timestamp (seconds since unix epoch). */
            nonce = block.timestamp;
        } else {
            nonce = _nonce;
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

    /**
     * Set (Volume) Amount Filled
     */
    function _setAmountFilled(
        bytes32 _orderId,
        uint _amountFilled
    ) private returns (bool success) {
        /* Set fill amount. */
        _orders[_orderId].amountFilled = _amountFilled;
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
     * MakerDAO DAI Interface
     *
     * Retrieves the current DAI interface,
     * using the aname record from Zer0netDb.
     */
    function _dai() private view returns (
        ERC20Interface dai
    ) {
        /* Initailze hash. */
        // NOTE: ERC tokens are case-sensitive.
        bytes32 hash = keccak256('aname.DAI');

        /* Retrieve value from Zer0net Db. */
        address aname = _zer0netDb.getAddress(hash);

        /* Initialize interface. */
        dai = ERC20Interface(aname);
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
     * Convert Bytes to Bytes32
     */
    function _bytesToBytes32(
        bytes _data,
        uint _offset
    ) private pure returns (bytes32 result) {
        /* Loop through each byte. */
        for (uint i = 0; i < 32; i++) {
            /* Shift bytes onto result. */
            result |= bytes32(_data[i + _offset] & 0xFF) >> (i * 8);
        }
    }

    /**
     * Bytes-to-Address
     *
     * Converts bytes into type address.
     */
    function _bytesToAddress(
        bytes _address
    ) private pure returns (address) {
        uint160 m = 0;
        uint160 b = 0;

        for (uint8 i = 0; i < 20; i++) {
            m *= 256;
            b = uint160(_address[i]);
            m += (b);
        }

        return address(m);
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
