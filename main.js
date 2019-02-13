/* Import vendor libraries. */
// import io from 'socket.io-client'

/* Import core app libraries. */
import Maia from './src/Maia'
import RelayStation from './src/RelayStation'

console.log('\n')
console.log('ZeroCache Daemon v19.2.12 (alpha)')
console.log('---------------------------------')
console.log('\n')

/* Create new Maia bot. */
// NOTE: Maia is D14na's "official" Money Manager Bot.
const maia = new Maia()

/* Create new relay station. */
const relayStation = new RelayStation()

// https://cache.0net.io/depositToken
// app.get('/depositToken', (req, res) => {
//     /* Initilize address. */
//     const from = CONFIG['bots']['auntieAlice'].address
//
//     /* Initilize private key. */
//     const privateKey = CONFIG['bots']['auntieAlice'].privateKey
//
//     /* Initilize abi. */
//     const abi = require('./abi/etherDelta')
//
//     /* Initilize address. */
//     const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819' // ZeroDelta_2
//
//     /* Initialize options. */
//     const options = { from, gasPrice }
//
//     const myContract = new web3.eth.Contract(
//         abi, contractAddress)
//
//     const encodedABI = myContract.methods.depositToken(
//         '0x6ef5bca539A4A01157af842B4823F54F9f7E9968', // ZeroGold
//         1000000000000 // 10k tokens
//     ).encodeABI()
//
//     var gasPrice = '2' //or get with web3.eth.gasPrice
//
//     const tx = {
//         from,
//         to: contractAddress,
//         gas: DEFAULT_GAS,
//         gasPrice: web3.utils.toHex(gasPrice * 1e9),
//         // gasLimit: web3.utils.toHex(gasLimit),
//         data: encodedABI
//     }
//
//     web3.eth.accounts.signTransaction(tx, privateKey)
//         .then(signed => {
//             const tx = web3.eth.sendSignedTransaction(signed.rawTransaction)
//
//             // NOTE: Why do we need to listen for 24 confirmations??
//             tx.on('confirmation', (confirmationNumber, receipt) => {
//                 // console.log('confirmation: ' + confirmationNumber)
//                 // if (receipt) console.log('CONFIRMATION RECEIPT', receipt)
//             })
//
//             tx.on('transactionHash', hash => {
//                 console.log('hash', hash)
//             })
//
//             tx.on('receipt', receipt => {
//                 console.log('reciept', receipt)
//
//                 res.json(receipt)
//             })
//
//             tx.on('error', console.error)
//         })
// })

// https://cache.0net.io/order
// app.get('/order', async (req, res) => {
//     /* Initilize address. */
//     const from = CONFIG['bots']['auntieAlice'].address
//
//     /* Initilize private key. */
//     const privateKey = CONFIG['bots']['auntieAlice'].privateKey
//
//     /* Initilize abi. */
//     const abi = require('./abi/etherDelta')
//
//     /* Initilize address. */
//     const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819' // ZeroDelta_2
//
//     /* Initialize options. */
//     const options = { from, gasPrice }
//
//     const myContract = new web3.eth.Contract(
//         abi, contractAddress)
//
//     const blockNumber = await web3.eth.getBlockNumber()
//
//     const offering = 150 // ZeroGold bricks
//     const ethUsd = 125.20 // current ETH price in USD
//
//     const basePriceBN = web3.utils.toBN(parseInt(ZEROGOLD_BASE_PRICE * 10**18)) // ZeroGold base price
//     const ethUsdBN = web3.utils.toBN(parseInt(ethUsd * 10**18)) // ETH_USD
//     const offeringBN = web3.utils.toBN(parseInt(offering * 10**18)) // ZeroGOLD
//
//     const tokenGet = '0x0000000000000000000000000000000000000000' // Ethereum (ETH)
//     const amountGet = basePriceBN.mul(offeringBN).div(ethUsdBN) // ETH received
//     const tokenGive = '0x6ef5bca539A4A01157af842B4823F54F9f7E9968' // ZeroGold
//     const amountGive = offeringBN.div(web3.utils.toBN(1 * 10**10)) // 0GOLD sent
//     const expires = blockNumber + 10000 // approx 1 3/4 days
//     const nonce = moment().unix() // seconds since epoch
//
//     // return res.json({
//     //     basePriceBN,
//     //     offeringBN,
//     //     ethUsdBN
//     // })
//
//     // return res.json({
//     //     tokenGet,
//     //     amountGet_gwei: amountGet.div(web3.utils.toBN(1 * 10**9)), // in gwei
//     //     tokenGive,
//     //     amountGive,
//     //     expires,
//     //     nonce
//     // })
//
//     // return res.json({
//     //     tokenGet,
//     //     amountGet: amountGet.toString(),
//     //     tokenGive,
//     //     amountGive: amountGive.toString(),
//     //     expires,
//     //     nonce
//     // })
//
//     const encodedABI = myContract.methods.order(
//         tokenGet,
//         amountGet.toString(),
//         tokenGive,
//         amountGive.toString(),
//         expires,
//         nonce
//     ).encodeABI()
//
//     var gasPrice = '3' //or get with web3.eth.gasPrice
//
//     const tx = {
//         from,
//         to: contractAddress,
//         gas: DEFAULT_GAS,
//         gasPrice: web3.utils.toHex(gasPrice * 1e9),
//         data: encodedABI
//     }
//
//     // return res.json(tx)
//
//     web3.eth.accounts.signTransaction(tx, privateKey)
//         .then(signed => {
//             const tx = web3.eth.sendSignedTransaction(signed.rawTransaction)
//
//             // NOTE: Why do we need to listen for 24 confirmations??
//             tx.on('confirmation', (confirmationNumber, receipt) => {
//                 // console.log('confirmation: ' + confirmationNumber)
//                 // if (receipt) console.log('CONFIRMATION RECEIPT', receipt)
//             })
//
//             tx.on('transactionHash', hash => {
//                 console.log('hash', hash)
//             })
//
//             tx.on('receipt', receipt => {
//                 console.log('reciept', receipt)
//
//                 res.json(receipt)
//             })
//
//             tx.on('error', console.error)
//         })
// })

// https://cache.0net.io/tsOrder
// app.get('/tsOrder', async (req, res) => {
//     /* Initilize address. */
//     const from = CONFIG['bots']['auntieAlice'].address
//
//     /* Initilize private key. */
//     const privateKey = CONFIG['bots']['auntieAlice'].privateKey
//
//     /* Initilize abi. */
//     const abi = require('./abi/etherDelta')
//
//     /* Initilize address. */
//     const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819' // ZeroDelta_2
//
//     /* Initialize options. */
//     const options = { from, gasPrice }
//
//     const myContract = new web3.eth.Contract(
//         abi, contractAddress)
//
//     const blockNumber = await web3.eth.getBlockNumber()
//
//     const offering = 150 // ZeroGold bricks
//     const ethUsd = 125.20 // current ETH price in USD
//
//     const basePriceBN = web3.utils.toBN(parseInt(ZEROGOLD_BASE_PRICE * 10**18)) // ZeroGold base price
//     const ethUsdBN = web3.utils.toBN(parseInt(ethUsd * 10**18)) // ETH_USD
//     const offeringBN = web3.utils.toBN(parseInt(offering * 10**18)) // ZeroGOLD
//
//     const tokenGet = '0x0000000000000000000000000000000000000000' // Ethereum (ETH)
//     const amountGet = basePriceBN.mul(offeringBN).div(ethUsdBN) // ETH received
//     const tokenGive = '0x6ef5bca539A4A01157af842B4823F54F9f7E9968' // ZeroGold
//     const amountGive = offeringBN.div(web3.utils.toBN(1 * 10**10)) // 0GOLD sent
//     const expires = blockNumber + 10000 // approx 1 3/4 days
//     const nonce = moment().unix() // seconds since epoch
//
//
//
//     // const http = require('http');
//     // let body =`{
//     //   "account": "0x1307b8d863e0cfc147ad0953613f98bbdf95be41",
//     //   "contract": '0x1cE7AE555139c5EF5A57CC8d814a867ee6Ee33D8',
//     //   "tokenGet": "0x0000000000000000000000000000000000000000",
//     //   "amountGet": "747000000000000000",
//     //   "tokenGive": "0x62a56a4a2ef4d355d34d10fbf837e747504d38d4",
//     //   "amountGive": "30000",
//     //   "nonce": "1982976399",
//     //   "expires": 5629999,
//     //   "signature": {
//     //     "r": "0xfd7aa97d7bdf41ee188ab6db5ce6fcbd312e9f8d1932df9b446820a5a7f6ff4a",
//     //     "s": "0x37eab8f9e95629f4ede94ed7e38d14f8fbd6bde6fcc19d24dc2aaea21bd5eaa1",
//     //     "v": 28
//     //   }
//     // }
//     // `;
//     // let init = {
//     // host:'v1-1.api.token.store',
//     // path:'/orders',
//     // port:'443',
//     // method:'POST',
//     // };
//     // const callback = function(response){
//     // var str = '';
//     // response.on('data', function(chunk){
//     // str += chunk;
//     // });
//     // response.on('end', function(){
//     // // str has response body
//     // });
//     // };
//     // const req = http.request(init, callback);
//     // req.write(body);
//     // req.end();
//
//
//
//     // return res.json({
//     //     basePriceBN,
//     //     offeringBN,
//     //     ethUsdBN
//     // })
//
//     // return res.json({
//     //     tokenGet,
//     //     amountGet_gwei: amountGet.div(web3.utils.toBN(1 * 10**9)), // in gwei
//     //     tokenGive,
//     //     amountGive,
//     //     expires,
//     //     nonce
//     // })
//
//     // return res.json({
//     //     tokenGet,
//     //     amountGet: amountGet.toString(),
//     //     tokenGive,
//     //     amountGive: amountGive.toString(),
//     //     expires,
//     //     nonce
//     // })
//
//     const encodedABI = myContract.methods.order(
//         tokenGet,
//         amountGet.toString(),
//         tokenGive,
//         amountGive.toString(),
//         expires,
//         nonce
//     ).encodeABI()
//
//     var gasPrice = '3' //or get with web3.eth.gasPrice
//
//     const tx = {
//         from,
//         to: contractAddress,
//         gas: DEFAULT_GAS,
//         gasPrice: web3.utils.toHex(gasPrice * 1e9),
//         data: encodedABI
//     }
//
//     // return res.json(tx)
//
//     web3.eth.accounts.signTransaction(tx, privateKey)
//         .then(signed => {
//             const tx = web3.eth.sendSignedTransaction(signed.rawTransaction)
//
//             // NOTE: Why do we need to listen for 24 confirmations??
//             tx.on('confirmation', (confirmationNumber, receipt) => {
//                 // console.log('confirmation: ' + confirmationNumber)
//                 // if (receipt) console.log('CONFIRMATION RECEIPT', receipt)
//             })
//
//             tx.on('transactionHash', hash => {
//                 console.log('hash', hash)
//             })
//
//             tx.on('receipt', receipt => {
//                 console.log('reciept', receipt)
//
//                 res.json(receipt)
//             })
//
//             tx.on('error', console.error)
//         })
// })

// https://cache.0net.io/edBalance
// app.get('/edBalance', (req, res) => {
//     /* Initilize address. */
//     const from = CONFIG['bots']['auntieAlice'].address
//
//     /* Initilize private key. */
//     const pk = CONFIG['bots']['auntieAlice'].privateKey
//
//     /* Initialize new account from private key. */
//     const acct = web3.eth.accounts.privateKeyToAccount(pk)
//
//     /* Initilize address. */
//     const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819'
//
//     /* Initilize abi. */
//     const abi = require('./abi/etherDelta')
//
//     /* Initialize gas price. */
//     const gasPrice = '20000000000' // default gas price in wei, 20 gwei in this case
//
//     /* Initialize options. */
//     const options = { from, gasPrice }
//
//     const myContract = new web3.eth.Contract(
//         abi, contractAddress, options)
//
//     // console.log('MY CONTRACT', myContract)
//
//     myContract.methods
//         .balanceOf(
//             '0x6ef5bca539A4A01157af842B4823F54F9f7E9968', // token
//             '0x3F75223FdF7e8d0f59060945497E48B9A1608f20' // account address
//         ).call({ from },
//             function (_error, _result) {
//                 if (_error) return console.error(_error)
//
//                 console.log('RESULT', _result)
//
//                 let pkg = {
//                     balance: _result,
//                     bricks: parseInt(_result / 100000000)
//                 }
//
//                 res.json(pkg)
//             })
// })

// https://cache.0net.io/orderbook
// app.get('/ed/orderbook', function(req, res, next){
//     console.log("Received Token Address: " + req.query.tokenAddr);
//
//     socket = io.connect(SOCKET_URL, { transports: ['websocket'] });
//     socket.emit('getMarket', {token: req.query.tokenAddr, user: req.query.userAddr});
//     socket.on('market',  function(data){
//         console.log('DATA', data)
//
// 	    res.contentType('application/json');
// 	    res.send(checkOutput(JSON.parse(JSON.stringify(data))));
//     })
// })
