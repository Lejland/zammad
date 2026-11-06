# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Local Zammad extension: import an HTML file into the signature editor.
#
# The file is read in the browser. Executable markup is removed before the
# preview is inserted, and Zammad's normal server-side rich-text sanitizer is
# still applied when the signature is saved.

# coffeelint: disable=camel_case_classes
class App.UiElement.signature_html_import extends Spine.Module
  @MAX_FILE_SIZE: 10 * 1024 * 1024

  @render: (attribute, params, form) ->
    container = $('<div class="signature-html-import"></div>')
    controls = $('<div></div>')
    selectButton = $('<button type="button" class="btn btn--secondary js-signature-html-select"></button>')
      .text(App.i18n.translateContent('Choose HTML file'))
    fileInput = $('<input type="file" class="hide js-signature-html-file" accept=".html,.htm,text/html,application/xhtml+xml">')
    filenameInput = $('<input type="hidden" name="source_filename">')
    sourceInput = $('<textarea class="hide" name="source_body"></textarea>')
    state = $('<div class="hide js-signature-html-state" style="margin-top: 8px;"></div>')
    stateLabel = $('<strong></strong>').text(App.i18n.translateContent('Imported file') + ': ')
    stateName = $('<span class="js-signature-html-name"></span>')
    help = $('<p class="help-block"></p>').text(
      App.i18n.translateContent('The HTML body is imported into the editor. Inline formatting and placeholders such as #{user.firstname} are preserved. Remote PNG, JPEG, GIF, and WebP images are embedded when the signature is saved.')
    )

    existingFilename = params?.source_filename || ''
    existingSource = params?.source_body || ''
    filenameInput.val(existingFilename)
    sourceInput.val(existingSource)

    updateState = (filename) ->
      if filename
        stateName.text(filename)
        state.removeClass('hide')
        selectButton.text(App.i18n.translateContent('Replace HTML file'))
      else
        stateName.text('')
        state.addClass('hide')
        selectButton.text(App.i18n.translateContent('Choose HTML file'))

    showError = (message) ->
      form.showAlert(message)
      fileInput.val('')

    selectButton.on('click', (event) ->
      event.preventDefault()
      fileInput.trigger('click')
    )

    fileInput.on('change', (event) =>
      file = event.currentTarget.files?[0]
      return if !file

      if !file.name.match(/\.html?$/i)
        showError(App.i18n.translateContent('Please choose a file ending in .html or .htm.'))
        return

      if file.size > @MAX_FILE_SIZE
        showError(App.i18n.translateContent('The HTML file is too large. The maximum size is 10 MB.'))
        return

      selectButton.prop('disabled', true)
      reader = new FileReader()

      reader.addEventListener('error', =>
        selectButton.prop('disabled', false)
        showError(App.i18n.translateContent('The HTML file could not be read.'))
      )

      reader.addEventListener('load', (loadEvent) =>
        selectButton.prop('disabled', false)
        source = "#{loadEvent.target.result || ''}"

        try
          result = @safeBody(source)
        catch error
          App.Log.error('Signature HTML import', error)
          showError(App.i18n.translateContent('The HTML file could not be parsed.'))
          return

        if !result.html.trim()
          showError(App.i18n.translateContent('The HTML file does not contain a usable body.'))
          return

        editor = form.form.find('[contenteditable][data-name=body]')
        if !editor.length
          showError(App.i18n.translateContent('The signature editor could not be found.'))
          return

        editor.html(result.html)
        editor.trigger('input')
        editor.trigger('change')
        filenameInput.val(file.name)
        sourceInput.val(source)
        updateState(file.name)
        fileInput.val('')

        message = App.i18n.translateContent('HTML signature imported. Review the preview, then select Submit to save it. Remote images will be embedded by Zammad.')
        if result.removedImages
          message += ' ' + App.i18n.translateContent('Some images were removed because they used local or unsupported addresses.')

        App.Event.trigger('notify',
          type: 'success'
          msg: message
          timeout: 5000
        )
      )

      reader.readAsText(file)
    )

    state.append(stateLabel).append(stateName)
    controls.append(selectButton).append(fileInput).append(state)
    container.append(controls).append(help).append(filenameInput).append(sourceInput)
    updateState(existingFilename)
    container

  @safeBody: (source) ->
    parser = new DOMParser()
    document = parser.parseFromString(source, 'text/html')
    removedImages = 0

    blockedTags = 'script,style,iframe,frame,frameset,object,embed,applet,form,input,button,textarea,select,option,link,meta,base'
    for element in Array.prototype.slice.call(document.querySelectorAll(blockedTags))
      element.parentNode?.removeChild(element)

    for element in Array.prototype.slice.call(document.body.querySelectorAll('*'))
      for attribute in Array.prototype.slice.call(element.attributes)
        name = attribute.name.toLowerCase()
        value = (attribute.value || '').replace(/[\u0000-\u001f\u007f\s]+/g, '')
        lowerValue = value.toLowerCase()

        if name.indexOf('on') is 0 || name in ['srcdoc', 'formaction', 'xlink:href']
          element.removeAttribute(attribute.name)
          continue

        if name in ['href', 'src', 'background']
          if lowerValue.match(/^(javascript|vbscript|file):/) || lowerValue.match(/^data:(?!image\/(png|gif|jpe?g|webp);base64,)/)
            element.removeAttribute(attribute.name)
            continue

        if name is 'style' && lowerValue.match(/expression\(|javascript:|vbscript:|-moz-binding|behavior:/)
          element.removeAttribute(attribute.name)

      if element.tagName.toLowerCase() is 'img'
        src = (element.getAttribute('src') || '').trim()
        if src.match(/^http:\/\//i)
          src = src.replace(/^http:\/\//i, 'https://')
          element.setAttribute('src', src)
        supported = src.match(/^https:\/\//i) || src.match(/^data:image\/(png|gif|jpe?g|webp);base64,/i)
        if !supported
          removedImages += 1
          element.parentNode?.removeChild(element)

    {
      html: document.body.innerHTML
      removedImages: removedImages
    }

for modelAttribute in ['source_body', 'source_filename']
  if App.Signature.attributes.indexOf(modelAttribute) is -1
    App.Signature.attributes.push(modelAttribute)

hasImportAttribute = _.find(App.Signature.configure_attributes, (item) ->
  item.name is 'signature_html_import'
)

if !hasImportAttribute
  bodyPosition = _.findIndex(App.Signature.configure_attributes, (item) ->
    item.name is 'body'
  )
  bodyPosition = 1 if bodyPosition < 0

  App.Signature.configure_attributes.splice(bodyPosition, 0,
    name: 'signature_html_import'
    display: __('Import HTML')
    tag: 'signature_html_import'
    'null': true
  )
