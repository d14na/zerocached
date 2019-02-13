/**
 * Token Store Order
 */
export default async function (req, res) {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const privateKey = CONFIG['bots']['auntieAlice'].privateKey

    /* Initilize abi. */
    const abi = require('./abi/etherDelta')

    /* Initilize address. */
    const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819' // ZeroDelta_2

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress)

    const blockNumber = await web3.eth.getBlockNumber()

    const offering = 150 // ZeroGold bricks
    const ethUsd = 125.20 // current ETH price in USD

    const basePriceBN = web3.utils.toBN(parseInt(ZEROGOLD_BASE_PRICE * 10**18)) // ZeroGold base price
    const ethUsdBN = web3.utils.toBN(parseInt(ethUsd * 10**18)) // ETH_USD
    const offeringBN = web3.utils.toBN(parseInt(offering * 10**18)) // ZeroGOLD

    const tokenGet = '0x0000000000000000000000000000000000000000' // Ethereum (ETH)
    const amountGet = basePriceBN.mul(offeringBN).div(ethUsdBN) // ETH received
    const tokenGive = '0x6ef5bca539A4A01157af842B4823F54F9f7E9968' // ZeroGold
    const amountGive = offeringBN.div(web3.utils.toBN(1 * 10**10)) // 0GOLD sent
    const expires = blockNumber + 10000 // approx 1 3/4 days
    const nonce = moment().unix() // seconds since epoch



    // const http = require('http');
    // let body =`{
    //   "account": "0x1307b8d863e0cfc147ad0953613f98bbdf95be41",
    //   "contract": '0x1cE7AE555139c5EF5A57CC8d814a867ee6Ee33D8',
    //   "tokenGet": "0x0000000000000000000000000000000000000000",
    //   "amountGet": "747000000000000000",
    //   "tokenGive": "0x62a56a4a2ef4d355d34d10fbf837e747504d38d4",
    //   "amountGive": "30000",
    //   "nonce": "1982976399",
    //   "expires": 5629999,
    //   "signature": {
    //     "r": "0xfd7aa97d7bdf41ee188ab6db5ce6fcbd312e9f8d1932df9b446820a5a7f6ff4a",
    //     "s": "0x37eab8f9e95629f4ede94ed7e38d14f8fbd6bde6fcc19d24dc2aaea21bd5eaa1",
    //     "v": 28
    //   }
    // }
    // `;
    // let init = {
    // host:'v1-1.api.token.store',
    // path:'/orders',
    // port:'443',
    // method:'POST',
    // };
    // const callback = function(response){
    // var str = '';
    // response.on('data', function(chunk){
    // str += chunk;
    // });
    // response.on('end', function(){
    // // str has response body
    // });
    // };
    // const req = http.request(init, callback);
    // req.write(body);
    // req.end();



    // return res.json({
    //     basePriceBN,
    //     offeringBN,
    //     ethUsdBN
    // })

    // return res.json({
    //     tokenGet,
    //     amountGet_gwei: amountGet.div(web3.utils.toBN(1 * 10**9)), // in gwei
    //     tokenGive,
    //     amountGive,
    //     expires,
    //     nonce
    // })

    // return res.json({
    //     tokenGet,
    //     amountGet: amountGet.toString(),
    //     tokenGive,
    //     amountGive: amountGive.toString(),
    //     expires,
    //     nonce
    // })

    const encodedABI = myContract.methods.order(
        tokenGet,
        amountGet.toString(),
        tokenGive,
        amountGive.toString(),
        expires,
        nonce
    ).encodeABI()

    var gasPrice = '3' //or get with web3.eth.gasPrice

    const tx = {
        from,
        to: contractAddress,
        gas: DEFAULT_GAS,
        gasPrice: web3.utils.toHex(gasPrice * 1e9),
        data: encodedABI
    }

    // return res.json(tx)

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
}
