url = require 'url'


class ImageRequest

  constructor: (@options) ->
    @req = @options.req
    @res = @options.res
    @time = @options.time || Date.now()

    # Extract the query parameters, and pass them through to the request we will have 
    # Phantom make of our image page building endpoint.
    @query = url.parse(@req.url).search

    @webdriverUrlRequest = null
    @webdriverScreenshotRequest = null



  # handleRequest starts the sequence of calls to take care of the request
  
  # Only Phantom implements true promises, which is why this is structured as a set of
  # callbacks rather than a promise chain.

  # No matter what, we need to call done() when we are done.

  handleRequest: (browserTools, done) ->
    @browserTools = browserTools
    @done = done

    @awaitPhantom()


  awaitPhantom: ->
    @browserTools.phantomPromise.then @awaitWebdriver

    .catch @errorHandler


  awaitWebdriver: =>
    @browserTools.webdriverSession.then @loadUrl
    
    .catch @errorHandler


  loadUrl: =>

    unless @query?
      @errorHandler new Error("No visualization parameters specified.")
      return

    @webdriverUrlRequest = @browserTools.webdriverSession.url("#{process.env.HOST}:#{process.env.PORT_NUMBER}/html_image/#{@query}")

    @webdriverUrlRequest.then =>

      # We've seen an issue where the font has not loaded in time for the screenshot, and
      # so none of the text is rendered. The 50ms timeout is intended to compensate for this.
      # This is not an ideal solution, but detecting font loading is hard, and this is simple.
      # The issue occurred in maybe 1 request in 20.
      # Other options: include the font as a data URI, try the CSS3 document.fontloader API
      setTimeout @saveScreenshot, 50

    .catch @errorHandler


  saveScreenshot: =>
    @webdriverScreenshotRequest = @webdriverUrlRequest.saveScreenshot()
    @webdriverScreenshotRequest.then @writeResponse
    
    .catch @errorHandler


  writeResponse: (screenshotBuffer) =>
    @res.setHeader "content-type", "image/png"
    # content-disposition=attachment prompts the browser to start a file download rather
    # than navigate to the image.
    @res.setHeader "content-disposition", "attachment"
    @res.setHeader 'cache-control', "max-age=600" 
    @res.write(screenshotBuffer)
    @res.end()

    @done()

    console.log "Time: #{Date.now() - @time}"



  errorHandler: (error) =>
    console.log "That's an error: "
    console.log error.message
    console.log error.stack

    @res.writeHead 500
    @res.end "HTTP 500 #{error.message}"

    @done()








module.exports = ImageRequest