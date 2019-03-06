/* Import vendor libraries. */
const express = require('express')
const Web3 = require('web3')

/**
 * Maia (Market Maker Bot)
 */
class Maia {
    constructor (_relayStation) {
        /* Start initialization. */
        this._init(_relayStation)
    }

    /**
     * App Initialization.
     */
    _init (_relayStation) {
        console.log('Starting Maia initialization...')

        /* Set relay station. */
        this.relayStation = _relayStation

        /* Initialize configuration settings. */
        this.config = require('../../config')

        /* Set ZeroGold base price. */
        // NOTE: maximum 21,000,000 tokens @ starting $500,000 valuation
        this.zerogoldBasePrice = 0.023809523809524

        /* Initailize Express framework. */
        this.app = express()

        /* Initialize static content folder. */
        this.app.use(express.static('static'))

        /* Initialize JSON body handler. */
        this.app.use(express.json())

        /* Add CORS. */
        this.app.use(function (req, res, next) {
            res.header('Access-Control-Allow-Headers', '*')
            res.header('Access-Control-Allow-Origin', '*')
            next()
        })

        /* Initialize endpoints / routes. */
        this.routes = require('../../routes')

        if (process.env.NODE_ENV === 'production') {
            /* Initialize (default) port number. */
            this.portNum = 3000

            /* Initialize network providers. */
            this.httpProvider = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
            this.wsProvider = 'wss://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
        } else {
            /* Initialize (default) port number. */
            this.portNum = 4000

            /* Initialize network providers. */
            this.httpProvider = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
            this.wsProvider = 'wss://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
        }

        /* Initialize Web3. */
        this.web3 = new Web3(new Web3.providers.HttpProvider(this.httpProvider))

        /* Initialize (default) gas amount. */
        this.gasAmount = '300000'

        /* Set Token Store Ticker URL. */
        this.tokenStoreTickerUrl = 'https://v1-1.api.token.store/ticker'

        /* Set ForkDelta Socket URL. */
        // NOTE: This appears to be more reliable than EtherDelta.
        this.forkDeltaSocketUrl = 'https://socket.forkdelta.app'

        /* Set EtherDelta Socket URL. */
        this.forkDeltaSocketUrl = 'https://socket.etherdelta.com'

        /* Start API server. */
        this._startAPIServer()

        /* Set execution interval. */
        setInterval(
            () => {
                /* Process queue. */
                this.relayStation.processQueue()
            }, 30000
        )

        /* Process queue at startup. */
        this.relayStation.processQueue()
    }

    /**
     * Start API Server
     */
    _startAPIServer () {
        this.app.listen(this.portNum, () => {
            console.log(`ZeroCache Daemon is now listening... [ port: ${this.portNum} ]`)
        })

        // https://cache.0net.io/v1/maker
        this.app.get('/v1/maker', this['routes']['maker'].stats.bind(this))

        // https://cache.0net.io/v1/createOrder
        this.app.post('/v1/maker/createOrder', this['routes']['maker'].createOrder.bind(this))

        // https://cache.0net.io/v1/taker
        this.app.get('/v1/taker', this['routes']['taker'].stats.bind(this))

        // https://cache.0net.io/v1/transfer
        this.app.get('/v1/transfer', this['routes']['transfer'].stats.bind(this))

        // https://cache.0net.io/v1/transfer
        this.app.post('/v1/transfer', this['routes']['transfer'].relay.bind(this))

        // https://cache.0net.io/approve
        // this.app.get('/approve', this['routes']['exchange'].approve.bind(this))

        // https://cache.0net.io/depositToken
        // this.app.get('/depositToken', this['routes']['exchange'].depositToken.bind(this))

        // https://cache.0net.io/order
        // this.app.get('/order', this['routes']['exchange'].order.bind(this))

        // https://cache.0net.io/tsOrder
        // this.app.get('/tsOrder', this['routes']['exchange'].tsOrder.bind(this))

        // https://cache.0net.io/edBalance
        // this.app.get('/edBalance', this['routes']['exchange'].edBalance.bind(this))

        // https://cache.0net.io/orderbook
        // this.app.get('/orderbook', this['routes']['exchange'].orderbook.bind(this))
    }
}

module.exports = Maia
