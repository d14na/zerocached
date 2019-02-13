/**
 * EtherDelta Balance
 */
export default async function (req, res) {
    /* Initilize address. */
    const from = CONFIG['bots']['auntieAlice'].address

    /* Initilize private key. */
    const pk = CONFIG['bots']['auntieAlice'].privateKey

    /* Initialize new account from private key. */
    const acct = web3.eth.accounts.privateKeyToAccount(pk)

    /* Initilize address. */
    const contractAddress = '0x8d12A197cB00D4747a1fe03395095ce2A5CC6819'

    /* Initilize abi. */
    const abi = require('./abi/etherDelta')

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
}
