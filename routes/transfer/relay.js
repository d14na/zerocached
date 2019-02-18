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
    const contractAddress = '0x79e0FCF937843E58C84eF491AF394BA8835Aa098' // ZeroCache

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

                const sigHash = web3.utils.soliditySha3(
                    { t: 'address', v: contractAddress },
                    { t: 'address', v: '0x079F89645eD85b85a475BF2bdc82c82f327f2932' },
                    { t: 'address', v: '0xe5Fe2e0Ec02bB85d0655CA6Cf4E23824fAD285DC' },
                    { t: 'address', v: '0xb07d84f2c5d8be1f4a440173bc536e0b2ee3b05e' },
                    { t: 'uint256', v: '8880000' },
                    { t: 'bytes'  , v: '0x0000000000000000000000000000000000000000' }, // same as address, but w/out checksum
                    { t: 'uint256', v: '0' },
                    { t: 'uint256', v: '5046541' },
                    { t: 'uint256', v: '0' }
                )

                // const sig = web3.utils.soliditySha3(
                //     { t: 'string', v: 'Hello!%' },
                //     { t: 'uint256', v:-23 },
                //     { t: 'address', v: '0x85F43D8a49eeB85d32Cf465507DD71d507100C1d' }
                // )
                //
                console.log('SIGNATURE HASH', sigHash)

                let privateKey = '0xbc2cd411934c8bf2502a26af1c3c116a932e99e27051bfe6439c8747cf91b3a5'
                const sig = web3.eth.accounts.sign(sigHash, privateKey)

                console.log('SIGNATURE', sig.signature)

                let pkg = {
                    sigHash,
                    sig,
                    balance: _result,
                    bricks: parseInt(_result / 100000000)
                }

                res.json(pkg)
            })

}
