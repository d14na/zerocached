const moment = require('moment')
const Web3 = require('web3')

/**
 * Relay
 */
module.exports = function (req, res) {
    /* Initialize request body. */
    const body = req.body

    // console.log('BODY', body)

    console.log(`Maia received a new relay request from [ ${body.from} ]`)

    const _token = { t: 'address', v: '0x079F89645eD85b85a475BF2bdc82c82f327f2932' }
    const _from = { t: 'address', v: '0xe5Fe2e0Ec02bB85d0655CA6Cf4E23824fAD285DC' }
    const _to = { t: 'address', v: '0xb07d84f2c5d8be1f4a440173bc536e0b2ee3b05e' }
    const _tokens = { t: 'uint256', v: '1337' }
    const _staekholder = { t: 'bytes', v: '0x0000000000000000000000000000000000000000' }
    const _staek = { t: 'uint256', v: '0' }
    const _expires = { t: 'uint256', v: '5090000' }
    const _nonce = { t: 'uint256', v: moment().valueOf() } // milliseconds
    const signature = '0xd0fe4aaab37fd633a34618ed43b504a2941de649a745aa497f58f172dd8ce20e229ee49348fa3281eaa9b5d6c3ce7cc71a58844e8fc4e4c6c818346fe88fd5ab1c'

    /* Initialize window.web3 global. */
    // const HTTP_PROVIDER = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
    const HTTP_PROVIDER = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'

    /* Initialize web3. */
    const web3 = new Web3(new Web3.providers.HttpProvider(HTTP_PROVIDER))

    /* Initilize abi. */
    const abi = require('../../abi/zeroCache')

    /* Initialize contract. */
    const contract = new web3.eth.Contract(abi)

    /* Build encoded ABI. */
    const encodedABI = contract.methods.transfer(
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

    /* Initialize Nano connection. */
    const nano = require('nano')('http://localhost:5984')

    /* Initialize ZeroCache (requests) database. */
    const db = nano.db.use('zerocache_requests')

    /* Set owner. */
    const owner = _from.v

    /* Build relay package. */
    const relayPkg = {
        owner,
        staek: _staek.v,
        data: encodedABI,
        dateCreated: moment().unix()
    }

    /* Insert to database. */
    db.insert(relayPkg).then(_result => {
        // console.log(_result)

        /* Set success. */
        const success = _result

        /* Return JSON results. */
        res.json({ success })
    }).catch(_error => {
        console.error(_error)

        /* Set error. */
        const error = _error

        /* Return JSON results. */
        res.json({ error })
    })
}
