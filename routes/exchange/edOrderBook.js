/**
 * EtherDelta Order Book
 */
export default async function (req, res) {
    // FIXME What is this for?? returnTicker??
    const _checkOutput = (_op) => {
        if (typeof _op['returnTicker'] !== 'undefined') {
            prev_good = _op

            return _op
        } else {
            return prev_good
        }
    }

    console.log("Received Token Address: " + req.query.tokenAddr);

    socket = io.connect(SOCKET_URL, { transports: ['websocket'] });
    socket.emit('getMarket', {token: req.query.tokenAddr, user: req.query.userAddr});
    socket.on('market',  function(data){
        console.log('DATA', data)

	    res.contentType('application/json');
	    res.send(_checkOutput(JSON.parse(JSON.stringify(data))));
    })

}
