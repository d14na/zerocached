/* Import vendor libraries. */
import express from 'express'
import Web3 from 'web3'

/**
 * Relay Station
 *
 * An express web server, implementing the ZeroCache API.
 */
class RelayStation {
    constructor () {
        /* Start initialization. */
        this._init()
    }

    /**
     * App Initialization.
     */
    _init () {
        console.log('Starting RelayStation initialization...')

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
        this.app.get('/limit', this['routes']['limit'].info.bind(this))

        // https://cache.0net.io/market/
        this.app.get('/market', this['routes']['market'].info.bind(this))

        // https://cache.0net.io/approve
        // this.app.get('/approve', this['routes']['exchange'].approve.bind(this))
    }

    // FIXME What is this for?? returnTicker??
    _checkOutput (_op) {
        if (typeof _op['returnTicker'] !== 'undefined') {
            prev_good = _op

            return _op
        } else {
            return prev_good
        }
    }

}

export default RelayStation
