const express = require('express')
const io = require('socket.io-client')
const app = express()

const moment = require('moment')
const Web3 = require('web3')

const ABI = require('./abi')
const CONFIG = require('./config')

const TOKEN_STORE_TICKER = 'https://v1-1.api.token.store/ticker'
const DEFAULT_GAS = '150000'
const DEFAULT_PORT = 3000

// const SOCKET_URL = 'https://socket.etherdelta.com'
const SOCKET_URL = 'https://socket.forkdelta.app'

const HTTP_PROVIDER = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
// const HTTP_PROVIDER = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
// const WS_PROVIDER = 'wss://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'

const web3 = new Web3(new Web3.providers.HttpProvider(HTTP_PROVIDER))

const config = {
}

app.get('/', (req, res) => res.send('<h1>Welcome to ZeroCache!</h1>'))

// app.get('/bots', (req, res) => {
//     res.json(CONFIG['bots'])
// })

https://cache.0net.io/testAsk
app.get('/testAsk', (req, res) => {
    /* Initilize private key. */
    const pk = CONFIG['bots']['auntieAlice'].privateKey

    /* Initialize new account from private key. */
    const acct = web3.eth.accounts.privateKeyToAccount(pk)

    res.json(acct)
})

https://cache.0net.io/approve
app.get('/approve', (req, res) => {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const privateKey = CONFIG['bots']['auntieAlice'].privateKey

    /* Initilize abi. */
    const abi = ABI.zerogold

    /* Initilize address. */
    const contractAddress = '0x6ef5bca539A4A01157af842B4823F54F9f7E9968' // ZeroGold

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress)

    const encodedABI = myContract.methods.approve(
        '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819', // ZeroDelta_2
        1000000000000 // 10k tokens
    ).encodeABI()

    var gasPrice = '1.8' //or get with web3.eth.gasPrice

    const tx = {
        from,
        to: contractAddress,
        gas: DEFAULT_GAS,
        gasPrice: web3.utils.toHex(gasPrice * 1e9),
        // gasLimit: web3.utils.toHex(gasLimit),
        data: encodedABI
    }

    web3.eth.accounts.signTransaction(tx, privateKey)
        .then(signed => {
            const tx = web3.eth.sendSignedTransaction(signed.rawTransaction)

            // NOTE: Why do we need to listen for 24 confirmations??
            tx.on('confirmation', (confirmationNumber, receipt) => {
                // console.log('confirmation: ' + confirmationNumber)
                // if (receipt) console.log('CONFIRMATION RECEIPT', receipt)
            })

            tx.on('transactionHash', hash => {
                console.log('hash', hash)
            })

            tx.on('receipt', receipt => {
                console.log('reciept', receipt)

                res.json(receipt)
            })

            tx.on('error', console.error)
        })
})

https://cache.0net.io/depositToken
app.get('/depositToken', (req, res) => {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const privateKey = CONFIG['bots']['auntieAlice'].privateKey

    /* Initilize abi. */
    const abi = ABI.etherDelta

    /* Initilize address. */
    const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819' // ZeroDelta_2

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress)

    const encodedABI = myContract.methods.depositToken(
        '0x6ef5bca539A4A01157af842B4823F54F9f7E9968', // ZeroGold
        1000000000000 // 10k tokens
    ).encodeABI()

    var gasPrice = '2' //or get with web3.eth.gasPrice

    const tx = {
        from,
        to: contractAddress,
        gas: DEFAULT_GAS,
        gasPrice: web3.utils.toHex(gasPrice * 1e9),
        // gasLimit: web3.utils.toHex(gasLimit),
        data: encodedABI
    }

    web3.eth.accounts.signTransaction(tx, privateKey)
        .then(signed => {
            const tx = web3.eth.sendSignedTransaction(signed.rawTransaction)

            // NOTE: Why do we need to listen for 24 confirmations??
            tx.on('confirmation', (confirmationNumber, receipt) => {
                // console.log('confirmation: ' + confirmationNumber)
                // if (receipt) console.log('CONFIRMATION RECEIPT', receipt)
            })

            tx.on('transactionHash', hash => {
                console.log('hash', hash)
            })

            tx.on('receipt', receipt => {
                console.log('reciept', receipt)

                res.json(receipt)
            })

            tx.on('error', console.error)
        })
})

// https://cache.0net.io/order
app.get('/order', (req, res) => {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const privateKey = CONFIG['bots']['auntieAlice'].privateKey

    /* Initilize abi. */
    const abi = ABI.etherDelta

    /* Initilize address. */
    const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819' // ZeroDelta_2

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress)

    const tokenGet = '0x0000000000000000000000000000000000000000'
    const amountGet = '189355207646922000'
    const tokenGive = '0x6ef5bca539A4A01157af842B4823F54F9f7E9968'
    const amountGive = '100000000000'
    const expires = '7093142'
    const nonce = moment().unix() // seconds since epoch

    const encodedABI = myContract.methods.order(
        tokenGet,
        amountGet,
        tokenGive,
        amountGive,
        expires,
        nonce
    ).encodeABI()

    var gasPrice = '3' //or get with web3.eth.gasPrice

    const tx = {
        from,
        to: contractAddress,
        gas: DEFAULT_GAS,
        gasPrice: web3.utils.toHex(gasPrice * 1e9),
        // gasLimit: web3.utils.toHex(gasLimit),
        data: encodedABI
    }

    web3.eth.accounts.signTransaction(tx, privateKey)
        .then(signed => {
            const tx = web3.eth.sendSignedTransaction(signed.rawTransaction)

            // NOTE: Why do we need to listen for 24 confirmations??
            tx.on('confirmation', (confirmationNumber, receipt) => {
                // console.log('confirmation: ' + confirmationNumber)
                // if (receipt) console.log('CONFIRMATION RECEIPT', receipt)
            })

            tx.on('transactionHash', hash => {
                console.log('hash', hash)
            })

            tx.on('receipt', receipt => {
                console.log('reciept', receipt)

                res.json(receipt)
            })

            tx.on('error', console.error)
        })
})

// https://cache.0net.io/edBalance
app.get('/edBalance', (req, res) => {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const pk = CONFIG['bots']['auntieAlice'].privateKey

    /* Initialize new account from private key. */
    const acct = web3.eth.accounts.privateKeyToAccount(pk)

    /* Initilize address. */
    const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819'

    /* Initilize abi. */
    const abi = ABI.etherDelta

    /* Initialize gas price. */
    const gasPrice = '20000000000' // default gas price in wei, 20 gwei in this case

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress, options)

    // console.log('MY CONTRACT', myContract)

    myContract.methods
        .balanceOf(
            '0x6ef5bca539A4A01157af842B4823F54F9f7E9968', // token
            '0x3F75223FdF7e8d0f59060945497E48B9A1608f20' // account address
        ).call({ from },
    function (_error, _result) {
        if (_error) return console.error(_error)

        console.log('RESULT', _result)

        let pkg = {
            balance: _result,
            bricks: parseInt(_result / 100000000)
        }

        res.json(pkg)
    })
})

// https://cache.0net.io/orderbook
app.get('/ed/orderbook', function(req, res, next){
    console.log("Received Token Address: " + req.query.tokenAddr);

    socket = io.connect(SOCKET_URL, { transports: ['websocket'] });
    socket.emit('getMarket', {token: req.query.tokenAddr, user: req.query.userAddr});
    socket.on('market',  function(data){
        console.log('DATA', data)

	    res.contentType('application/json');
	    res.send(checkOutput(JSON.parse(JSON.stringify(data))));
    })
})

app.listen(DEFAULT_PORT, () => console.log(`Example app listening on port ${DEFAULT_PORT}!`))

// NOTE: What is this for?? returnTicker??
const checkOutput = function (_op) {
    if (_op['returnTicker'] != undefined) {
        prev_good = _op;
	    return _op;
    } else {
        return prev_good;
    }
}
