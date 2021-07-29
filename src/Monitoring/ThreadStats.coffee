ThreadStats =
  init: ->
    return if g.VIEW isnt 'thread' or !Conf['Thread Stats']

    if Conf['Page Count in Stats']
      @[if g.SITE.isPrunedByAge?(g.BOARD) then 'showPurgePos' else 'showPage'] = true

    statsHTML = <%= html(
      '<span id="post-count">?</span> / <span id="file-count">?</span>' +
      '?{Conf["IP Count in Stats"]}{ / <span id="ip-count">?</span>}' +
      '?{Conf["Page Count in Stats"]}{ / <span id="page-count">?</span>}'
    ) %>
    statsTitle = 'Posts / Files'
    statsTitle += ' / IPs'  if Conf['IP Count in Stats']
    statsTitle += (if @showPurgePos then ' / Purge Position' else ' / Page') if Conf['Page Count in Stats']

    if Conf['Updater and Stats in Header']
      @dialog = sc = $.el 'span',
        id:    'thread-stats'
        title: statsTitle
      $.extend sc, statsHTML
      Header.addShortcut 'stats', sc, 200

    else
      @dialog = sc = UI.dialog 'thread-stats',
        <%= html('<div class="move" title="${statsTitle}">&{statsHTML}</div>') %>
      $.addClass doc, 'float'
      $.ready ->
        $.add d.body, sc

    @postCountEl = $ '#post-count', sc
    @fileCountEl = $ '#file-count', sc
    @ipCountEl   = $ '#ip-count',   sc
    @pageCountEl = $ '#page-count', sc

    $.on @pageCountEl, 'click', ThreadStats.fetchPage if @pageCountEl

    Callbacks.Thread.push
      name: 'Thread Stats'
      cb:   @node

  node: ->
    ThreadStats.thread = @
    ThreadStats.lastPost = @stats.lastPost
    ThreadStats.update()
    ThreadStats.fetchPage()
    $.on d, 'PostsInserted ThreadUpdate', ->
      $.queueTask ThreadStats.onUpdate unless ThreadStats.queued
      ThreadStats.queued = true

  onUpdate: ->
    delete ThreadStats.queued
    ThreadStats.update()
    if ThreadStats.showPage and ThreadStats.thread.stats.lastPost > ThreadStats.lastPost
      ThreadStats.lastPost = ThreadStats.thread.stats.lastPost
      if ThreadStats.pageCountEl.textContent isnt '1'
        ThreadStats.fetchPage()

  update: ->
    {thread, postCountEl, fileCountEl, ipCountEl} = ThreadStats
    {stats} = thread
    postCountEl.textContent = stats.posts
    fileCountEl.textContent = stats.opFiles + stats.replyFiles
    ipCountEl.textContent   = stats.IPs ? '?'
    postCountEl.classList.toggle 'warning', (thread.postLimit and !thread.isSticky)
    fileCountEl.classList.toggle 'warning', (thread.fileLimit and !thread.isSticky)

  fetchPage: ->
    return unless ThreadStats.pageCountEl
    clearTimeout ThreadStats.timeout
    if ThreadStats.thread.isDead
      ThreadStats.pageCountEl.textContent = 'Dead'
      $.addClass ThreadStats.pageCountEl, 'warning'
      return
    ThreadStats.timeout = setTimeout ThreadStats.fetchPage, 2 * $.MINUTE
    $.whenModified(
      g.SITE.urls.threadsListJSON({boardID: ThreadStats.thread.board}),
      'ThreadStats',
      ThreadStats.onThreadsLoad
    )

  onThreadsLoad: ->
    if @status is 200
      for page in @response
        if ThreadStats.showPurgePos
          purgePos = 1
          for thread in page.threads
            if thread.no < ThreadStats.thread.ID
              purgePos++
          ThreadStats.pageCountEl.textContent = purgePos
        else
          for thread in page.threads when thread.no is ThreadStats.thread.ID
            ThreadStats.pageCountEl.textContent = page.page
            (if page.page is @response.length then $.addClass else $.rmClass) ThreadStats.pageCountEl, 'warning'
            ThreadStats.lastPageUpdate = new Date thread.last_modified * $.SECOND
            ThreadStats.retry()
            return
    else if @status is 304
      ThreadStats.retry()

  retry: ->
    # If thread data is stale (modification date given < time of last post), try again.
    # Skip this on vichan sites due to sage posts not updating modification time in threads.json.
    return unless (
      ThreadStats.showPage and
      ThreadStats.pageCountEl.textContent isnt '1' and
      !g.SITE.threadModTimeIgnoresSage and
      ThreadStats.thread.posts[ThreadStats.thread.stats.lastPost].info.date > ThreadStats.lastPageUpdate
    )
    clearTimeout ThreadStats.timeout
    ThreadStats.timeout = setTimeout ThreadStats.fetchPage, 5 * $.SECOND
