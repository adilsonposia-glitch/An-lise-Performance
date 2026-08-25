(() => {
  const fileInput = document.getElementById('fileInput')
  const dropzone = document.getElementById('dropzone')
  const uploadButtons = [document.getElementById('uploadButton'), document.getElementById('browseButton'), document.getElementById('emptyUpload')]
  const placeholderTitles = { lotes: 'Lotes de conciliação', excecoes: 'Relatório de exceções', configuracoes: 'Configurações', auditoria: 'Auditoria' }
  const acceptedTypes = ['.csv', '.xlsx']

  const openFilePicker = () => fileInput.click()
  uploadButtons.forEach((button) => button?.addEventListener('click', openFilePicker))

  function showSelectedFile(file) {
    const extension = `.${file.name.split('.').pop().toLowerCase()}`
    if (!acceptedTypes.includes(extension)) {
      alert('Selecione um arquivo CSV ou XLSX.')
      fileInput.value = ''
      return
    }
    if (file.size > 50 * 1024 * 1024) {
      alert('O arquivo deve ter no máximo 50 MB.')
      fileInput.value = ''
      return
    }
    document.querySelector('.dropzone h2').textContent = file.name
    document.querySelector('.dropzone p').textContent = 'Arquivo selecionado. O preview e o mapa de colunas estarão disponíveis na próxima etapa.'
    document.querySelector('.status-strip strong').textContent = 'Arquivo pronto para revisão'
    document.querySelector('.status-strip small').textContent = `Última atividade: ${file.name}`
    document.querySelector('.strip-metrics div strong').textContent = '1'
  }

  fileInput.addEventListener('change', () => {
    const file = fileInput.files?.[0]
    if (file) showSelectedFile(file)
  })

  ;['dragenter', 'dragover'].forEach((name) => dropzone.addEventListener(name, (event) => {
    event.preventDefault()
    dropzone.classList.add('is-dragging')
  }))
  ;['dragleave', 'drop'].forEach((name) => dropzone.addEventListener(name, (event) => {
    event.preventDefault()
    dropzone.classList.remove('is-dragging')
  }))
  dropzone.addEventListener('drop', (event) => {
    const file = event.dataTransfer.files?.[0]
    if (file) showSelectedFile(file)
  })

  document.querySelectorAll('.nav-item').forEach((item) => item.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach((nav) => nav.classList.remove('active'))
    item.classList.add('active')
    const isInbox = item.dataset.view === 'inbox'
    document.getElementById('view-inbox').classList.toggle('hidden', !isInbox)
    document.getElementById('view-placeholder').classList.toggle('hidden', isInbox)
    if (!isInbox) document.getElementById('placeholderTitle').textContent = placeholderTitles[item.dataset.view] || 'Área do sistema'
  }))
})()
