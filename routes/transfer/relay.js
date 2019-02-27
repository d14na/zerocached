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

    /* Initialize (http) provider. */
    let provider = null

    /* Select http provider. */
    if (process.env.NODE_ENV === 'production') {
        provider = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
    } else {
        provider = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
    }

    /* Initialize web3. */
    const web3 = new Web3(new Web3.providers.HttpProvider(provider))

    /* Initilize abi. */
    const abi = require('../../abi/zeroCache')

    /* Initialize contract. */
    const contract = new web3.eth.Contract(abi)

    /* Build encoded ABI. */
    const encodedABI = contract.methods.transfer(
        body.token,
        body.from,
        body.to,
        body.tokens,
        body.staekholder,
        body.staek,
        body.expires,
        body.nonce,
        body.signature
    ).encodeABI()

    /* Initialize Nano connection. */
    const nano = require('nano')('http://localhost:5984')

    /* Initialize database object. */
    let db = null

    /* Select ZeroCache (requests) database. */
    if (process.env.NODE_ENV === 'production') {
        db = nano.db.use('zerocache_requests')
    } else {
        db = nano.db.use('zerocache_requests_ropsten')
    }

    /* Set owner. */
    const owner = body.from

    /* Set staek. */
    const staek = body.staek

    /* Set data. */
    const data = encodedABI

    /* Set date created. */
    const dateCreated = moment().unix()

    /* Build relay package. */
    const relayPkg = { owner, staek, data, dateCreated }

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
