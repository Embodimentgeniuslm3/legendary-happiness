Embedding =
  init: ->
    return unless Conf['Embedding'] or Conf['Link Title']
    @types = {}
    @types[type.key] = type for type in @ordered_types

    if Conf['Floating Embeds']
      @dialog = UI.dialog 'embedding', 'top: 50px; right: 0px;',
        <%= importHTML('Features/Embed') %>
      @media = $ '#media-embed', @dialog
      $.one d, '4chanXInitFinished', @ready

    if Conf['Link Title']
      $.on d, '4chanXInitFinished PostsInserted', ->
        for key, service of Embedding.types when service.title?.batchSize
          Embedding.flushTitles service.title
        return

  events: (post) ->
    return unless Conf['Embedding']
    i = 0
    items = $$ '.embedder', post.nodes.comment
    while el = items[i++]
      $.on el, 'click', Embedding.cb.toggle
      Embedding.cb.toggle.call el if $.hasClass el, 'embedded'
    return

  process: (link, post) ->
    return unless Conf['Embedding'] or Conf['Link Title']
    return if $.x 'ancestor::pre', link
    if data = Embedding.services link
      data.post = post
      Embedding.embed data if Conf['Embedding']
      Embedding.title data if Conf['Link Title']

  services: (link) ->
    {href} = link
    for type in Embedding.ordered_types when match = type.regExp.exec href
      return if type.dummy
      return {key: type.key, uid: match[1], options: match[2], link}
    return

  embed: (data) ->
    {key, uid, options, link, post} = data
    {href} = link
    return if Embedding.types[key].httpOnly and location.protocol isnt 'http:'

    $.addClass link, key.toLowerCase()

    embed = $.el 'a',
      className:   'embedder'
      href:        'javascript:;'
      textContent: '(embed)'

    embed.dataset[name] = value for name, value of {key, uid, options, href}

    $.on embed, 'click', Embedding.cb.toggle
    $.after link, [$.tn(' '), embed]

    if Conf['Auto-embed'] and !Conf['Floating Embeds'] and !post.isFetchedQuote and key isnt 'TwitchTV' # XXX https://github.com/justintv/Twitch-API/issues/289
      $.asap (-> doc.contains embed), ->
        Embedding.cb.toggle.call embed

  ready: ->
    $.addClass Embedding.dialog, 'empty'
    $.on $('.close', Embedding.dialog), 'click',     Embedding.closeFloat
    $.on $('.move',  Embedding.dialog), 'mousedown', Embedding.dragEmbed
    $.on $('.jump',  Embedding.dialog), 'click', ->
      Header.scrollTo Embedding.lastEmbed if doc.contains Embedding.lastEmbed
    $.add d.body, Embedding.dialog

  closeFloat: ->
    delete Embedding.lastEmbed
    $.addClass Embedding.dialog, 'empty'
    $.replace Embedding.media.firstChild, $.el 'div'

  dragEmbed: ->
    # only webkit can handle a blocking div
    {style} = Embedding.media
    if Embedding.dragEmbed.mouseup
      $.off d, 'mouseup', Embedding.dragEmbed
      Embedding.dragEmbed.mouseup = false
      style.visibility = ''
      return
    $.on d, 'mouseup', Embedding.dragEmbed
    Embedding.dragEmbed.mouseup = true
    style.visibility = 'hidden'

  title: (data) ->
    {key, uid, options, link, post} = data
    return unless service = Embedding.types[key].title
    $.addClass link, key.toLowerCase()
    if service.batchSize
      (service.queue or= []).push data
      if service.queue.length >= service.batchSize
        Embedding.flushTitles service
    else
      unless $.cache service.api(uid), (-> Embedding.cb.title @, data), {responseType: 'json'}
        $.extend link, <%= html('[${key}] <span class="warning">Title Link Blocked</span> (are you using NoScript?)</a>') %>

  flushTitles: (service) ->
    {queue} = service
    return unless queue?.length
    service.queue = []
    cb = ->
      Embedding.cb.title @, data for data in queue
      return
    unless $.cache service.api(data.uid for data in queue), cb, {responseType: 'json'}
      for data in queue
        $.extend data.link, <%= html('[${data.key}] <span class="warning">Title Link Blocked</span> (are you using NoScript?)</a>') %>
    return

  cb:
    toggle: (e) ->
      e?.preventDefault()
      if Conf['Floating Embeds']
        return unless div = Embedding.media.firstChild
        $.replace div, Embedding.cb.embed @
        Embedding.lastEmbed = Get.postFromNode(@).nodes.root
        $.rmClass Embedding.dialog, 'empty'
        return
      if $.hasClass @, "embedded"
        $.rm @nextElementSibling
        @textContent = '(embed)'
      else
        $.after @, Embedding.cb.embed @
        @textContent = '(unembed)'
      $.toggleClass @, 'embedded'

    embed: (a) ->
      # We create an element to embed
      container = $.el 'div'
      $.add container, el = (type = Embedding.types[a.dataset.key]).el a

      # Set style values.
      el.style.cssText = if type.style?
        type.style
      else
        "border:0;width:640px;height:390px"

      return container

    title: (req, data) ->
      {key, uid, options, link, post} = data
      {status} = req
      service = Embedding.types[key].title

      text = "[#{key}] #{switch status
        when 200, 304
          service.text req.response, uid
        when 404
          "Not Found"
        when 403
          "Forbidden or Private"
        else
          "#{status}'d"
      }"

      link.dataset.original = link.textContent
      link.textContent = text
      for post2 in post.clones
        for link2 in $$ 'a.linkify', post2.nodes.comment when link2.href is link.href
          link2.dataset.original ?= link2.textContent
          link2.textContent = text
      return

  ordered_types: [
      key: 'audio'
      regExp: /\.(?:mp3|ogg|wav)(?:\?|$)/i
      style: ''
      el: (a) ->
        $.el 'audio',
          controls:    true
          preload:     'auto'
          src:         a.dataset.href
    ,
      key: 'Gist'
      regExp: /^\w+:\/\/gist\.github\.com\/(?:[\w\-]+\/)?(\w+)/
      el: (a) ->
        el = $.el 'iframe'
        el.setAttribute 'sandbox', 'allow-scripts'
        content = <%= html('<html><head><title>${a.dataset.uid}</title></head><body><script src="https://gist.github.com/${a.dataset.uid}.js"></script></body></html>') %>
        el.src = E.url content
        el
      title:
        api: (uid) -> "https://api.github.com/gists/#{uid}"
        text: ({files}) ->
          return file for file of files when files.hasOwnProperty file
    ,
      key: 'image'
      regExp: /\.(?:gif|png|jpg|jpeg|bmp)(?:\?|$)/i
      style: ''
      el: (a) ->
        $.el 'div', <%= html('<a target="_blank" href="${a.dataset.href}"><img src="${a.dataset.href}" style="max-width: 80vw; max-height: 80vh;"></a>') %>
    ,
      key: 'InstallGentoo'
      regExp: /^\w+:\/\/paste\.installgentoo\.com\/view\/(?:raw\/|download\/|embed\/)?(\w+)/
      el: (a) ->
        $.el 'iframe',
          src: "https://paste.installgentoo.com/view/embed/#{a.dataset.uid}"
    ,
      key: 'Twitter'
      regExp: /^\w+:\/\/(?:www\.)?twitter\.com\/(\w+\/status\/\d+)/
      el: (a) -> 
        $.el 'iframe',
          src: "https://twitframe.com/show?url=https://twitter.com/#{a.dataset.uid}"
    ,
      key: 'LiveLeak'
      regExp: /^\w+:\/\/(?:\w+\.)?liveleak\.com\/.*\?.*i=(\w+)/
      httpOnly: true
      style: 'border: none; width: 640px; height: 360px;'
      el: (a) ->
        el = $.el 'iframe',
          src: "http://www.liveleak.com/ll_embed?i=#{a.dataset.uid}",
        el.setAttribute "allowfullscreen", "true"
        el
    ,
      key: 'Pastebin'
      regExp: /^\w+:\/\/(?:\w+\.)?pastebin\.com\/(?!u\/)(?:[\w\.]+\?i\=)?(\w+)/
      httpOnly: true
      el: (a) ->
        div = $.el 'iframe',
          src: "http://pastebin.com/embed_iframe.php?i=#{a.dataset.uid}"
    ,
      key: 'Gfycat'
      regExp: /^\w+:\/\/(?:www\.)?gfycat\.com\/(?:iframe\/)?(\w+)/
      el: (a) ->
        div = $.el 'iframe',
          src: "//gfycat.com/iframe/#{a.dataset.uid}"
    ,
      key: 'SoundCloud'
      regExp: /^\w+:\/\/(?:www\.)?(?:soundcloud\.com\/|snd\.sc\/)([\w\-\/]+)/
      style: 'border: 0; width: 500px; height: 400px;'
      el: (a) ->
        $.el 'iframe',
          src: "https://w.soundcloud.com/player/?visual=true&show_comments=false&url=https%3A%2F%2Fsoundcloud.com%2F#{encodeURIComponent a.dataset.uid}"
      title:
        api: (uid) -> "//soundcloud.com/oembed?format=json&url=https%3A%2F%2Fsoundcloud.com%2F#{encodeURIComponent uid}"
        text: (_) -> _.title
    ,
      key: 'StrawPoll'
      regExp: /^\w+:\/\/(?:www\.)?strawpoll\.me\/(?:embed_\d+\/)?(\d+(?:\/r)?)/
      style: 'border: 0; width: 600px; height: 406px;'
      el: (a) ->
        $.el 'iframe',
          src: "//strawpoll.me/embed_1/#{a.dataset.uid}"
    ,
      key: 'TwitchTV'
      regExp: /^\w+:\/\/(?:www\.)?twitch\.tv\/(\w[^#\&\?]*)/
      style: "border: none; width: 620px; height: 378px;"
      el: (a) ->
        if result = /(\w+)\/([bcv])\/(\d+)/i.exec a.dataset.uid
          [_, channel, type, id] = result
          idprefix = if type is 'b' then 'a' else type
          flashvars = "channel=#{channel}&start_volume=25&auto_play=false&videoId=#{idprefix}#{id}"
          if start = a.dataset.href.match /\bt=(\w+)/
            seconds = 0
            for part in start[1].match /\d+[hms]/g
              seconds += +part[...-1] * {'h': 3600, 'm': 60, 's': 1}[part[-1..]]
            flashvars += "&initial_time=#{seconds}"
        else
          channel = (/(\w+)/.exec a.dataset.uid)[0]
          flashvars = "channel=#{channel}&start_volume=25&auto_play=false"
        obj = $.el 'object',
          data: '//www-cdn.jtvnw.net/swflibs/TwitchPlayer.swf'
        $.extend obj, <%= html('<param name="allowFullScreen" value="true"><param name="flashvars">') %>
        obj.children[1].value = flashvars
        obj
    ,
      key: 'Vocaroo'
      regExp: /^\w+:\/\/(?:www\.)?vocaroo\.com\/i\/(\w+)/
      style: ''
      el: (a) ->
        el = $.el 'audio',
          controls: true
          preload: 'auto'
        type = if el.canPlayType 'audio/ogg' then 'ogg' else 'mp3'
        el.src = "http://vocaroo.com/media_command.php?media=#{a.dataset.uid}&command=download_#{type}"
        el
    ,
      key: 'Vimeo'
      regExp:  /^\w+:\/\/(?:www\.)?vimeo\.com\/(\d+)/
      el: (a) ->
        $.el 'iframe',
          src: "//player.vimeo.com/video/#{a.dataset.uid}?wmode=opaque"
      title:
        api: (uid) -> "https://vimeo.com/api/oembed.json?url=https://vimeo.com/#{uid}"
        text: (_) -> _.title
    ,
      key: 'Vine'
      regExp: /^\w+:\/\/(?:www\.)?vine\.co\/v\/(\w+)/
      style: 'border: none; width: 500px; height: 500px;'
      el: (a) ->
        $.el 'iframe',
          src: "https://vine.co/v/#{a.dataset.uid}/card"
    ,
      key: 'YouTube'
      regExp: /^\w+:\/\/(?:youtu.be\/|[\w\.]*youtube[\w\.]*\/.*(?:v=|\/embed\/|\/v\/|\/videos\/))([\w\-]{11})[^#\&\?]?(.*)/
      el: (a) ->
        start = a.dataset.options.match /\b(?:star)?t\=(\w+)/
        start = start[1] if start
        if start and !/^\d+$/.test start
          start += ' 0h0m0s'
          start = 3600 * start.match(/(\d+)h/)[1] + 60 * start.match(/(\d+)m/)[1] + 1 * start.match(/(\d+)s/)[1]
        el = $.el 'iframe',
          src: "//www.youtube.com/embed/#{a.dataset.uid}?wmode=opaque#{if start then '&start=' + start else ''}"
        el.setAttribute "allowfullscreen", "true"
        el
      title:
        batchSize: 50
        api: (uids) ->
          ids = encodeURIComponent uids.join(',')
          key = '<%= meta.youtubeAPIKey %>'
          "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=#{ids}&fields=items%28id%2Csnippet%28title%29%29&key=#{key}"
        text: (data, uid) ->
          for item in data.items when item.id is uid
            return item.snippet.title
          'Not Found'
    ,
      key: 'Loopvid'
      regExp: /^\w+:\/\/(?:www\.)?loopvid.appspot.com\/#?((?:pf|kd|lv|gd|gh|db|dx|nn|cp|wu|ig|ky|mf|pc|gc)\/[\w\-\/]+(,[\w\-\/]+)*|fc\/\w+\/\d+)/
      style: 'max-width: 80vw; max-height: 80vh;'
      el: (a) ->
        el = $.el 'video',
          controls: true
          preload:  'auto'
          loop:     true
        [_, host, names] = a.dataset.uid.match /(\w+)\/(.*)/
        types = switch host
          when 'gd', 'wu', 'fc' then ['']
          when 'gc' then ['giant', 'fat', 'zippy']
          else ['.webm', '.mp4']
        for name in names.split ','
          for type in types
            base = "#{name}#{type}"
            url = switch host
              # list from src/common.py at http://loopvid.appspot.com/source.html
              when 'pf' then "https://web.archive.org/web/2/http://a.pomf.se/#{base}"
              when 'kd' then "http://kastden.org/loopvid/#{base}"
              when 'lv' then "http://kastden.org/_loopvid_media/lv/#{base}"
              when 'gd' then "https://docs.google.com/uc?export=download&id=#{base}"
              when 'gh' then "https://googledrive.com/host/#{base}"
              when 'db' then "https://dl.dropboxusercontent.com/u/#{base}"
              when 'dx' then "https://dl.dropboxusercontent.com/#{base}"
              when 'nn' then "http://naenara.eu/loopvids/#{base}"
              when 'cp' then "https://copy.com/#{base}"
              when 'wu' then "http://webmup.com/#{base}/vid.webm"
              when 'ig' then "https://i.imgur.com/#{base}"
              when 'ky' then "https://kiyo.me/#{base}"
              when 'mf' then "https://d.maxfile.ro/#{base}"
              when 'pc' then "http://a.pomf.cat/#{base}"
              when 'fc' then "//i.4cdn.org/#{base}.webm"
              when 'gc' then "https://#{type}.gfycat.com/#{name}.webm"
            $.add el, $.el 'source', src: url
        el
    ,
      key: 'Clyp'
      regExp: /^\w+:\/\/(?:www\.)?clyp\.it\/(\w+)/
      style: ''
      el: (a) ->
        el = $.el 'audio',
          controls: true
          preload: 'auto'
        type = if el.canPlayType 'audio/ogg' then 'ogg' else 'mp3'
        el.src = "https://clyp.it/#{a.dataset.uid}.#{type}"
        el
    ,
      # dummy entries: not implemented but included to prevent them being wrongly embedded as a subsequent type
      key: 'Loopvid-dummy'
      regExp: /^\w+:\/\/(?:www\.)?loopvid.appspot.com\//
      dummy: true
    ,
      key: 'MediaFire-dummy'
      regExp: /^\w+:\/\/(?:www\.)?mediafire.com\//
      dummy: true
    ,
      key: 'video'
      regExp: /\.(?:ogv|webm|mp4)(?:\?|$)/i
      style: 'max-width: 80vw; max-height: 80vh;'
      el: (a) ->
        $.el 'video',
          controls: true
          preload:  'auto'
          src:      a.dataset.href
          loop:     /^https?:\/\/i\.4cdn\.org\//.test a.dataset.href
  ]
