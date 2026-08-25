(() => {
  const fileInput = document.getElementById('fileInput')
  const dropzone = document.getElementById('dropzone')
  const uploadButtons = [document.getElementById('uploadButton'), document.getElementById('browseButton'), document.getElementById('emptyUpload')]
  const placeholderTitles = { lotes: 'Lotes de conciliação', excecoes: 'Relatório de exceções', configuracoes: 'Configurações', auditoria: 'Auditoria' }

  uploadButtons.forEach((button) => button?.addEventListener('click', () => fileInput.click()))
  fileInput.addEventListener('change', () => {
    const file = fileInput.files?.[0]
    if (!file) return
    const heading = document.querySelector('.dropzone h2')
    const copy = document.querySelector('.dropzone p')
    heading.textContent = file.name
    copy.textContent = 'Arquivo selecionado. O preview e o mapa de colunas estarão disponíveis na próxima etapa.'
  })
  ;['dragenter', 'dragover'].forEach((eventName) => dropzone.addEventListener(eventName, (event) => { event.preventDefault(); dropzone.classList.add('is-dragging') }))
  ;['dragleave', 'drop'].forEach((eventName) => dropzone.addEventListener(eventName, (event) => { event.preventDefault(); dropzone.classList.remove('is-dragging') }))
  dropzone.addEventListener('drop', (event) => { fileInput.files = event.dataTransfer.files; fileInput.dispatchEvent(new Event('change')) })

  document.querySelectorAll('.nav-item').forEach((item) => item.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach((nav) => nav.classList.remove('active'))
    item.classList.add('active')
    const view = item.dataset.view
    const inbox = document.getElementById('view-inbox')
    const placeholder = document.getElementById('view-placeholder')
    if (view === 'inbox') { inbox.classList.remove('hidden'); placeholder.classList.add('hidden') }
    else { inbox.classList.add('hidden'); placeholder.classList.remove('hidden'); document.getElementById('placeholderTitle').textContent = placeholderTitles[view] || 'Área do sistema' }
  }))
})()
