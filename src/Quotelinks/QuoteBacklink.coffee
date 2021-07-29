QuoteBacklink =
  # Backlinks appending need to work for:
  #  - previous, same, and following posts.
  #  - existing and yet-to-exist posts.
  #  - newly fetched posts.
  #  - in copies.
  # XXX what about order for fetched posts?
  #
  # First callback creates backlinks and add them to relevant containers.
  # Second callback adds relevant containers into posts.
  # This is is so that fetched posts can get their backlinks,
  # and that as much backlinks are appended in the background as possible.
  containers: {}
  init: ->
    return if g.VIEW not in ['index', 'thread'] or !Conf['Quote Backlinks']

    Callbacks.Post.push
      name: 'Quote Backlinking Part 1'
      cb:   @firstNode
    Callbacks.Post.push
      name: 'Quote Backlinking Part 2'
      cb:   @secondNode
  firstNode: ->
    return if @isClone or !@quotes.length or @isRebuilt
    markYours = Conf['Mark Quotes of You'] and QuoteYou.db?.get {boardID: @board.ID, threadID: @thread.ID, postID: @ID}
    a = $.el 'a',
      href: Build.postURL @board.ID, @thread.ID, @ID
      className: if @isHidden then 'filtered backlink' else 'backlink'
      textContent: Conf['backlink'].replace(/%(?:id|%)/g, (x) => {'%id': @ID, '%%': '%'}[x]) + (if markYours then '\u00A0(You)' else '')
    for quote in @quotes
      containers = [QuoteBacklink.getContainer quote]
      if (post = g.posts[quote]) and post.nodes.backlinkContainer
        # Don't add OP clones when OP Backlinks is disabled,
        # as the clones won't have the backlink containers.
        for clone in post.clones
          containers.push clone.nodes.backlinkContainer
      for container in containers
        link = a.cloneNode true
        nodes = if container.firstChild then [$.tn(' '), link] else [link]
        if Conf['Quote Previewing']
          $.on link, 'mouseover', QuotePreview.mouseover
        if Conf['Quote Inlining']
          $.on link, 'click', QuoteInline.toggle
          if Conf['Quote Hash Navigation']
            hash = QuoteInline.qiQuote link, $.hasClass link, 'filtered'
            nodes.push hash
        $.add container, nodes
    return
  secondNode: ->
    if @isClone and (@origin.isReply or Conf['OP Backlinks'])
      @nodes.backlinkContainer = $ '.container', @nodes.info
      return
    # Don't backlink the OP.
    return unless @isReply or Conf['OP Backlinks']
    container = QuoteBacklink.getContainer @fullID
    @nodes.backlinkContainer = container
    $.add @nodes.info, container
  getContainer: (id) ->
    @containers[id] or=
      $.el 'span', className: 'container'
