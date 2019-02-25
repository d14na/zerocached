import moment from 'moment'
import Web3 from 'web3'

const CONFIG = require('../../config')
const DEFAULT_GAS = '200000'

/**
 * Stats
 */
module.exports = function (req, res) {
    console.log('BODY', req.body)

    /* Initialize window.web3 global. */
    // const HTTP_PROVIDER = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
    const HTTP_PROVIDER = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'

    const web3 = new Web3(new Web3.providers.HttpProvider(HTTP_PROVIDER))

    /* Initilize address. */
    const from = CONFIG['accounts']['relay'].address

    /* Initilize private key. */
    const privateKey = CONFIG['accounts']['relay'].privateKey

    /* Initialize new account from private key. */
    const acct = web3.eth.accounts.privateKeyToAccount(privateKey)

    /* Initilize address. */
    // FIXME Pull this value dynamically from `aname.zerocache`
    const contractAddress = '0x565d0859a620aE99052Cc44dDe74b199F13A3433' // ZeroCache

    /* Initilize abi. */
    const abi = require('../../abi/zeroCache')

    /* Initialize gas price. */
    // const gasPrice = '20000000000' // default gas price in wei, 20 gwei in this case
    const gasPrice = '5.5' * 1e9 // or get with web3.eth.gasPrice

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress, options)

    // console.log('MY CONTRACT', myContract)

    const _token = { t: 'address', v: '0x079F89645eD85b85a475BF2bdc82c82f327f2932' }
    const _from = { t: 'address', v: '0xe5Fe2e0Ec02bB85d0655CA6Cf4E23824fAD285DC' }
    const _to = { t: 'address', v: '0xb07d84f2c5d8be1f4a440173bc536e0b2ee3b05e' }
    const _tokens = { t: 'uint256', v: '1337' }
    const _staekholder = { t: 'bytes', v: '0x0000000000000000000000000000000000000000' }
    const _staek = { t: 'uint256', v: '0' }
    const _expires = { t: 'uint256', v: '5090000' }
    const _nonce = { t: 'uint256', v: '0' }

    const signature = '0xd0fe4aaab37fd633a34618ed43b504a2941de649a745aa497f58f172dd8ce20e229ee49348fa3281eaa9b5d6c3ce7cc71a58844e8fc4e4c6c818346fe88fd5ab1c'

    /* Build encoded ABI. */
    const encodedABI = myContract.methods.transfer(
        _token.v,
        _from.v,
        _to.v,
        _tokens.v,
        _staekholder.v,
        _staek.v,
        _expires.v,
        _nonce.v,
        signature
    ).encodeABI()

    const tx = {
        from,
        to: contractAddress,
        gas: DEFAULT_GAS,
        gasPrice: web3.utils.toHex(gasPrice),
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
