Captcha.replace =
  init: ->
    return unless g.SITE.software is 'yotsuba' and d.cookie.indexOf('pass_enabled=1') < 0

    new Connection null, 'https://www.google.com',
      recaptchaBlocked: ->
        msg = $.el 'div',
          <%= html('Google seems to have blocked you from using Recaptcha. [<a href="' + meta.captchaFAQ + '" target="_blank" rel="noopener">More info</a>]<br>Consider visiting <a href="' + meta.alternatives + '#${g.BOARD.ID}" target="_blank" rel="noopener">other imageboards</a>.') %>
        new Notice 'warning', msg

    if Conf['Force Noscript Captcha'] and Main.jsEnabled
      $.ready Captcha.replace.noscript
      return

    if Conf['captchaLanguage'].trim() or Conf['Captcha Fixes']
      if location.hostname in ['boards.4chan.org', 'boards.4channel.org']
        $.onExists doc, '#captchaFormPart', (node) -> $.onExists node, 'iframe', Captcha.replace.iframe
      else
        $.onExists doc, 'iframe', Captcha.replace.iframe

  noscript: ->
    return if not ((original = $ '#g-recaptcha') and (noscript = $ 'noscript', original.parentNode))
    span = $.el 'span',
      id: 'captcha-forced-noscript'
    $.replace noscript, span
    $.rm original
    insert = ->
      span.innerHTML = noscript.textContent
      Captcha.replace.iframe $('iframe', span)
    if (toggle = $ '#togglePostFormLink a, #form-link')
      $.on toggle, 'click', insert
    else
      insert()

  iframe: (iframe) ->
    if (lang = Conf['captchaLanguage'].trim())
      src = if /[?&]hl=/.test iframe.src
        iframe.src.replace(/([?&]hl=)[^&]*/, '$1' + encodeURIComponent lang)
      else
        iframe.src + "&hl=#{encodeURIComponent lang}"
      iframe.src = src unless iframe.src is src
    Captcha.replace.autocopy iframe

  autocopy: (iframe) ->
    return unless Conf['Captcha Fixes'] and /^https:\/\/www\.google\.com\/recaptcha\/api\/fallback\?/.test(iframe.src)
    new Connection iframe, 'https://www.google.com',
      working: ->
        if $.id('qr')?.contains iframe
          $('#qr .captcha-container textarea')?.parentNode.hidden = true
      token: (token) ->
        node = iframe
        while (node = node.parentNode)
          break if (textarea = $ 'textarea', node)
        textarea.value = token
        $.event 'input', null, textarea
      disabled: ->
        msg = $.el 'div',
          <%= html('Noscript captcha seems to be disabled on 4chan. [<a href="' + meta.captchaFAQ + '" target="_blank" rel="noopener">More info</a>]<br>You may be able to post if you uncheck &quot;Force Noscript Captcha&quot; in your settings.<br>Consider visiting <a href="' + meta.alternatives + '#${g.BOARD.ID}" target="_blank" rel="noopener">other imageboards</a>.') %>
        new Notice 'warning', msg
