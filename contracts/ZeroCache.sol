pragma solidity ^0.4.25;

/*******************************************************************************
 *
 * Copyright (c) 2019 Decentralization Authority MDAO.
 * Released under the MIT License.
 *
 * ZeroCache - AmTrust (rev0)
 *
 *             -----------------------------------------------------------------
 *
 *             !!! WARNING WARNING WARNING !!!
 *             !!! THIS IS HIGHLY EXPERIMENTAL SOFTWARE !!!
 *             !!! USE AT YOUR OWN RISK !!!
 *
 *             -----------------------------------------------------------------
 *
 *             Our team at D14na has been hard at work over the Crypto Winter;
 *             and we are very proud to announce the premier release of a still
 *             experimental, but really fun and social new way to "Do Crypto!"
 *
 *             TL;DR
 *             -----
 *
 *             A meta-currency / smart wallet built for the purpose of promoting
 *             and supporting the core economic needs of the Zeronet community:
 *                 1. Electronic Commerce
 *                 2. Zite Monetization
 *                 3. Wealth Management
 *
 *             ALL transactions are guaranteed by Solidty contracts managed by a
 *             growing community of federated nodes.
 *
 *             For more information, please visit:
 *             https://0net.io/zerocache.bit
 *
 * Version 19.2.12
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
library ECRecovery {
    /**
     * @dev Recover signer address from a message by using their signature
     *
     * @param hash bytes32 The hash of the signed message.
     * @param sig bytes The signature generated using web3.eth.sign().
     */
    function recover(
        bytes32 hash,
        bytes sig
    ) public pure returns (address) {
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
 * Wrapped ETH (WETH) Interface
 */
contract WETHInterface {
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

    /* Initialize predecessor contract. */
    address public predecessor;

    /* Initialize successor contract. */
    address public successor;

    /* Initialize revision number. */
    uint private _revision;

    /* Initialize Zer0net Db contract. */
    Zer0netDbInterface private _zer0netDb;

    /* Initialize ZeroGold contract. */
    ERC20Interface private _zeroGold;

    /* Initialize Wrapped ETH (WETH) contract. */
    WETHInterface private _wethContract;

    /* Initialize account balances. */
    mapping(address => mapping (address => uint)) balances;

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

    event Debug(
        address us
    );

    /***************************************************************************
     *
     * Constructor
     */
    constructor() public {
        /* Set predecessor address. */
        predecessor = 0x49722554d23a1A4549DDCfD68cB40Bbe2323aefC;

        /* Verify predecessor address. */
        if (predecessor != 0x0) {
            /* Retrieve the last revision number (if available). */
            uint lastRevision = ZeroCache(predecessor).getRevision();

            /* Set (current) revision number. */
            _revision = lastRevision + 1;
        }

        /* Initialize Zer0netDb (eternal) storage database contract. */
        // NOTE We hard-code the address here, since it should never change.
        // zer0netDb = Zer0netDbInterface(0xE865Fe1A1A3b342bF0E2fcB11fF4E3BCe58263af);
        _zer0netDb = Zer0netDbInterface(0x4C2f68bCdEEB88764b1031eC330aD4DF8d6F64D6); // ROPSTEN

        /* Set the ZeroGold fee account address. */
        // NOTE We hard-code the address here, since it should never change.
        // zeroGold = 0x6ef5bca539A4A01157af842B4823F54F9f7E9968;
        // zeroGold = 0x079F89645eD85b85a475BF2bdc82c82f327f2932; // ROPSTEN

        /* Initialize Wrapped ETH (WETH) contract. */
        // NOTE We hard-code the address here, since it should never change.
        // wethContract = WrapperInterface(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        // wethContract = WETHInterface(0xc778417E063141139Fce010982780140Aa0cD5Ab); // ROPSTEN
    }

    /**
     * @dev Only allow access to an authorized Zer0net administrator.
     */
    modifier onlyAuthBy0Admin() {
        /* Verify write access is only permitted to authorized accounts. */
        require(_zer0netDb.getBool(keccak256(
            abi.encodePacked(msg.sender, '.has.auth.for.zerocache'))) == true);

        _;      // function code is inserted here
    }

    /**
     * Fallback (default)
     *
     * Accepts direct ETH transfers to be wrapped for owner into one of the
     * canonical Wrapped ETH (WETH) contracts:
     *     - Mainnet : 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
     *     - Ropsten : 0xc778417E063141139Fce010982780140Aa0cD5Ab
     *     - Kovan   : 0xd0A1E359811322d97991E03f863a0C30C2cF029C
     *     - Rinkeby : 0xc778417E063141139Fce010982780140Aa0cD5Ab
     * (source https://blog.0xproject.com/canonical-weth-a9aa7d0279dd)
     */
    function () public payable {
        /* Set hash. */
        bytes32 hash = keccak256('aname.WETH');

        /* Retrieve value from Zer0net Db. */
        address wethAddress = _zer0netDb.getAddress(hash);

        /* Validate WETH address. */
        if (wethAddress == 0x0) {
            revert('Oops! This ANAME has NOT been initialized.');
        }

        /* DO NOT (re-)wrap incoming ETH from Wrapped ETH contract. */
        if (msg.sender != wethAddress) {
            _wrap();
        }
    }

    /**************************************/
    /* ACTIONS */
    /**************************************/

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
    function _wrap() private returns (bool success) {
        /* Forward this payable ether into the wrapping contract. */
        success = address(_wethContract).call
            .gas(200000)
            .value(msg.value)
            (abi.encodeWithSignature("deposit()"));

        /* Increase WETH balance by sent value. */
        balances[address(_wethContract)][msg.sender] = balances[address(_wethContract)][msg.sender].add(msg.value);

        /* Initialize empty data (for event log). */
        bytes memory data;

        /* Record to event log. */
        emit Deposit(address(_wethContract), msg.sender, msg.value, data);
    }

    /**
     * Unwrap
     */
    function unwrap(
        uint _tokens
    ) external returns (bool success) {
        return _unwrap(msg.sender, _tokens);
    }

    /**
     * Unwrap (Administrators ONLY)
     */
    function unwrap(
        address _owner,
        uint _tokens
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
        uint _tokens
    ) private returns (bool success) {
        /* Decrease WETH balance by sent value. */
        balances[address(_wethContract)][_owner] = balances[address(_wethContract)][_owner].sub(_tokens);

        /* Withdraw ETH from Wrapper contract. */
        success = address(_wethContract).call
            .gas(200000)
            (abi.encodeWithSignature("withdraw(uint256)", _tokens));

        /* Transfer "unwrapped" Ether (ETH) back to owner. */
        _owner.transfer(_tokens);

        /* Record to event log. */
        emit Withdraw(
            address(_wethContract),
            address(_owner),
            _tokens
        );
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
        address _token,
        address _from,
        uint _tokens,
        bytes _data
    ) external returns (bool success) {
        return _deposit(_token, _from, _tokens, _data);
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
        // TODO Payload actions are not yet implemented.
        // parse the data: first byte is for action id.
        // byte actionId = _data[0];

        /**
         * If `_data` is an `address`, then set the value to `from`.
         * e.g. when `approveAndCall` is made from a contract (representing the owner).
         */
        if (_data.length == 20) {
            /* Retrieve the receiver's address from the (data) payload. */
            address receiver = _bytesToAddress(_data);

            /* NOTE: Deposit credited to `_data` address. */
            return _deposit(_token, receiver, _tokens, _data);
        }

        /* NOTE: Deposit credited to `msg.sender`. */
        return _deposit(_token, _from, _tokens, _data);
    }

    /**
     * Deposit (private)
     *
     * NOTE: This function requires pre-approval from the token
     *       contract for the amount requested.
     */
    function _deposit(
        address _token,
        address _from,
        uint _tokens,
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

        /* Decrease owner's balance by token amount. */
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
     * This transfer requires an off-chain (EC) signature, from the
     * account holder, detailing the transaction.
     *
     * Boost Fee
     * ---------
     *
     * Users may choose to boost the fee paid for their transfer request,
     * decreasing the delivery time to near instant (highest priority for
     * miners to process) confirmation. This fee is paid for in ZeroGold,
     * and is 100% optional. Standard Delivery will be FREE forever.
     *
     * TODO: Let's implement GasToken to provide relayers an opportunity
     *       to hedge against the volatility of the gas price.
     *       (source: https://gastoken.io/)
     */
    function transfer(
        address _token,         // contract address
        address _from,          // sender's address
        address _to,            // receiver's address
        uint _tokens,           // quantity of tokens
        address _boostProvider, // boost service provider
        uint _boostFee,         // boost fee
        uint _expires,          // expiration time
        uint _nonce,            // unique integer
        bytes _signature        // signed message
    ) external returns (bool success) {
        /* Calculate transfer hash. */
        bytes32 transferHash = keccak256(abi.encodePacked(
            address(this),
            _token,
            _from,
            _to,
            _tokens,
            _boostProvider,
            _boostFee,
            _expires,
            _nonce
        ));

        /* Validate transfer. */
        bool isValidTransfer = _isValidTransfer(
            address(this),
            transferHash,
            _expires,
            _signature
        );

        /* Validate transfer. */
        if (!isValidTransfer) {
            revert('Oops! This transfer is NOT valid.');
        }

        /* Validate boost fee and pay (if necessary). */
        if (_boostFee > 0) {
            _payBoostFee(_from, _boostProvider, _boostFee);
        }

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
     * Transfer Multiple Tokens (w/ Single Transaction)
     *
     * NOTE: This feature is not yet implemented (publicly).
     */
    function _multiTransfer(
        address _sender,
        address[] _receiver,
        address[] _token,
        uint[] _tokens
    ) private returns (bool success) {
        /* Loop through all receivers. */
        for (uint i = 0; i < _receiver.length; i++) {
            /* Set token. */
            address token = _token[i];

            /* Set token value. */
            uint tokens = _tokens[i];

            /* Set receiver. */
            address receiver = _receiver[i];

            /* Make transfer. */
            ERC20Interface(token).transfer(receiver, tokens);

            /* Remove the transfer value from sender's balance. */
            balances[token][_sender] = balances[token][_sender].sub(tokens);

            /* Add the transfer value to the receiver's balance. */
            balances[token][receiver] = balances[token][receiver].add(tokens);

            /* Report the transfer. */
            emit Transfer(token, _sender, receiver, tokens);
        }

        /* Return success. */
        return true;
    }

    /**
     * Pay Boost Fee (private)
     *
     * This is an (optional) fee paid by the sender, which
     * transfers ZeroGold from the sender's account to the specified
     * fee account (eg. Infinity Pool).
     */
    function _payBoostFee(
        address _sender,
        address _provider,
        uint _tokens
    ) private returns (bool success) {
        /* Validate available balance. */
        if (balances[_zeroGold][_sender] < _tokens) revert();

        /* Decrease owner's balance by token amount. */
        balances[_zeroGold][_sender] = balances[_zeroGold][_sender].sub(_tokens);

        /* Transfer specified tokens to boost account. */
        ERC20Interface(_zeroGold).transfer(_provider, _tokens);

        /* Record to event log. */
        emit Transfer(_zeroGold, _sender, _provider, _tokens);

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
        uint _tokens,
        address _token,
        uint _expires,
        uint _nonce
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
        address[] _tokens,
        bool _preApproved
    ) external returns (bool success) {
        return _sweep(msg.sender, _tokens, _preApproved);
    }

    /**
     * Sweep (Administrators ONLY)
     */
    function sweep(
        address _owner,
        address[] _tokens,
        bool _preApproved
    ) onlyAuthBy0Admin external returns (bool success) {
        return _sweep(_owner, _tokens, _preApproved);
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
        address[] _tokens,
        bool _preApproved
    ) private returns (bool success) {

        // TODO Create loop to process tokens one-at-a-time.
        address token = _tokens[0];

        /* Retrieve available balance. */
        uint balance = balances[token][_owner];

        /* Pull latest instance address from Zer0net Db. */
        address latestCache = _zer0netDb.getAddress(
            keccak256('zerocache.latest'));

        /* Reduce owner's balance to zero. */
        // balances[_token][_owner] = 0;

        /* Initialize empty data (for event log). */
        bytes memory data;

        /* Transfer full balance to owner's account on the latest instance. */
        if (_preApproved) {
            ZeroCache(latestCache).deposit(token, _owner, balance, data);
        } else {
            ApproveAndCallFallBack(token).approveAndCall(_owner, balance, data);
        }

        // TODO If WETH, must first get allowance.

        /* Record to event log. */
        emit Sweep(token, _owner, balance);

        /* Return success. */
        return true;
    }

    /**
     * Is Order Transfer
     */
    function _isValidTransfer(
        address _from,
        bytes32 _transferHash,
        uint _expires,
        bytes _signature
    ) private returns (bool success) {
        /* Calculate signature hash. */
        bytes32 sigHash = keccak256(abi.encodePacked(
            '\x19Ethereum Signed Message:\n32', _transferHash));

        /* Set expiration flag. */
        // NOTE: Set a flag here to prevent double-spending.
        expiredSignatures[sigHash] = true;

        /* Validate the expiration time. */
        if (block.number > _expires) {
            return false;
        }

        /* Validate signature expiration. */
        if (expiredSignatures[sigHash]) {
            return false;
        }

        /* Retrieve the authorized account (address). */
        address authorizedAccount = ECRecovery.recover(sigHash, _signature);

        /* Validate the signer matches owner of the tokens. */
        if (_from != authorizedAccount) {
            return false;
        }

        return true;
    }

    function _isAccountOpen(
        // address _account
    ) private pure returns (bool success) {
        // TODO
        // 1. Check `mapping(address => bool) _accountStatus`
        // 2. OR... create struct for `Accounts`

        /* Return success. */
        return true;
    }

    /**
     * Close Account
     *
     * Sets a flag to indicate that ALL tokens have been
     * transferred out of the Cache and no further activity
     * is permitted to take place for this account.
     */
    function _closeAccount(
        // address _account
    ) private pure returns (bool success) {
        // TODO
        // 1. Validate no tokens exist.
        // 2. Disable user execution.

        /* Return success. */
        return true;
    }


    /**************************************/
    /* GETTERS */
    /**************************************/

    /***************************************************************************
     *
     * Get the token balance for account `tokenOwner`
     */
    function balanceOf(
        address _token,
        address _owner
    ) external constant returns (uint balance) {
        /* Retrieve balance. */
        balance = balances[_token][_owner];
    }

    /**
     * Get Revision (Number)
     */
    function getRevision() public view returns (uint) {
        return _revision;
    }


    /**************************************/
    /* SETTERS */
    /**************************************/

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

    /**
     * Is (Owner) Contract
     *
     * Tests if a specified account / address is a contract.
     */
    function _ownerIsContract(
        address _owner
    ) private view returns (bool isContract) {
        /* Initialize code length. */
        uint codeLength;

        /* Run assembly. */
        assembly {
            /* Retrieve the size of the code on target address. */
            codeLength := extcodesize(_owner)
        }

        /* Set test result. */
        isContract = (codeLength > 0);
    }

    /**
     * Bytes-to-Address
     *
     * Converts bytes into type address.
     */
    function _bytesToAddress(bytes _address) private pure returns (address) {
        uint160 m = 0;
        uint160 b = 0;

        for (uint8 i = 0; i < 20; i++) {
            m *= 256;
            b = uint160(_address[i]);
            m += (b);
        }

        return address(m);
    }
}
