/* Import vendor libraries. */
import Web3 from 'web3'

/**
 * Market Maker
 *
 * Automated ERC token trader.
 */
class MarketMaker {
    constructor () {
        /* Start initialization. */
        this._init()
    }

    /**
     * App Initialization.
     */
    _init () {
        console.log('Starting MarketMaker initialization...')

        /* Initialize configuration settings. */
        this.config = require('../../config')

        /* Set ZeroGold base price. */
        // NOTE: maximum 21,000,000 tokens @ starting $500,000 valuation
        this.zerogoldBasePrice = 0.023809523809524

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

    }
}

export default MarketMaker
