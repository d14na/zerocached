const moment = require('moment')
const request = require('superagent')
const Web3 = require('web3')

/* Initialize Nano connection. */
const nano = require('nano')('http://localhost:5984')

/* Initialize blockchain provider. */
let provider = null

/* Select (http) provider. */
if (process.env.NODE_ENV === 'production') {
    provider = 'https://mainnet.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
} else {
    provider = 'https://ropsten.infura.io/v3/9c75462e9ef54ba3ae559cde271fcf0d'
}

/* Initialize web3. */
const web3 = new Web3(new Web3.providers.HttpProvider(provider))

const CONFIG = require('../../config')

const DEFAULT_GAS = '200000'

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
    async _init () {
        console.log('Starting RelayStation initialization...')

        if (process.env.NODE_ENV === 'production') {
            /* Initialize ZeroCache (requests) database. */
            this.dbRequests = nano.db.use('zerocache_requests')

            /* Initialize ZeroCache (queued) database. */
            this.dbQueued = nano.db.use('zerocache_queued')

            /* Initialize ZeroCache (success) database. */
            this.dbSuccess = nano.db.use('zerocache_success')

            /* Initialize ZeroCache (failed) database. */
            this.dbFailed = nano.db.use('zerocache_failed')
        } else {
            /* Initialize ZeroCache (requests) database. */
            this.dbRequests = nano.db.use('zerocache_requests_ropsten')

            /* Initialize ZeroCache (queued) database. */
            this.dbQueued = nano.db.use('zerocache_queued_ropsten')

            /* Initialize ZeroCache (success) database. */
            this.dbSuccess = nano.db.use('zerocache_success_ropsten')

            /* Initialize ZeroCache (failed) database. */
            this.dbFailed = nano.db.use('zerocache_failed_ropsten')
        }

        /* Initialize queue. */
        this.queue = []

        /* Initilize (from) address. */
        this.from = CONFIG['accounts']['relay'].address

        /* Initilize private key. */
        this.privateKey = CONFIG['accounts']['relay'].privateKey

        /* Set data id. */
        // NOTE: keccak256(`aname.zerocache`)
        const dataId = '0x75341c765d2ccac618fa566b11618076575bdb7620692a552e9ac9ff23a5540c'

        /* Initialize endpoint. */
        let endpoint = null

        /* Select (http) provider. */
        if (process.env.NODE_ENV === 'production') {
            endpoint = `https://db.0net.io/v1/getAddress/${dataId}`
        } else {
            endpoint = `https://db-ropsten.0net.io/v1/getAddress/${dataId}`
        }

        /* Make API request. */
        const response = await request
            .get(endpoint)
            .set('accept', 'json')
            .catch(_error => {
                console.error('REQUEST ERROR:', _error)
            })

        // console.log('ZeroCache ANAME RESPONSE:', response)

        /* Validate response. */
        if (response && response.body)  {
            console.log('ZeroCache ANAME:', response.body)

            /* Set contract address. */
            this.contractAddress = response.body
        }

        /* Initialize gas price. */
        // const gasPrice = '20000000000' // default gas price in wei, 20 gwei in this case
        this.gasPrice = '5.5' * 1e9 // or get with web3.eth.gasPrice

        /* Initilize abi. */
        const abi = require('../../abi/zeroCache')

        /* Initialize (transaction) options. */
        const options = {
            from: this.from,
            gasPrice: this.gasPrice
        }

        /* Initialize contract. */
        this.contract = new web3.eth.Contract(
            abi, this.contractAddress, options)

        // console.log('CONTRACT', this.contract)
    }

    async processQueue () {
        /* Initialize db options. */
        const options = {
            include_docs: true
        }

        /* Request database request records. */
        const body = await this.dbRequests.list(options)
            .catch(_error => {
                console.error('ERROR:', _error)
            })

        /* Loop through all requests. */
        body.rows.forEach(async (_doc) => {
            /* Set doc(ument). */
            const doc = _doc.doc

            /* Validate request record. */
            if (doc.language) {
                return
            }

            // console.log(doc)

            /* Set owner. */
            const owner = doc.owner

            /* Set staek. */
            const staek = doc.staek

            /* Set data. */
            const data = doc.data

            /* Set date created. */
            const dateCreated = moment().unix()

            /* Build package entry. */
            const entry = { owner, staek, data, dateCreated }

            /* Destroy the record. */
            // NOTE: We err on the side of caution, by avoiding the
            //       possiblity of duplicate requests.
            let result = await this.dbRequests.destroy(doc._id, doc._rev)
                .catch(_error => {
                    console.error('ERROR:', _error)
                })

            // console.log(result)

            /* Insert into (queued) database. */
            result = await this.dbQueued.insert(entry)
                .catch(_error => {
                    console.error('ERROR:', _error)
                })

            // console.log(result)

            /* Add (inserted) document reference to entry. */
            entry.docRef = result

            /* Add to queue. */
            this.queue.push(entry)

            console.log(`Maia added request to queue from [ ${entry.owner} ]`)
        })

        /* Maia (queue) status message. */
        if (this.queue.length > 0) {
            console.log(`Maia is processing [ 1 of ${this.queue.length} ] txs from queue...`)

            /* Retreive (and remove) the first entry. */
            const nextRequest = this.queue.shift()

            /* Process (on-chain) transaction. */
            this._processTx(nextRequest)
        } else {
            console.log(`Maia is waiting for txs from queue...`)
        }
    }

    async _processTx (_nextRequest) {
        console.log(`Maia is processing next request from [ ${_nextRequest.owner} ]`)

        /* Initialize tx hash (holder). */
        let txHash = null

        /* Initialize encoded ABI. */
        const data = _nextRequest.data

        // console.log('_processTx ABI', data)

        /* Build raw transaction package. */
        const rawTx = {
            from: this.from,
            to: this.contractAddress,
            gas: DEFAULT_GAS,
            gasPrice: web3.utils.toHex(this.gasPrice),
            data
        }

        /* Generate signed transaction. */
        const signed = await web3.eth.accounts
            .signTransaction(rawTx, this.privateKey)
            .catch(_error => {
                console.error('ERROR:', _error)
            })

        /* Send signed transaction (to network). */
        const signedTx = web3.eth.sendSignedTransaction(signed.rawTransaction)

        // NOTE: Why do we need to listen for 24 confirmations??
        signedTx.on('confirmation', (_confirmationNumber, _receipt) => {
            // console.log('confirmation: ' + _confirmationNumber)
            // if (receipt) console.log('CONFIRMATION RECEIPT', _receipt)
        })

        signedTx.on('transactionHash', _txHash => {
            /* Set tx hash. */
            txHash = _txHash

            console.log(`[ ${txHash} ] has been submitted.`)
        })

        signedTx.on('receipt', async _receipt => {
            // console.log('Reciept', _receipt)

            console.log(`[ ${_receipt.transactionHash} ] has been added to [ block # ${_receipt.blockNumber} ]`)

            /* Retrieve document reference. */
            const doc = _nextRequest.docRef

            /* Set owner. */
            const owner = _nextRequest.owner

            /* Set staek. */
            const staek = _nextRequest.staek

            /* Set data. */
            const data = _nextRequest.data

            /* Set receipt. */
            const receipt = _receipt

            /* Set date created. */
            const dateCreated = moment().unix()

            /* Build entry. */
            const entry = {
                owner,
                staek,
                data,
                receipt,
                dateCreated
            }

            /* Insert into (success) database. */
            let result = await this.dbSuccess.insert(entry)
                .catch(_error => {
                    console.error('ERROR:', _error)
                })

            // console.log(result)

            /* Destroy the record. */
            // NOTE: We err on the side of caution, and ONLY destroy
            //       after recording the successful receipt.
            result = await this.dbQueued.destroy(doc.id, doc.rev)
                .catch(_error => {
                    console.error('ERROR:', _error)
                })

            // console.log(result)
        })

        signedTx.on('error', async (_error) => {
            // console.error('ERROR:', _error)
            console.error('ERROR:', _error.message)

            /* Retrieve document reference. */
            const doc = _nextRequest.docRef

            /* Set owner. */
            const owner = _nextRequest.owner

            /* Set staek. */
            const staek = _nextRequest.staek

            /* Set data. */
            const data = _nextRequest.data

            /* Set error. */
            const error = _error.message

            /* Set date created. */
            const dateCreated = moment().unix()

            /* Build entry. */
            const entry = {
                owner,
                staek,
                data,
                txHash,
                error,
                dateCreated
            }

            /* Insert into (failed) database. */
            let result = await this.dbFailed.insert(entry)
                .catch(_error => {
                    console.error('ERROR:', _error)
                })

            // console.log(result)

            /* Destroy the record. */
            // NOTE: We err on the side of caution, and ONLY destroy
            //       after recording the error.
            result = await this.dbQueued.destroy(doc.id, doc.rev)
                .catch(_error => {
                    console.error('ERROR:', _error, doc)
                })

            // console.log(result)
        })
    }

}

module.exports = RelayStation
