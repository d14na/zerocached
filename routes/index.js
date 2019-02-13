/* Initialize limit routes. */
const limit = require('./limit')

/* Initialize homepage route. */
const homepage = function (req, res) {
    res.send('<h1>Welcome to ZeroCache Daemon</h1>')
}

/* Export homepage. */
module.exports = {
    homepage,
    limit
}
