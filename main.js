/* Import vendor libraries. */
// import io from 'socket.io-client'

/* Import core app libraries. */
const Maia = require('./src/Maia')
const MarketMaker = require('./src/MarketMaker')
const RelayStation = require('./src/RelayStation')

console.log('\n')
if (process.env.NODE_ENV === 'production') {
    console.log('ZeroCache Daemon v19.2.26 (alpha) [ MAINNET ]')
    console.log('---------------------------------------------\n')
} else {
    console.log('ZeroCache Daemon v19.2.26 (alpha) [ ROPSTEN ]')
    console.log('---------------------------------------------\n')
}

/* Create new relay station. */
const relayStation = new RelayStation()

/* Create new market maker. */
const marketMaker = new MarketMaker()

/* Create new Maia bot. */
// NOTE: Maia is D14na's "official" Money Manager Bot.
const maia = new Maia(relayStation)
