/* Import vendor libraries. */
// import io from 'socket.io-client'

/* Import core app libraries. */
import Maia from './src/Maia'
import RelayStation from './src/RelayStation'

console.log('\n')
console.log('ZeroCache Daemon v19.2.12 (alpha)')
console.log('---------------------------------')
console.log('\n')

/* Create new Maia bot. */
// NOTE: Maia is D14na's "official" Money Manager Bot.
const maia = new Maia()

/* Create new relay station. */
const relayStation = new RelayStation()
