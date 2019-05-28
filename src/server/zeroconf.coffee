os = require 'os'
mdns = require 'mdns'

otto = global.otto

global.otto.zeroconf = do -> # note 'do' calls the function
  zeroconf = {}

  # we should use node_mdns for osx, and this avahi module under linux:
  # https://github.com/D1plo1d/node_avahi_pub
  # FIXME

  zeroconf.createMDNSAdvertisement = ->
    try
      console.log 'advertising on mdns'
      ad_otto = mdns.createAdvertisement mdns.tcp('otto'), 8778, { name: 'Otto Audio Jukebox @ ' + os.hostname() }
      ad_otto.on 'error', handleMDNSError
      ad_otto.start()
      ad_http = mdns.createAdvertisement mdns.tcp('http'), 8778, { name: 'Otto Audio Jukebox @ ' + os.hostname() }
      ad_http.on 'error', handleMDNSError
      ad_http.start()
    catch ex
      handleMDNSError(ex)

  handleMDNSError = (error) ->
    switch (error.errorCode)
      when mdns.kDNSServiceErr_Unknown
        console.warn(error)
        otto.misc.timeoutSet(5000, mdns.createMDNSAdvertisement)
      else throw error


  return zeroconf
