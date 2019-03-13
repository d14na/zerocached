const moment = require('moment')
const request = require('superagent')
const Web3 = require('web3')

/* Initialize Nano connection. */
const nano = require('nano')('http://localhost:5984')

/* Initialize blockchain provider. */
let provider = null

/* Select (http) provider. */
if (process.env.NODE_ENV === 'production') {
    provider = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
} else {
    provider = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
}

/* Initialize web3. */
const web3 = new Web3(new Web3.providers.HttpProvider(provider))

const CONFIG = require('../../config')

const DEFAULT_GAS = '350000'

/**
 * Market Maker
 *
 * Automated ERC token trader.
 */
class MarketMaker {
    constructor () {
        /* Start initialization. */
        this._init()
    }

    /**
     * App Initialization.
     */
    async _init () {
        console.log('Starting MarketMaker initialization...')

        /* Initilize (from) address. */
        this.from = CONFIG['accounts']['maker'].address

        /* Initilize private key. */
        this.privateKey = CONFIG['accounts']['maker'].privateKey

        /* Set data id. */
        // NOTE: keccak256(`aname.zerodelta`)
        const dataId = '0xbd7239f4aaac15ef5b656f04994d54293ff22d4aac85bedfcb4b68e502db0497'

        /* Initialize endpoint. */
        let endpoint = null

        /* Select (http) provider. */
        if (process.env.NODE_ENV === 'production') {
            endpoint = `https://db.0net.io/v1/getAddress/${dataId}`
        } else {
            endpoint = `https://db-ropsten.0net.io/v1/getAddress/${dataId}`
        }

        /* Make API request. */
        const response = await request
            .get(endpoint)
            .set('accept', 'json')
            .catch(_error => {
                console.error('REQUEST ERROR:', _error)
            })

        // console.log('ZeroDelta ANAME RESPONSE:', response)

        /* Validate response. */
        if (response && response.body)  {
            console.log('ZeroDelta ANAME:', response.body)

            /* Set contract address. */
            this.contractAddress = response.body
        }

        /* Initialize gas price. */
        this.gasPrice = '5.5' * 1e9 // or get with web3.eth.gasPrice

        /* Initilize abi. */
        const abi = require('../../abi/zeroDelta')

        /* Initialize (transaction) options. */
        const options = {
            from: this.from,
            gasPrice: this.gasPrice
        }

        /* Initialize contract. */
        this.contract = new web3.eth.Contract(
            abi, this.contractAddress, options)

        // console.log('CONTRACT', this.contract)

        // TEMPORARY -- FOR TESTING PURPOSES ONLY
        this._createOrder()
    }

    async _createOrder () {
        console.log('Creating new order.')

        /* Retrieve current block. */
        const blockNumber = await web3.eth.getBlockNumber()

        console.log('Current block number', blockNumber)

        /* Set data id. */
        // NOTE: keccak256(`aname.zerocache`)
        const dataId = '0x75341c765d2ccac618fa566b11618076575bdb7620692a552e9ac9ff23a5540c'

        /* Initialize endpoint. */
        let endpoint = null

        /* Select (http) provider. */
        if (process.env.NODE_ENV === 'production') {
            endpoint = `https://db.0net.io/v1/getAddress/${dataId}`
        } else {
            endpoint = `https://db-ropsten.0net.io/v1/getAddress/${dataId}`
        }

        /* Make API request. */
        const response = await request
            .get(endpoint)
            .set('accept', 'json')
            .catch(_error => {
                console.error('REQUEST ERROR:', _error)
            })

        /* Initialize ZeroCache ANAME. */
        let anameZeroCache = null

        /* Validate response. */
        if (response && response.body)  {
            console.log('ZeroCache ANAME:', response.body)

            /* Set ANAME. */
            anameZeroCache = response.body
        } else {
            return console.error('ERROR ZeroCache ANAME:', response)
        }

        // const anameZeroCache = '0x565d0859a620aE99052Cc44dDe74b199F13A3433'
        const tokenRequest = '0xc778417E063141139Fce010982780140Aa0cD5Ab'
        const amountRequest = '888000000000000000'
        const tokenOffer = '0x079F89645eD85b85a475BF2bdc82c82f327f2932'
        const amountOffer = '13370000000'
        const ttl = blockNumber + 10000
        const timestamp = moment().unix() // seconds
        const canPartialFill = false

        /**
         * Initialize all transaction parameters for signing.
         *
         * NOTE: We manually set the `t` of each parameter
         *       for accurate type casting.
         */
        const contract = { t: 'address', v: anameZeroCache }
        const token = { t: 'address', v: tokenOffer }
        const from = { t: 'address', v: this.from }
        const to = { t: 'address', v: this.contractAddress }
        const tokens = { t: 'uint256', v: amountOffer }
        const staekholder = { t: 'bytes', v: '0x0000000000000000000000000000000000000000' }
        const staek = { t: 'uint256', v: 0 }
        const expires = { t: 'uint256', v: ttl }
        const nonce = { t: 'uint256', v: timestamp }

        /* Sign the parameters to generate a hash signature. */
        const sigHash = web3.utils.soliditySha3(
            contract, // ZeroCache's contract address
            token, // token's contract address
            from, // sender's address
            to, // receiver's address
            tokens, // quantity of tokens
            staekholder, // staekholder (NOTE: bytes is the same as address, but w/out checksum)
            staek, // staek amount
            expires, // expiration time
            nonce // nonce (unique integer)
        )

        console.log('SIGNATURE HASH', sigHash)

        /* Sign signature hash. */
        const signaturePkg = web3.eth.accounts.sign(
            sigHash, this.privateKey)

        // console.log('SIGNATURE PACKAGE', signaturePkg)

        /* Set signature. */
        const signature = signaturePkg.signature

        console.log('SIGNATURE', signature)

        /* Build encoded ABI. */
        const encodedABI = this.contract.methods.createOrder(
            tokenRequest,
            amountRequest,
            tokenOffer,
            amountOffer,
            ttl,
            timestamp,
            signature,
            canPartialFill
        ).encodeABI()

        this._processTx(encodedABI)
    }

    async _processTx (_data) {
        /* Initialize tx hash (holder). */
        let txHash = null

        /* Set from. */
        const from = this.from

        /* Set to. */
        const to = this.contractAddress

        /* Set gas. */
        const gas = DEFAULT_GAS

        /* Set gas price. */
        const gasPrice = web3.utils.toHex(this.gasPrice)

        /* Initialize encoded ABI. */
        const data = _data

        // console.log('_processTx ABI', data)

        /* Build raw transaction package. */
        const rawTx = {
            from,
            to,
            gas,
            gasPrice,
            data
        }

        console.log(`Maia is processing next request, by [ ${rawTx.from} ]`)

        /* Generate signed transaction. */
        const signed = await web3.eth.accounts
            .signTransaction(rawTx, this.privateKey)
            .catch(_error => {
                console.error('ERROR:', _error)
            })

        /* Send signed transaction (to network). */
        const signedTx = web3.eth.sendSignedTransaction(signed.rawTransaction)

        // NOTE: Why do we need to listen for 24 confirmations??
        signedTx.on('confirmation', (_confirmationNumber, _receipt) => {
            // console.log('confirmation: ' + _confirmationNumber)
            // if (receipt) console.log('CONFIRMATION RECEIPT', _receipt)
        })

        signedTx.on('transactionHash', _txHash => {
            /* Set transaction hash. */
            txHash = _txHash

            console.log(`[ ${_txHash} ] has been submitted.`)
        })

        signedTx.on('receipt', async _receipt => {
            // console.log('Reciept', _receipt)

            console.log(`[ ${_receipt.transactionHash} ] has been added to [ block # ${_receipt.blockNumber} ]`)
        })

        signedTx.on('error', async (_error) => {
            // console.error('ERROR:', _error)
            console.error('ERROR:', _error.message)
        })
    }
}

module.exports = MarketMaker
