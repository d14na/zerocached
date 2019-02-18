import moment from 'moment'

/**
 * Stats
 */
module.exports = function (req, res) {
    console.log(req)

    const pkg = {
        transfering: false,
        lastAction: moment().unix()
    }

    res.json(pkg)
}
