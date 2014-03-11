###############
### client side (otto.client.cubes.coffee served as /otto.cubes.js)
###############

global.otto.client.cubes = ->
  window.otto.client.cubes = do ->  # note the 'do' causes the function to be called
    cubes = {}


    $ ->
      #$('head').append($ '<script src="static/js/jquery.rule-min.js">')
      #$('head').append($ '<script src="static/js/jss.js">')
      $('head').append '<script src="http://d3js.org/d3.v2.js">'
      $('head').append '<link rel="stylesheet" href="static/css/otto.cubes.css" />'

      # now we try to make our own style sheet for dynamically adding rules

      # from https://developer.mozilla.org/en-US/docs/DOM/CSSStyleSheet/insertRule
      ##style = document.createElement('style')
      ##$('head').append(style)
      ##if not window.createPopup  # for Safari
      ##   style.appendChild document.createTextNode('')
      # give the last line a chance to manipulate the dom and then grab the last stylesheet created
      # this is risky as other stylesheet loads might be pending but i don't know what else to do.
      # it should probably be ok as long as we don't assume we can do things like remove 'our' stylesheet
      ##setTimeout(->
      ##  cubes.style = document.styleSheets[document.styleSheets.length - 1]
      ##  console.log 'cubes.style', cubes.style
      ##,0)

      # let's try it the jQuery.rule way
      # it said "we must append to get a stylesheet":
      #storageNode = $('<style rel="alternate stylesheet" type="text/css" />').appendTo('head')[0]
      #if storageNode.sheet
      #  cubes.style = storageNode.sheet
      #else
      #  cubes.style = storageNode.styleSheet
      #cubes.style = $ cubes.style
      #cubes.style = $ storageNode

      # let's try it this way (http://stackoverflow.com/questions/5618742):
      #style = document.createElement('style')
      #text = ''
      #style.setAttribute("type", "text/css")
      #if style.styleSheet    # for IE
      #   style.styleSheet.cssText = text
      #else   # others
      #  textnode = document.createTextNode(text)
      #  style.appendChild(textnode)
      #document.getElementsByTagName('head')[0].appendChild(style)
      #cubes.style = document.styleSheets[document.styleSheets.length - 1]
      #console.log 'cubes.style', cubes.style

      # i give up! i don't know where $.rule...('style') is appending the rules
      # but it works and i don't care enough to keep the dynamic css rules in their own sheet
      # ... arrrrgh! doesn't work in FF. sigh.
      # read the 'link' worked better in FF than 'script'. didn't help.


    hash_code = (str) ->
      hash = 0
      for char in str
        hash = ((hash<<5)-hash)+char.charCodeAt(0)
        hash = hash & hash # Convert to 32bit integer
      return hash


    scene_transform = (x, y, z) ->
      z = z || 0
      top = (-x*7-y*7-z*6)
      left = (x*14-y*14)
      if top < cubes.maxheight
        cubes.maxheight = top
      return {'top': top, 'left': left}


    create_cube = (x, y, z, color, shade, z_index, rowclass, title) ->
      color = color || 0
      shade = shade || 0
      pos = scene_transform x, y, z
      bg_x = -((shade%7)*28)
      bg_y = -((color%9)*28)
      # being wrapped in a link affects the opacity rendering effect we want
      # discovered that it doesn't need to be a link, just another element. need to test this on other non-chrome browsers.
      return "<div class='cubelink #{rowclass}' title='#{title}'><dev class='cube' style='top: #{pos.top}px; left: #{pos.left}px; z-index: #{z_index}; visibility: visible; background-position: #{bg_x}px #{bg_y}px;'></div></div>"
      # let's try to do it with half the elements
      #return "<a href='' class='cube cubelink #{rowclass}' title='#{title}' style='top: #{pos.top}px; left: #{pos.left}px; z-index: #{z_index}; visibility: visible; background-position: #{bg_x}px #{bg_y}px;'></a>"
      # ha! that affects the transparence effect too. seems like we need two elements.
      # that only saved about 12% in time anyways


    height = []
    reset_heights = ->
      for x in [0..27]
        height[x] = []
        for y in [0..26]
          height[x][y] = 0

    window.place_one_cube = (fileunderkey, fileundername, albumname) ->
      if not fileunderkey then fileunderkey = 'Unknown'
      namehash = hash_code(fileunderkey.substr(0,9))  # why do we limit it to the first 9 chars??
      color = namehash % 5
      if color < 0
        color = -color

      c0 = fileunderkey.toUpperCase().charCodeAt(0) || 0
      #c1 = fileunderkey.toUpperCase().charCodeAt(1) || 0  # unused? also: wasteful double uppercasing
      x = c0 - 65
      if x > 25 then x = 27
      if x < 0  then x = 26

      y = hash_code(fileunderkey) # could we just use namehash from above?
      if y < 0  then y = -y
      y = y % 26

      z = height[x][y]++
      #z_index = (1000-(x*30+(y-29)))
      z_index = (1000-(x*30+y))
      title = fileundername
      shade = 0
      if albumname
        title = title + ' - ' + albumname
        albumhash = hash_code(albumname.substr(0,9))  # again with the 0,9
      else
        albumhash = hash_code('')
      shade = albumhash % 7

      if shade < 0 then shade = -shade

      #title = title + ' (' + x + ',' + y + ',' + z + ',' + z_index + ',' + color + ',' + shade + ')'
      if x < 26
        rowclass = fileunderkey.toUpperCase()[0]
      else if x is 26
        rowclass = 'num'
      else if x is 27
        rowclass = 'other'

      return create_cube(x, y, z, color, shade, z_index, rowclass, title)

    stackupthecubes = (data) ->
      console.log 'data received'
      cubes.maxheight = 0
      x = 0
      y = -2
      top_adjust = +12  # nudge it into place
      left_adjust = -9
      html = ''
      for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#⋯'
        pos = scene_transform(x, y)
        pos.top  += top_adjust
        pos.left += left_adjust
        html += "<div class='stacklabel', style='top:#{pos.top}px; left:#{pos.left}px'>#{letter}</div>"
        x += 1
      $scene.append $(html)

      reset_heights()

      html = ''

      console.log 'starting to loop through the data...'
      for fileunder in data
        name = fileunder['key'] || ''
        if name is 'Unknown' || not name
          continue
        if name is 'Various' || name is 'Various Artists' || name is 'Soundtrack'
          continue
        if name is 'various' # there's currently a problem with various, everything appears under it! FIXME
          continue

        for album in fileunder['albums']
          if album['album']
            albumname = album['album']
          else
            albumname = ''
          html += place_one_cube(name, fileunder['name'], albumname)

      console.log 'done.'

      console.log 'inserting html string into the dom'
      $scene.append html
      console.log 'done.'

      console.log 'positioning the cubes'
      maxheight = cubes.maxheight
      maxheight = -400 if maxheight > -400
      console.log maxheight
      # position the cubes so the top fits on the landscape
      $cubes.css('top', (-maxheight + 20) + "px")

      console.log 'adjusting the landscape'
      # adjust the landscape grid to cover everything
      $landscape.height(-maxheight + 300)

      # this one seems to trigger the dom rending:
      console.log 'scrolling the window'
      # scroll the bottom in to view if it is not already
      container_bottom = $landscape.offset().top + $landscape.height()
      scroll_bottom = $('#results').parent().scrollTop() + $(window).height()
      if scroll_bottom < container_bottom-100
        $('#results').parent().scrollTop(container_bottom - $(window).height() - 100)
      console.log 'all done!'

      #html = '<button id="loadmusic">load music</div>'
      #$scene.append html

      if data.length is 0
        html = '<div id="databasempty">no music loaded</div>'
        $scene.append html

    $landscape = null
    $cubes = null
    $scene = null

    cubes.show = ->
      $landscape = $("<div id='landscape' class='landscape'>")
      $cubes = $("<div id='cubes'>")
      $scene = $("<div class='scene'>")
      $landscape.append( $cubes.append( $scene ) )

      console.log 'installing handler'
      $landscape.on 'click', cubes.click_handler

      $("#results").empty()
      $("#results").append($('<div id="loader_progress">'))
      $("#results").append($('<div id="loader_current">'))
      $("#results").append($landscape)

      $.getJSON(
      #  '/all_albums',
      #  '/list_all_albums',
        '/starts_with?value=all&attribute=key&otype=40',
      #  '/starts_with?value=all&attribute=album&otype=20&nochildren=1',
      #  '/all_artists',
        {}, stackupthecubes
      )


    cubes.reset = (opacity='1') ->
      console.log 'cubes.reset'
      all = ''
      for letter in 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z num other'.split(' ')
        if all
          all += ','
        all += ".cubelink.#{letter}"
      #document.styleSheets[0].addRule(all, "opacity: " + opacity)
      #$.rule('#content ul','style').remove();
      #$.rule(all + '{ opacity: '+opacity+'; }').appendTo(cubes.style);
      #if cubes.style.addRule
      #  cubes.style.addRule(all, "opacity: #{opacity}")
      #else
      #  cubes.style.insertRule("#{all} {opacity: #{opacity}}", cubes.style.cssRules.length)
      #$.rule(all, cubes.style).add "{ opacity: #{opacity}}"
      #$.rule(all + '{ opacity: '+opacity+'; }').appendTo('link');
      #$(all).css('opacity', opacity)
      #jss all, opacity: opacity
      #jss '.cublink.A', display: 'none'
      if document.styleSheets[0].addRule
        document.styleSheets[0].addRule(all, "opacity: #{opacity}")
      else
        document.styleSheets[0].insertRule("#{all} {opacity: #{opacity}}", document.styleSheets[0].cssRules.length)


    cubes.highlight = ($target) ->
      cubes.reset('0.3')
      console.log 'cubes.highlight'
      val = $target.text()
      if val is '#'
        val = 'num'
      if val is '⋯'
        val = 'other'
      #if cubes.style.addRule
      #  console.log 'addRule'
      #  cubes.style.addRule(".cubelink."+val, "opacity: 1")
      #else
      #  console.log 'insertRule:', cubes.style.insertRule
      #  cubes.style.insertRule(".cubelink."+val+" {opacity: 1}", cubes.style.cssRules.length)
      #$.rule('.cubelink.'+val+'{ opacity: 1; }').append(cubes.style)
      #$.rule(".cubelink.#{val}", cubes.style).add "{ opacity: 1}"
      #$.rule('.cubelink.'+val+'{ opacity: 1; }').appendTo('link')
      #$(".cubelink.#{val}").css('opacity', 1)
      #jss ".cubelink.#{val}", opacity: 1
      #jss ".cubelink.#{val}", display: 'block'
      #jss ".cubelink.A", display: 'block'
      if document.styleSheets[0].addRule
        document.styleSheets[0].addRule(".cubelink.#{val}", "opacity: 1")
      else
        document.styleSheets[0].insertRule(".cubelink.#{val} {opacity: 1}", document.styleSheets[0].cssRules.length)
      $target.parent().find('.stacklabel').removeClass 'active'
      $target.addClass 'active'

    cubes.click_handler = (e) ->
      console.log 'cubes.click_handler'
      $target = $(e.target)
      if $target.is '.stacklabel'
        if $target.is '.active'
          cubes.reset()
          $target.removeClass 'active'
        else
          cubes.highlight($target)
      else if $target.is '#landscape'
        cubes.reset()
        $target.parent().find('.stacklabel').removeClass 'active'
      else if $target.is '.cube'
        # this is only needed if you use <a> tags around the cubes
        console.log 'ignoring cube click'
        e.cancelBubble = true
        if e.stopPropagation
          e.stopPropagation();
        if (e.preventDefault)
          e.preventDefault()
        e.returnValue = false
        return false
      else if $target.is '#loadmusic'
        console.log 'initiating loadmusic!'
        $.getJSON '/loader', {}, ->
          $scene.append '<div>loading...</div>'
        return false


  ######### D3 attempt

    stackupthecubesD3 = (data) ->
      console.log 'data received'
      cubes.maxheight = 0
      x = 0
      y = -2
      top_adjust = +20  # nudge it into place
      left_adjust = -9
      html = ''
      for letter in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#⋯'
        pos = scene_transform(x, y)
        pos.top  += top_adjust
        pos.left += left_adjust
        html += "<div class='stacklabel', style='top:#{pos.top}px; left:#{pos.left}px'>#{letter}</div>"
        x += 1
      $scene.append $(html)

      html = ''

      height = []
      for x in [0..27]
        height[x] = []
        for y in [0..26]
          height[x][y] = []

      console.log 'starting to loop through the data...'
      for fileunder in data
        name = fileunder['key'] || ''
        if name is 'Unknown' || not name
          continue
        if name is 'Various' || name is 'Various Artists' || name is 'Soundtrack'
          continue
        if name is 'various' # there's currently a problem with various, everything appears under it! FIXME
          continue

        namehash = hash_code(name.substr(0,9))  # why do we limit it to the first 9 chars??
        color = namehash % 5
        if color < 0
          color = -color

        c0 = name.toUpperCase().charCodeAt(0) || 0
        #c1 = name.toUpperCase().charCodeAt(1) || 0  # unused? also: wasteful double uppercasing
        x = c0 - 65
        if x > 25 then x = 27
        if x < 0  then x = 26

        y = hash_code(name) # could we just use namehash from above?
        if y < 0  then y = -y
        y = y % 26

        for album in fileunder['albums']
          z = height[x][y].length
          #z_index = (1000-(x*30+(y-29)))
          z_index = (1000-(x*30+y))
          title = fileunder['name']
          shade = 0
          if album['album']
            title = title + ' - ' + album['album']
            if album['album'] and album['album'][0]
              albumhash = hash_code(album['album'][0].substr(0,9))  # again with the 0,9
            else
              albumhash = hash_code('')
            shade = albumhash % 7

          if shade < 0 then shade = -shade

          #title = title + ' (' + x + ',' + y + ',' + z + ',' + z_index + ',' + color + ',' + shade + ')'
          if x < 26
            rowclass = name.toUpperCase()[0]
          else if x is 26
            rowclass = 'num'
          else if x is 27
            rowclass = 'other'

          height[x][y].push( {x: x, y: y, z: z, color: color, z_index: z_index, rowclass: rowclass, title: title } )

      #data = d3.range(10).map(Math.random)
      data = []
      for x in [27..0] by -1
        for y in [26..0] by -1
          pile = height[x][y].length-1
          for z in [0..pile] by 1
            item = height[x][y][z]
            pos = scene_transform x, y, z
            item.ox = item.x
            item.x = pos.left
            item.oy = item.y
            item.y = pos.top
            data.push item

      console.log data.length
      #data = data[0..20000]

      width = 1200
      height = 1000
      outerRadius = Math.min(width, height) / 2
      innerRadius = outerRadius * .6
      color = d3.scale.category20()
      donut = d3.layout.pie()
      arc = d3.svg.arc().innerRadius(innerRadius).outerRadius(outerRadius)

      vis = d3.select(".scene").append("svg").data([data]).attr("width", width).attr("height", height)

      arcs = vis.selectAll("g.rect").data(donut).enter().append("rect").attr('x', (d) ->
          return d.data.x
        ).attr('y', (d, i) ->
          return 1000+d.data.y
        ).attr('fill', (d, i) ->
          return color(Math.random())
        ).attr('height', 10).attr('width', 10)

      #arcs = vis.selectAll("g.rect").data(donut).enter().append("g").attr("class", "rect").attr("transform", "translate(" + outerRadius + "," + outerRadius + ")")

      #arcs.append("path").attr("fill", (d, i) ->
      #    return color(i)
      #    ).attr("d", arc)

      #arcs.append("text").attr("transform", (d) ->
      #    return "translate(" + arc.centroid(d) + ")"
      #    ).attr("dy", ".35em").attr("text-anchor", "middle").attr("display", (d) ->
      #      return d.value > .15 ? null : "none"
      #    ).text (d, i) ->
      #      return d.value.toFixed(2)

      console.log 'done.'

      console.log 'inserting html string into the dom'
      $scene.append html
      console.log 'done.'

      console.log 'positioning the cubes'
      # position the cubes so the top fits on the landscape
      $cubes.css('top', (-cubes.maxheight + 20) + "px")

      console.log 'adjusting the landscape'
      # adjust the landscape grid to cover everything
      $landscape.height(-cubes.maxheight + 300)

      # this one seems to trigger the dom rending:
      console.log 'scrolling the window'
      # scroll the bottom in to view if it is not already
      container_bottom = $landscape.offset().top + $landscape.height()
      scroll_bottom = $('#results').parent().scrollTop() + $(window).height()
      if scroll_bottom < container_bottom-100
        $('#results').parent().scrollTop(container_bottom - $(window).height() - 100)
      console.log 'all done!'


    cubes.showD3 = ->
      $landscape = $("<div id='landscape' class='landscape'>")
      $cubes = $("<div id='cubes'>")
      $scene = $("<div class='scene'>")
      $landscape.append( $cubes.append( $scene ) )

      $("#results").empty().append($landscape)

      $.getJSON '/starts_with', { value: 'all', attribute: 'key', otype: 40 }, stackupthecubesD3


    return cubes
