/* Initialize limit routes. */
const limit = require('./limit')

/* Initialize market routes. */
const market = require('./market')

/* Initialize transfer routes. */
const transfer = require('./transfer')

/* Export homepage. */
module.exports = {
    limit,
    market,
    transfer
}
