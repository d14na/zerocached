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

        setInterval(
            () => {
                console.log('Hi, it\'s Maia again. Just checking in.')
            }, 30000
        )
    }
}

export default Maia
