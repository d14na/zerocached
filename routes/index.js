/* Initialize market maker routes. */
const maker = require('./maker')

/* Initialize market taker routes. */
const taker = require('./taker')

/* Initialize transfer routes. */
const transfer = require('./transfer')

/* Export homepage. */
module.exports = {
    maker,
    taker,
    transfer
}
