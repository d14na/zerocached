/**
 * Approve
 */
export default async function (req, res) {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const privateKey = CONFIG['bots']['auntieAlice'].privateKey

    /* Initilize abi. */
    const abi = require('./abi/zerogold')

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
}
