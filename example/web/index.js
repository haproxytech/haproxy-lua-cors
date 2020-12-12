const express = require('express')
const mustacheExpress = require('mustache-express')

const app = express()
app.engine('html', mustacheExpress())
app.set('view engine', 'html')
app.set('views', __dirname + '/views')

const port = 80

// the UI
app.get('/', function (req, res) {
  res.render('index', {})
})

// the API
app.get('/getdata', function(req, res) {
  res.send('Message from the server!')
})

app.put('/putdata', function(req, res) {
  res.sendStatus(204)
})

app.listen(port, () => console.log(`Server listening on port ${port}`))