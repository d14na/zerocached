pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroPriceIndex - Management system for maintaining the trade prices of
 *                  ERC tokens & collectibles listed within ZeroCache.
 *
 * Version 19.2.9
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
 * @notice Zero(Cache) Price Index
 *
 * @dev Manages the current trade prices of ZeroCache tokens.
 */
contract ZeroPriceIndex is Owned {
    using SafeMath for uint;

    /* Initialize version number. */
    uint public version;

    /* Initialize predecessor contract. */
    address public predecessor;

    /* Initialize successor contract. */
    address public successor;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /* Initialize price update notifications. */
    event PriceUpdate(
        bytes32 indexed key,
        uint value
    );

    /* Initialize price list update notifications. */
    event PriceListUpdate(
        bytes32 indexed key,
        string ipfsPath
    );

    /**
     * Set Zero(Cache) Price Index namespaces
     *
     * NOTE: Keep all namespaces lowercase.
     */
    string private _NAMESPACE = 'zpi';

    /* Set Dai Stablecoin (trade pair) base. */
    string private _TRADE_PAIR_BASE = 'DAI';

    /**
     * Initialize Core Tokens
     *
     * NOTE: All tokens are traded against DAI Stablecoin.
     */
    string[3] _CORE_TOKENS = [
        'WETH',     // Wrapped Ether
        '0GOLD',    // ZeroGold
        '0xBTC'     // 0xBitcoin Token
    ];

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
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
            abi.encodePacked(msg.sender, '.has.auth.for.zero.price.index'))) == true);

        _;      // function code is inserted here
    }

    /**
     * Get Trade Price (Token)
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function tradePriceOf(
        string _token
    ) external view returns (uint price) {
        /* Initailze hash. */
        bytes32 hash = 0x0;

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.', _token, '.', _TRADE_PAIR_BASE
        ));

        /* Retrieve value from Zer0net Db. */
        price = _zer0netDb.getUint(hash);
    }

    /**
     * Get Trade Price (Collectible)
     *
     * NOTE: All trades are made against DAI stablecoin.
     *
     * An up-to-date trade price index of the TOP 100 collectibles
     * listed in the ZeroCache.
     * (the complete listing is available via IPFS, see below)
     */
    function tradePriceOf(
        address _token,
        uint _tokenId
    ) external view returns (uint price) {
        /* Initailze hash. */
        bytes32 hash = 0x0;

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.', _token, '.', _tokenId
        ));

        /* Retrieve value from Zer0net Db. */
        price = _zer0netDb.getUint(hash);
    }

    /**
     * Get Trade Price List
     *
     * An up-to-date trade price index of ZeroCache TOP 100:
     *     1. ERC-20 Tokens
     *     2. ERC-721 (Collectible) Tokens
     *
     * Also, returns the IPFS address to the complete
     * ERC-721 (Collectible) trade price listings.
     *
     * Available Price List Ids [sha3 db keys]:
     * (prefix = `zero.price.index.`)
     *     1. ...total          [0xe2b20bfa270d5ae6914affbea57c9c78b8ca2c6020cf8bcb373a4d93097969a0]
     *     2. ...erc20.total    [0xa8ab0d96095c3871d984acd8bbe0f67263a0fabf821c09d2baae6b972727d8d0]
     *     3. ...erc20.top100   [0x0e8851764d1b074fb508b60635b42f7b2007c58eee56283b91eeefde5bc944fa]
     *     4. ...erc20.top1000  [0x57eb960f29b2d1b79561466a35a50b3d0501417756d095c772a995f225623798]
     *     5. ...erc721.total   [0x4b23268c0b8c5b67112d701f5d2a18f4e1d89668acdc782132a3e51b35668a99]
     *     6. ...erc721.top100  [0xc186305c869bfdf5a0dede31bc2519c8ffaac0f53848cc6fe3c79863a1f53df2]
     *     7. ...erc721.top1000 [0xf1bbd36ce08a9d69e7c4f36953d20df111a3f9df9006aa9b0d0c3abd72f370ce]
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function tradePriceList(
        string _listId
    ) external view returns (string ipfsPath) {
        /* Initailze hash. */
        bytes32 hash = 0x0;

        /* Set hash. */
        hash = keccak256(abi.encodePacked('zero.price.index.', _listId));

        /* Validate list id. */
        if (hash == 0x0) {
            /* Default to `...total`. */
            hash = 0xe2b20bfa270d5ae6914affbea57c9c78b8ca2c6020cf8bcb373a4d93097969a0;
        }

        /* Retrieve value from Zer0net Db. */
        ipfsPath = _zer0netDb.getString(hash);
    }

    /**
     * Trade Price Summary
     *
     * Retrieves the trade prices for the TOP 100 tokens and collectibles.
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function tradePriceSummary() external view returns (uint[3] summary) {
        /* Initailze hash. */
        bytes32 hash = 0x0;

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.WETH.', _TRADE_PAIR_BASE
        ));

        /* Retrieve value from Zer0net Db. */
        summary[0] = _zer0netDb.getUint(hash);

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.0GOLD.', _TRADE_PAIR_BASE
        ));

        /* Retrieve value from Zer0net Db. */
        summary[1] = _zer0netDb.getUint(hash);

        /* Set hash. */
        hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.0xBTC.', _TRADE_PAIR_BASE
        ));

        /* Retrieve value from Zer0net Db. */
        summary[2] = _zer0netDb.getUint(hash);
    }

    /**
     * Set Trade Price (Token)
     *
     * Keys for trade pairs are encoded using the 'exact' symbol,
     * as listed in their respective contract:
     *
     *     Wrapped Ether `ZPI.WETH.DAI`
     *     0xaa840c00b02234222d977a075b41a983e910b0ec8c91fc975a47445ec620d3e1
     *
     *     ZeroGold `ZPI.0GOLD.DAI`
     *     0xdf84929cbe1071e2ac39eebc96c778cf814bb08d423765c5e0fbad95a08b136b
     *
     *     0xBitcoin Token `ZPI.0xBTC.DAI`
     *     0x15368058dc772efcdf5cb4ab485b67fc39e579a5f5c211918831e9f504a483a5
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function setTradePrice(
        string _token,
        uint _value
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.', _token, '.', _TRADE_PAIR_BASE
        ));

        /* Set value in Zer0net Db. */
        _zer0netDb.setUint(hash, _value);

        /* Broadcast event. */
        emit PriceUpdate(hash, _value);

        /* Return success. */
        return true;
    }

    /**
     * Set Trade Price (Collectible)
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function setTradePrice(
        address _token,
        uint _tokenId,
        uint _value
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Set hash. */
        bytes32 hash = keccak256(abi.encodePacked(
            _NAMESPACE, '.', _token, '.', _tokenId
        ));

        /* Set value in Zer0net Db. */
        _zer0netDb.setUint(hash, _value);

        /* Broadcast event. */
        emit PriceUpdate(hash, _value);

        /* Return success. */
        return true;
    }

    /**
     * Set Trade Price (IPFS) List
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function setTradePriceList(
        string _listId,
        string _ipfsPath
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Initailze hash. */
        bytes32 hash = 0x0;

        /* Set hash. */
        hash = keccak256(abi.encodePacked('zero.price.index.', _listId));

        /* Set value in Zer0net Db. */
        _zer0netDb.setString(hash, _ipfsPath);

        /* Broadcast event. */
        emit PriceListUpdate(hash, _ipfsPath);

        /* Return success. */
        return true;
    }

    /**
     * Set Core Trade Prices
     *
     * NOTE: All trades are made against DAI stablecoin.
     *
     * NOTE: Use of `string[]` is still experimental,
     *       so we are required to `setCorePrices` by sending
     *       `_values` in the proper format.
     */
    function setAllCoreTradePrices(
        uint[] _values
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Iterate Core Tokens for updating. */
        for (uint i = 0; i < _CORE_TOKENS.length; i++) {
            /* Set hash. */
            bytes32 hash = keccak256(abi.encodePacked(
                _NAMESPACE, '.', _CORE_TOKENS[i], '.', _TRADE_PAIR_BASE
            ));

            /* Set value in Zer0net Db. */
            _zer0netDb.setUint(hash, _values[i]);

            /* Broadcast event. */
            emit PriceUpdate(hash, _values[i]);
        }

        /* Return success. */
        return true;
    }

    /**
     * Set (Multiple) Trade Prices
     *
     * This will be used for ERC-721 Collectible tokens.
     *
     * NOTE: All trades are made against DAI stablecoin.
     */
    function setTokenTradePrices(
        address[] _tokens,
        uint[] _tokenIds,
        uint[] _values
    ) external onlyAuthBy0Admin returns (bool success) {
        /* Iterate Core Tokens for updating. */
        for (uint i = 0; i < _tokens.length; i++) {
            /* Set hash. */
            bytes32 hash = keccak256(abi.encodePacked(
                _NAMESPACE, '.', _tokens[i], '.', _tokenIds[i]
            ));

            /* Set value in Zer0net Db. */
            _zer0netDb.setUint(hash, _values[i]);

            /* Broadcast event. */
            emit PriceUpdate(hash, _values[i]);
        }

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
