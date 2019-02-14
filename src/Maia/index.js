/* Import vendor libraries. */
import express from 'express'
import Web3 from 'web3'

/**
 * Maia (Market Maker Bot)
 */
class Maia {
    constructor () {
        /* Start initialization. */
        this._init()
    }

    /**
     * App Initialization.
     */
    _init () {
        console.log('Starting Maia initialization...')

        /* Initialize configuration settings. */
        this.config = require('../../config')

        /* Set ZeroGold base price. */
        // NOTE: maximum 21,000,000 tokens @ starting $500,000 valuation
        this.zerogoldBasePrice = 0.023809523809524

        /* Initailize Express framework. */
        this.app = express()

        /* Initialize endpoints / routes. */
        this.routes = require('../../routes')

        /* Initialize (default) port number. */
        this.portNum = 3000

        // this.httpProvider = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
        // this.wsProvider = 'wss://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
        this.httpProvider = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
        this.wsProvider = 'wss://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'

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

        setInterval(
            () => {
                console.log('Hi, it\'s Maia again. Just checking in.')
            }, 30000
        )
    }

    /**
     * Start API Server
     */
    _startAPIServer () {
        this.app.listen(this.portNum, () => {
            console.log(`ZeroCache Daemon is now listening. [ port: ${this.portNum} ]`)
        })

        // https://cache.0net.io/
        this.app.get('/', this['routes'].homepage.bind(this))

        // https://cache.0net.io/limit/
        this.app.get('/limit', this['routes']['limit'].stats.bind(this))

        // https://cache.0net.io/market/
        this.app.get('/market', this['routes']['market'].stats.bind(this))

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

export default Maia
