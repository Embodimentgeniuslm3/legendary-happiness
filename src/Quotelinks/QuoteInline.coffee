QuoteInline =
  init: ->
    return if g.VIEW not in ['index', 'thread'] or !Conf['Quote Inlining']

    @process = if Conf['Quote Hash Navigation']
      (link, clone) ->
        $.after link, QuoteInline.qiQuote link, $.hasClass link, 'filtered' unless clone
        $.on link, 'click', QuoteInline.toggle

    else
      (link) ->
        $.on link, 'click', QuoteInline.toggle

    if Conf['Comment Expansion']
      ExpandComment.callbacks.push @node

    Post.callbacks.push
      name: 'Quote Inlining'
      cb:   @node

  node: ->
    {process} = QuoteInline
    {isClone} = @
    process link, isClone for link in @nodes.quotelinks
    process link, isClone for link in @nodes.backlinks
    return

  qiQuote: (link, hidden) ->
    name = "hashlink"
    name += " filtered" if hidden
    $.el 'a',
      className: name
      textContent: '#'
      href: link.href

  toggle: (e) ->
    return if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey or e.button isnt 0
    e.preventDefault()
    {boardID, threadID, postID} = Get.postDataFromLink @
    context = Get.contextFromNode @
    if $.hasClass @, 'inlined'
      QuoteInline.rm @, boardID, threadID, postID, context
    else
      return if $.x "ancestor::div[@id='pc#{postID}']", @
      QuoteInline.add @, boardID, threadID, postID, context
    @classList.toggle 'inlined'

  findRoot: (quotelink, isBacklink) ->
    if isBacklink
      quotelink.parentNode.parentNode
    else
      $.x 'ancestor-or-self::*[parent::blockquote][1]', quotelink

  add: (quotelink, boardID, threadID, postID, context) ->
    isBacklink = $.hasClass quotelink, 'backlink'
    inline = $.el 'div',
      id: "i#{postID}"
      className: 'inline'
    root = QuoteInline.findRoot(quotelink, isBacklink)
    $.after root, inline

    qroot = $.x 'ancestor::*[contains(@class,"postContainer")][1]', root

    $.addClass qroot, 'hasInline'
    new Fetcher boardID, threadID, postID, inline, context

    return unless (post = g.posts["#{boardID}.#{postID}"]) and
      context.thread is post.thread

    # Hide forward post if it's a backlink of a post in this thread.
    # Will only unhide if there's no inlined backlinks of it anymore.
    if isBacklink and Conf['Forward Hiding']
      $.addClass post.nodes.root, 'forwarded'
      post.forwarded++ or post.forwarded = 1

    # Decrease the unread count if this post
    # is in the array of unread posts.
    return unless Unread.posts
    Unread.readSinglePost post

  rm: (quotelink, boardID, threadID, postID, context) ->
    isBacklink = $.hasClass quotelink, 'backlink'
    # Select the corresponding inlined quote, and remove it.
    root = QuoteInline.findRoot quotelink, isBacklink
    root = $.x "following-sibling::div[@id='i#{postID}'][1]", root
    qroot = $.x 'ancestor::*[contains(@class,"postContainer")][1]', root
    $.rm root

    unless $ '.inline', qroot
      $.rmClass qroot, 'hasInline'

    # Stop if it only contains text.
    return unless el = root.firstElementChild

    # Dereference clone.
    post = g.posts["#{boardID}.#{postID}"]
    post.rmClone el.dataset.clone

    # Decrease forward count and unhide.
    if Conf['Forward Hiding'] and
      isBacklink and
      context.thread is g.threads["#{boardID}.#{threadID}"] and
      not --post.forwarded
        delete post.forwarded
        $.rmClass post.nodes.root, 'forwarded'

    # Repeat.
    while inlined = $ '.inlined', el
      {boardID, threadID, postID} = Get.postDataFromLink inlined
      QuoteInline.rm inlined, boardID, threadID, postID, context
      $.rmClass inlined, 'inlined'
    return
