const moment = require('moment')

/**
 * Stats
 */
module.exports = function (req, res) {
    /* Initilize private key. */
    const pk = this['config']['accounts']['taker'].privateKey

    /* Initialize new account from private key. */
    const acct = this.web3.eth.accounts.privateKeyToAccount(pk)

    // NOTE Remove this for security reasons
    delete acct.privateKey

    acct.lastAction = moment().unix()

    res.json(acct)
}
