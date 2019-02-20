import moment from 'moment'
import Web3 from 'web3'

const CONFIG = require('../../config')
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
    const pk = CONFIG['accounts']['relay'].privateKey

    /* Initialize new account from private key. */
    const acct = web3.eth.accounts.privateKeyToAccount(pk)

    /* Initilize address. */
    const contractAddress = '0xA6CB833eA8127Aa628152720b622F6B4d002fCD8' // ZeroCache

    /* Initilize abi. */
    const abi = require('../../abi/zeroCache')

    /* Initialize gas price. */
    const gasPrice = '20000000000' // default gas price in wei, 20 gwei in this case

    /* Initialize options. */
    const options = { from, gasPrice }

    const myContract = new web3.eth.Contract(
        abi, contractAddress, options)

    // console.log('MY CONTRACT', myContract)

    myContract.methods
        .balanceOf(
            '0x079F89645eD85b85a475BF2bdc82c82f327f2932', // token
            '0xe5Fe2e0Ec02bB85d0655CA6Cf4E23824fAD285DC' // account address
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
}
