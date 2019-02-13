/* Initialize homepage route. */
const homepage = function (req, res) {
    res.send('<h1>Welcome to ZeroCache Daemon</h1>')
}

/* Initialize limit routes. */
const limit = require('./limit')

/* Initialize market routes. */
const market = require('./market')

/* Export homepage. */
module.exports = {
    homepage,
    limit,
    market
}
