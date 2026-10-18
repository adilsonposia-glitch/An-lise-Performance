<#
  Atualiza dashboard, Rede e Radar a partir de entradas\semana-atual.
  Formato fixo: Venda GBO *26.xlsx, Venda GBO *25.xlsx, Venda Rede *.csv, Estoques GBO*.xlsx
#>
[CmdletBinding()]
param(
  [string]$InputDir = ""
)

$ErrorActionPreference = "Stop"
try { $Host.UI.RawUI.WindowTitle = "Atualizar Semana" } catch { }
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }
Set-Location $Root
. (Join-Path $Root "build-data.ps1")

$inv = [System.Globalization.CultureInfo]::InvariantCulture
# build-data.ps1 pontuado redefine $InputDir para semana-nova — pasta do kit e outra.
$KitDir = if ($InputDir) { $InputDir } else { Join-Path $Root "entradas\semana-atual" }
if (-not (Test-Path -LiteralPath $KitDir)) { throw "Pasta nao encontrada: $KitDir" }
$Tmp = Join-Path $env:TEMP "atualizar-semana-gbo"
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
$script:TmpRoot = $Tmp

function Parse-Num([string]$s) {
  $d = 0.0
  if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return $d }
  return 0.0
}

function Expand-One([string]$src, [string]$destName) {
  $dest = Join-Path $Tmp $destName
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  New-Item -ItemType Directory -Path $dest | Out-Null
  Copy-Item -LiteralPath $src (Join-Path $dest "file.zip")
  Expand-Archive (Join-Path $dest "file.zip") (Join-Path $dest "content") -Force
  return $destName
}

function Find-Kit([string]$dir) {
  $files = @(Get-ChildItem -LiteralPath $dir -File)
  $v26 = $files | Where-Object { $_.Name -match 'GBO' -and $_.Name -match '26' -and $_.Extension -eq '.xlsx' -and $_.Name -notmatch 'Estoque' } | Select-Object -First 1
  $v25 = $files | Where-Object { $_.Name -match 'GBO' -and $_.Name -match '25' -and $_.Extension -eq '.xlsx' -and $_.Name -notmatch 'Estoque' } | Select-Object -First 1
  $rede = $files | Where-Object { $_.Name -match 'Rede' -and $_.Extension -eq '.csv' } | Select-Object -First 1
  $est = $files | Where-Object { $_.Name -match 'Estoque' -and $_.Extension -eq '.xlsx' } | Select-Object -First 1
  if (-not $v26) { throw "Faltou Venda GBO do ano atual (*26.xlsx) em $dir" }
  if (-not $v25) { throw "Faltou Venda GBO do ano anterior (*25.xlsx) em $dir" }
  return @{ v26 = $v26; v25 = $v25; rede = $rede; est = $est }
}

$Meses = @{
  JAN = 1; FEV = 2; MAR = 3; ABR = 4; MAI = 5; JUN = 6
  JUL = 7; AGO = 8; SET = 9; OUT = 10; NOV = 11; DEZ = 12
}

function Format-BR([datetime]$d) { return $d.ToString("dd/MM/yyyy") }

function Parse-PeriodoNome([string]$name) {
  $n = Normalize-Name $name
  if ($n -match '(\d{1,2})A(\d{1,2})(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)(\d{2})') {
    $m = [int]$Meses[$Matches[3]]; $y = 2000 + [int]$Matches[4]
    $d1 = Get-Date -Year $y -Month $m -Day ([int]$Matches[1])
    $d2 = Get-Date -Year $y -Month $m -Day ([int]$Matches[2])
    return @{ ini = $d1; fim = $d2; texto = "$(Format-BR $d1) a $(Format-BR $d2)" }
  }
  if ($n -match '(\d{1,2})(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)A(\d{1,2})(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)(\d{2})') {
    $y = 2000 + [int]$Matches[5]
    $d1 = Get-Date -Year $y -Month ([int]$Meses[$Matches[2]]) -Day ([int]$Matches[1])
    $d2 = Get-Date -Year $y -Month ([int]$Meses[$Matches[4]]) -Day ([int]$Matches[3])
    return @{ ini = $d1; fim = $d2; texto = "$(Format-BR $d1) a $(Format-BR $d2)" }
  }
  return $null
}

function Parse-PosicaoNome([string]$name, [int]$ano) {
  $n = Normalize-Name $name
  if ($n -match '(\d{1,2})(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)') {
    $d = Get-Date -Year $ano -Month ([int]$Meses[$Matches[2]]) -Day ([int]$Matches[1])
    return (Format-BR $d)
  }
  return $null
}

function Test-FooterOrTotal([string]$s) {
  $t = ([string]$s).Trim()
  if ([string]::IsNullOrWhiteSpace($t)) { return $true }
  if ($t -eq "Total") { return $true }
  if ($t.StartsWith("Filtros") -or $t.StartsWith("Data ") -or $t.StartsWith("nomereduzido")) { return $true }
  if ($t.StartsWith("Eixo ") -or $t.StartsWith("Parametro") -or $t.StartsWith("Parâmetro")) { return $true }
  if ($t.StartsWith("Semana ") -or $t.StartsWith("Ano ") -or $t.StartsWith("Nome do")) { return $true }
  if ($t.StartsWith("Filtro ")) { return $true }
  if ($t.Length -gt 80) { return $true }
  return $false
}

function Test-BlankCat([string]$s) {
  $t = ([string]$s).Trim()
  return [string]::IsNullOrWhiteSpace($t) -or $t -eq "Total"
}

function Get-ColMap([System.Collections.Generic.List[string]]$vals) {
  $m = @{}
  for ($i = 0; $i -lt $vals.Count; $i++) {
    $n = Normalize-Name $vals[$i]
    if ($n -eq "EMPRESA") { $m.emp = $i }
    elseif ($n -eq "FORNECEDOR") { $m.forn = $i }
    elseif ($n -eq "CATEGORIA 1") { $m.c1 = $i }
    elseif ($n -eq "CATEGORIA 2") { $m.c2 = $i }
    elseif ($n -eq "CATEGORIA 3") { $m.c3 = $i }
    elseif ($n -eq "CATEGORIA 4") { $m.c4 = $i }
    elseif ($n -eq "COMPRADOR") { $m.comp = $i }
    elseif ($n -match "VALOR DE VENDAS") { $m.venda = $i }
    elseif ($n -match "LUCRO BRUTO") { $m.lucro = $i }
    elseif ($n -match "VENDA EM QUANTIDADE") { $m.qtd = $i }
    elseif ($n -match "QUANTIDADE DE CLIENTES") { $m.cli = $i }
    elseif ($n -match "TICKET MEDIO") { $m.tkt = $i }
    elseif ($n -match "SKU") { $m.sku = $i }
    elseif ($n -match "VALOR DO ESTOQUE") { $m.estq = $i }
    elseif ($n -match "MEDIA DE VENDA CUSTO") { $m.media = $i }
    elseif ($n -match "DIAS DE COBERTURA") { $m.dias = $i }
    elseif ($n -match "ESTOQUE PENDENTE") { $m.pend = $i }
  }
  return $m
}

function Cell([System.Collections.Generic.List[string]]$vals, $idx) {
  if ($null -eq $idx -or $idx -lt 0 -or $idx -ge $vals.Count) { return "" }
  return [string]$vals[$idx]
}

function Read-SheetRows([string]$folder, [scriptblock]$onHeader, [scriptblock]$onRow) {
  $path = Join-Path $Tmp "$folder\content\xl\worksheets\sheet1.xml"
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.IgnoreWhitespace = $true
  $r = [System.Xml.XmlReader]::Create($path, $settings)
  $vals = New-Object System.Collections.Generic.List[string]
  $inRow = $false
  $cellHadValue = $false
  $rowN = 0
  $map = $null
  while ($r.Read()) {
    if ($r.NodeType -eq "Element" -and $r.LocalName -eq "row") {
      $vals.Clear(); $inRow = $true; $cellHadValue = $false
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "c" -and $inRow) {
      $cellHadValue = $false
      if ($r.IsEmptyElement) { [void]$vals.Add("") }
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "v" -and $inRow) {
      [void]$vals.Add($r.ReadElementContentAsString()); $cellHadValue = $true
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "t" -and $inRow) {
      [void]$vals.Add($r.ReadElementContentAsString()); $cellHadValue = $true
    }
    elseif ($r.NodeType -eq "EndElement" -and $r.LocalName -eq "c" -and $inRow) {
      if (-not $cellHadValue) { [void]$vals.Add("") }
    }
    elseif ($r.NodeType -eq "EndElement" -and $r.LocalName -eq "row") {
      $rowN++
      $inRow = $false
      if ($rowN -eq 1) { $map = Get-ColMap $vals; & $onHeader $map $vals; continue }
      & $onRow $map $vals
    }
  }
  $r.Close()
}

function Parse-GboVenda([string]$folder) {
  Write-Host "  venda $folder ..."
  $lojas = @{}; $merch = New-Object System.Collections.Generic.List[object]
  $footer = New-Object System.Collections.Generic.List[string]
  Read-SheetRows $folder {
    param($map, $vals)
    if (-not $map.ContainsKey("emp") -or -not $map.ContainsKey("venda")) { throw "Cabecalho GBO sem Empresa/Valor de Vendas" }
  } {
    param($map, $vals)
    $emp = Cell $vals $map.emp
    if (Test-FooterOrTotal $emp -and $emp.Trim() -ne "Total") {
      if ($emp.Trim()) { [void]$footer.Add($emp) }
      return
    }
    $c1 = Cell $vals $map.c1; $c2 = Cell $vals $map.c2; $c3 = Cell $vals $map.c3; $c4 = Cell $vals $map.c4
    $v = Parse-Num (Cell $vals $map.venda)
    $l = Parse-Num (Cell $vals $map.lucro)
    $q = Parse-Num (Cell $vals $map.qtd)
    $cli = Parse-Num (Cell $vals $map.cli)
    $tkt = Parse-Num (Cell $vals $map.tkt)
    if (Test-BlankCat $emp) { return }
    if (Test-BlankCat $c1) {
      $lojas[$emp] = [pscustomobject]@{
        nome = $emp
        venda = [math]::Round($v, 2)
        quantidade = [math]::Round($q, 2)
        lucro = [math]::Round($l, 2)
        margem = $(if ($v) { [math]::Round($l / $v, 6) } else { 0 })
        clientes = [math]::Round($cli, 0)
        ticket = $(if ($tkt) { [math]::Round($tkt, 2) } elseif ($cli) { [math]::Round($v / $cli, 2) } else { $null })
      }
    } elseif (Test-BlankCat $c2) {
      if (-not (Test-Excluded $c1)) { [void]$merch.Add([pscustomobject]@{ emp = $emp; grain = "dept"; nome = $c1; venda = $v; lucro = $l; qtd = $q }) }
    } elseif (Test-BlankCat $c3) {
      if (-not (Test-Excluded $c2)) { [void]$merch.Add([pscustomobject]@{ emp = $emp; grain = "secao"; nome = $c2; venda = $v; lucro = $l; qtd = $q }) }
    } elseif (Test-BlankCat $c4) {
      if (-not (Test-Excluded $c3)) { [void]$merch.Add([pscustomobject]@{ emp = $emp; grain = "grupo"; nome = $c3; venda = $v; lucro = $l; qtd = $q }) }
    }
  }
  Write-Host ("    lojas={0} merch={1}" -f $lojas.Count, $merch.Count)
  return @{ lojas = @($lojas.Values); merch = $merch; footer = ($footer -join " ") }
}

function Acc-Merch($items, $exclude) {
  $dept = @{}; $sec = @{}; $gru = @{}
  foreach ($x in $items) {
    if ($exclude -and $exclude.Contains($x.emp)) { continue }
    $name = [string]$x.nome
    if ([string]::IsNullOrWhiteSpace($name) -or $name -eq "Total") { continue }
    $map = $null
    if ($x.grain -eq "dept") { $map = $dept }
    elseif ($x.grain -eq "secao") { $map = $sec }
    elseif ($x.grain -eq "grupo") { $map = $gru }
    else { continue }
    if (-not $map.ContainsKey($name)) {
      $map[$name] = [pscustomobject]@{ nome = $name; venda = 0.0; quantidade = 0.0; lucro = 0.0; margem = 0.0; clientes = $null; ticket = $null }
    }
    $map[$name].venda += $x.venda
    $map[$name].lucro += $x.lucro
    $map[$name].quantidade += $x.qtd
  }
  $out = @{}
  foreach ($pair in @(@("dept", $dept), @("secao", $sec), @("grupo", $gru))) {
    $map = $pair[1]
    foreach ($k in @($map.Keys)) {
      $o = $map[$k]
      $o.venda = [math]::Round($o.venda, 2)
      $o.lucro = [math]::Round($o.lucro, 2)
      $o.quantidade = [math]::Round($o.quantidade, 2)
      $o.margem = $(if ($o.venda) { [math]::Round($o.lucro / $o.venda, 6) } else { 0 })
    }
    $out[$pair[0]] = @($map.Values | Sort-Object nome)
  }
  return $out
}

function Clear-ResidualZeroSales($rows) {
  foreach ($r in $rows) {
    if ([double]$r.venda -le 0) {
      $r.venda = 0; $r.lucro = 0; $r.quantidade = 0; $r.margem = 0; $r.clientes = 0; $r.ticket = $null
    }
  }
  return $rows
}

function New-MerchPhase($key, $label, $t25, $t26, $m25rows, $m26rows, $src25, $src26, $mesmaLabel) {
  $todas = Build-Base @(Compare-Years $t25 $t26) $false
  $mesma = Build-Base @(Compare-Years $m25rows $m26rows) $false
  return [ordered]@{
    key = $key; label = $label; hasClients = $false
    sources = [ordered]@{
      todas = [ordered]@{ y2025 = $src25; y2026 = $src26 }
      mesma = [ordered]@{ y2025 = $src25; y2026 = $mesmaLabel }
    }
    bases = [ordered]@{
      todas = [ordered]@{ totals = $todas.totals; agressores = $todas.agressores; melhores = $todas.melhores; rows = $todas.rows }
      mesma = [ordered]@{ totals = $mesma.totals; agressores = $mesma.agressores; melhores = $mesma.melhores; rows = $mesma.rows }
    }
  }
}

function Resolve-Periodo($file, $footer, $fallbackNome) {
  $fromName = Parse-PeriodoNome $file.Name
  if ($footer -match "depois de (\d{2}/\d{2}/\d{4}).*antes de (\d{2}/\d{2}/\d{4})") {
    $ini = [datetime]::ParseExact($Matches[1], "dd/MM/yyyy", $inv)
    $fimEx = [datetime]::ParseExact($Matches[2], "dd/MM/yyyy", $inv)
    $fim = $fimEx.AddDays(-1)
    return @{ texto = "$(Format-BR $ini) a $(Format-BR $fim)"; aviso = $null }
  }
  if ($fromName) { return @{ texto = $fromName.texto; aviso = "Periodo pelo nome do arquivo (rodape sem data final): $($file.Name)" } }
  throw "Nao deu para ler o periodo de $($file.Name)"
}

# --- kit ---
$kit = Find-Kit $KitDir
Write-Host "Kit em $KitDir"
Write-Host "  2026 $($kit.v26.Name)"
Write-Host "  2025 $($kit.v25.Name)"
if ($kit.rede) { Write-Host "  Rede $($kit.rede.Name)" } else { Write-Host "  Rede AUSENTE" }
if ($kit.est) { Write-Host "  Estoque $($kit.est.Name)" } else { Write-Host "  Estoque AUSENTE" }

$n25 = Expand-One $kit.v25.FullName "gbo25"
$n26 = Expand-One $kit.v26.FullName "gbo26"
$p25 = Parse-GboVenda $n25
$p26 = Parse-GboVenda $n26
$per25 = Resolve-Periodo $kit.v25 $p25.footer $kit.v25.Name
$per26 = Resolve-Periodo $kit.v26 $p26.footer $kit.v26.Name
if ($per25.aviso) { Write-Host "AVISO: $($per25.aviso)" }
if ($per26.aviso) { Write-Host "AVISO: $($per26.aviso)" }

$lojas25 = Clear-ResidualZeroSales @($p25.lojas)
$lojas26 = @($p26.lojas)
$allLojas = @(Compare-Years $lojas25 $lojas26)
$split = Split-StoreBases $allLojas
$novasNames = @($split.novas | ForEach-Object { $_.nome })
$exclude = New-Object "System.Collections.Generic.HashSet[string]"
foreach ($n in $novasNames) { [void]$exclude.Add($n) }
$m25t = Acc-Merch $p25.merch $null
$m26t = Acc-Merch $p26.merch $null
$m25m = Acc-Merch $p25.merch $exclude
$m26m = Acc-Merch $p26.merch $exclude
$src25 = $kit.v25.Name
$src26 = $kit.v26.Name
$mesmaSrc = if ($novasNames.Count -gt 0) { "$src26 (sem novas: $($novasNames -join ', '))" } else { "$src26 (mesma = todas)" }

$lojasPhase = [ordered]@{
  key = "lojas"; label = "Lojas"; hasClients = $true
  sources = [ordered]@{
    todas = [ordered]@{ y2025 = $src25; y2026 = $src26 }
    mesma = [ordered]@{ y2025 = $src25; y2026 = $mesmaSrc }
  }
  storeMeta = [ordered]@{
    allCount = $allLojas.Count
    comparableCount = $split.mesma.Count
    novasCount = $split.novas.Count
    novasNames = $novasNames
  }
  bases = [ordered]@{
    todas = (Build-Base $allLojas $true)
    mesma = (Build-Base $split.mesma $true)
  }
}

Write-Host ("Lojas Todas V26={0:N0} cli={1:N0}  Mesma V26={2:N0} lojas={3} novas={4}" -f `
  $lojasPhase.bases.todas.totals.venda2026, $lojasPhase.bases.todas.totals.clientes2026, `
  $lojasPhase.bases.mesma.totals.venda2026, $split.mesma.Count, $(if ($novasNames) { $novasNames -join "," } else { "-" }))

$payload = [ordered]@{
  meta = [ordered]@{
    titulo = "Analise de Performance Comercial"
    periodoLabel = "Sexta a Quinta - Ano contra Ano"
    periodo2025 = $per25.texto
    periodo2026 = $per26.texto
    anoBase = 2025
    anoAtual = 2026
    excluidos = @("NAO REVENDA", "INATIVOS", "SERVICOS", "RECICLAVEIS", "FRETE")
    geradoEm = (Get-Date -Format "yyyy-MM-dd HH:mm")
  }
  storeMeta = $lojasPhase.storeMeta
  phases = @(
    (New-MerchPhase "departamentos" "Departamentos" $m25t.dept $m26t.dept $m25m.dept $m26m.dept $src25 $src26 $mesmaSrc),
    $lojasPhase,
    (New-MerchPhase "secao" "Mercadologico - Secao" $m25t.secao $m26t.secao $m25m.secao $m26m.secao $src25 $src26 $mesmaSrc),
    (New-MerchPhase "grupos" "Mercadologico - Grupos" $m25t.grupo $m26t.grupo $m25m.grupo $m26m.grupo $src25 $src26 $mesmaSrc)
  )
}

$bundle = Read-Bundle
$bundle = Add-WeekToBundle $bundle $payload 0
Write-Bundle $bundle
Write-Host "Dashboard OK. Semanas:"
$bundle.weeks | ForEach-Object {
  $st = if ($_.hasData) { "{0}  novas={1}" -f $_.meta.periodo2026, $_.storeMeta.novasCount } else { "sem dados" }
  Write-Host ("  {0}: {1}" -f $_.label, $st)
}

# --- Rede ---
if ($kit.rede) {
  Write-Host "Rede..."
  & (Join-Path $Root "build-rede.ps1") -Csv2026 $kit.rede.FullName -Periodo2025 $per25.texto -Periodo2026 $per26.texto -SemanaLabel "4ª Semana"
} else {
  Write-Host "Rede pulada (sem CSV)."
}

# --- Estoque / radar ---
if (-not $kit.est) {
  Write-Host "Radar pulado (sem Excel de estoque)."
  return
}

function Get-NameKey([string]$name) {
  $n = Normalize-Name $name
  if ($n -match '\((\d+)\)\s*$') { return "ID:$($Matches[1])" }
  return ($n -replace '\s*\(\d+\)\s*$', "").Trim()
}
function Get-BaseNameKey([string]$name) {
  $n = Normalize-Name $name
  return ($n -replace '\s*\(\d+\)\s*$', "").Trim()
}
function Test-SkipEstoqueItem([string]$secao, [string]$grupo) {
  $s = Normalize-Name $secao
  $g = Normalize-Name $grupo
  if ($s -match "\bBAZAR\b" -and $g -match "BOLSAS E SACOLAS") { return $true }
  if ($s -match "\bPADARIA\b" -and ($g -match "^LANCHONETE\b" -or $g -match "PADARIA FABRICACAO")) { return $true }
  return $false
}

Write-Host "Estoque $($kit.est.Name) ..."
$nEst = Expand-One $kit.est.FullName "gboest"
$anoAtual = 2026
if ($per26.texto -match "(\d{4})$") { $anoAtual = [int]$Matches[1] }
$posicao = Parse-PosicaoNome $kit.est.Name $anoAtual
if (-not $posicao) { $posicao = (Get-Date).ToString("dd/MM/yyyy") }

function Test-SkipRadarLoja([string]$loja) {
  $n = Normalize-Name $loja
  if ($n -match "CENTRAL|\b70\b") { return $true }
  if ($n -match "P\.?\s*LUCAS|\b17\s*-") { return $true }
  if ($n -match "^02\s*-" -or $n -match "^04\s*-") { return $true }
  return $false
}
function Get-Sid([string]$loja) {
  $n = Normalize-Name $loja
  if ($n -match "^(\d+)") { return $Matches[1] }
  return $n
}

$storeVal = @{}; $storeQtd = @{}; $lojaMeta = @{}
$grp = @{}; $mx = @{}; $forn = @{}
Read-SheetRows $nEst { param($map, $vals) } {
  param($map, $vals)
  $emp = Cell $vals $map.emp
  if (Test-FooterOrTotal $emp -and $emp.Trim() -ne "Total") { return }
  if ([string]::IsNullOrWhiteSpace($emp) -or $emp -eq "Total") { return }
  if ($emp -match "Exported data|omitted|allowed volume") { return }
  $fornN = Cell $vals $map.forn
  $c1 = Cell $vals $map.c1; $c2 = Cell $vals $map.c2; $c3 = Cell $vals $map.c3; $c4 = Cell $vals $map.c4
  $valor = Parse-Num (Cell $vals $map.estq)
  $media = Parse-Num (Cell $vals $map.media)
  $dias = Parse-Num (Cell $vals $map.dias)
  $sku = Parse-Num (Cell $vals $map.sku)
  $pend = Parse-Num (Cell $vals $map.pend)
  $sid = Get-Sid $emp
  if (-not $lojaMeta.ContainsKey($sid)) {
    $lojaMeta[$sid] = [ordered]@{
      id = $sid; nome = $emp; short = (($emp -replace "^\d+\s*-\s*", "").Trim())
      papel = $(if ($sid -eq "70") { "cd" } else { "loja" })
    }
  }
  if (Test-BlankCat $fornN) {
    if (-not $storeVal.ContainsKey($sid) -or $valor -gt [double]$storeVal[$sid]) {
      $storeVal[$sid] = $valor
      $storeQtd[$sid] = $sku
    }
    return
  }
  if (Test-BlankCat $c1) {
    $nk = Normalize-Name $fornN
    if (-not $forn.ContainsKey($nk)) { $forn[$nk] = @{ nome = $fornN; l = 0.0; cd = 0.0; mediaL = 0.0; mediaCd = 0.0 } }
    if ($sid -eq "70") { $forn[$nk].cd += $valor; $forn[$nk].mediaCd += $media }
    else { $forn[$nk].l += $valor; $forn[$nk].mediaL += $media }
    return
  }
  if ((-not (Test-BlankCat $c3)) -and (Test-BlankCat $c4)) {
    if (Test-Excluded $c3) { return }
    if ($c2 -and (Test-SkipEstoqueItem $c2 $c3)) { return }
    if (-not (Test-SkipRadarLoja $emp)) {
      $gk = Get-NameKey $c3
      if (-not $grp.ContainsKey($gk)) {
        $grp[$gk] = [pscustomobject]@{
          nome = $c3; key = $gk; secao = $c2; dept = $c1
          skus = 0.0; valor = 0.0; mediaCustoDia = 0.0; diasCobertura = $null; estoquePendente = 0.0; qtd = 0.0
          excluido = $false
        }
      }
      $grp[$gk].valor += $valor
      $grp[$gk].skus += $sku
      $grp[$gk].mediaCustoDia += $media
      $grp[$gk].estoquePendente += $pend
    }
  }
  if (-not (Test-BlankCat $c4)) {
    if (Test-SkipEstoqueItem $c2 $c3) { return }
    $mk = Normalize-Name $c4
    if (-not $mx.ContainsKey($mk)) { $mx[$mk] = @{ subgrupo = $c4.Trim(); grupo = $c3.Trim(); secao = $c2; by = @{} } }
    if (-not $mx[$mk].by.ContainsKey($sid)) { $mx[$mk].by[$sid] = @{ valor = 0.0; qtd = 0.0 } }
    $mx[$mk].by[$sid].valor += $valor
    $mx[$mk].by[$sid].qtd += $sku
  }
}

$estoques = @($grp.Values | ForEach-Object {
  $_.valor = [math]::Round($_.valor, 2)
  $_.skus = [math]::Round($_.skus, 0)
  $_
})
Write-Host ("  lojas no arquivo: {0}" -f (($lojaMeta.Values | ForEach-Object { $_.nome }) -join ", "))
Write-Host ("  grupos radar={0}" -f $estoques.Count)

# cobertura 4 semanas (data.json ja atualizado)
$bundle2 = Get-Content (Join-Path $Root "data.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$series = @{}; $periodos = @()
foreach ($w in @($bundle2.weeks | Sort-Object ordem)) {
  if (-not $w.hasData) { continue }
  $periodos += [ordered]@{ ordem = [int]$w.ordem; label = [string]$w.label; periodo2026 = [string]$w.meta.periodo2026 }
  $ord = [int]$w.ordem
  $gruP = @($w.phases | Where-Object { $_.key -eq "grupos" } | Select-Object -First 1)
  if (-not $gruP) { continue }
  $rows = $gruP.bases.mesma.rows
  if (-not $rows) { $rows = $gruP.bases.todas.rows }
  foreach ($r in @($rows)) {
    $key = Get-NameKey ([string]$r.nome)
    if (-not $series.ContainsKey($key)) { $series[$key] = [ordered]@{ nome = [string]$r.nome; key = $key; qtd = @{}; venda = @{}; lucro = @{} } }
    $series[$key].qtd[$ord] = [double]$r.qtd2026
    $series[$key].venda[$ord] = [double]$r.venda2026
    $series[$key].lucro[$ord] = [double]$r.lucro2026
  }
}
function Get-AlignedLocal($byOrdem) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($p in $periodos) {
    $ord = [int]$p.ordem
    if ($byOrdem -and $byOrdem.ContainsKey($ord)) { $list.Add([math]::Round([double]$byOrdem[$ord], 2)) }
    else { $list.Add($null) }
  }
  return , $list.ToArray()
}
function Get-AvgPresent($arr) {
  $present = @($arr | Where-Object { $null -ne $_ })
  if ($present.Count) { return ($present | Measure-Object -Average).Average }
  return 0
}
$vendaMap = @{}
foreach ($key in $series.Keys) {
  $qtds = Get-AlignedLocal $series[$key].qtd
  $vendas = Get-AlignedLocal $series[$key].venda
  $cmvBy = @{}
  foreach ($ord in @($series[$key].venda.Keys)) {
    $cmvBy[$ord] = [double]$series[$key].venda[$ord] - $(if ($series[$key].lucro.ContainsKey($ord)) { [double]$series[$key].lucro[$ord] } else { 0 })
  }
  $qPresent = @($qtds | Where-Object { $null -ne $_ })
  $vendaMap[$key] = [ordered]@{
    nome = $series[$key].nome; semanas = $qPresent.Count
    qtdMediaSemanal = [math]::Round((Get-AvgPresent $qtds), 2)
    qtdTotal4s = if ($qPresent.Count) { [math]::Round(($qPresent | Measure-Object -Sum).Sum, 2) } else { 0 }
    qtdsPorSemana = $qtds
    vendaMediaSemanal = [math]::Round((Get-AvgPresent $vendas), 2)
    cmvMediaSemanal = [math]::Round((Get-AvgPresent (Get-AlignedLocal $cmvBy)), 2)
  }
}
$vendaByBase = @{}
foreach ($key in $vendaMap.Keys) {
  $base = Get-BaseNameKey $vendaMap[$key].nome
  if ($base -and -not $vendaByBase.ContainsKey($base)) { $vendaByBase[$base] = $vendaMap[$key] }
}
function Resolve-VendaG($e) {
  if ($vendaMap.ContainsKey($e.key)) { return $vendaMap[$e.key] }
  $base = Get-BaseNameKey $e.nome
  if ($base -and $vendaByBase.ContainsKey($base)) { return $vendaByBase[$base] }
  return $null
}
function Get-Cob($valor, $v, $excelDias) {
  if ($valor -le 0) { return @{ dias = 0; semanas = 0; demanda = $null; base = "zerado" } }
  if ($v -and [double]$v.cmvMediaSemanal -gt 0) {
    $sem = $valor / [double]$v.cmvMediaSemanal
    return @{ dias = [math]::Round($sem * 7, 1); semanas = [math]::Round($sem, 2); demanda = [math]::Round($v.cmvMediaSemanal, 0); base = "cmv4s" }
  }
  if ($null -ne $excelDias) {
    return @{ dias = [double]$excelDias; semanas = [math]::Round([double]$excelDias / 7, 2); demanda = $null; base = "excel" }
  }
  return @{ dias = $null; semanas = $null; demanda = $null; base = $null }
}
function Classify($e, $v, $cob) {
  $teve = ($v -and ([double]$v.qtdMediaSemanal -gt 0 -or [double]$v.vendaMediaSemanal -gt 0))
  $dias = $cob.dias
  if ($e.valor -le 0 -and $teve) { return @{ status = "ruptura"; motivo = "Estoque zerado em $posicao com historico de venda"; tom = "danger" } }
  if ($e.valor -le 0) { return @{ status = "zerado_sem_giro"; motivo = "Zerado sem venda nas 4 semanas"; tom = "neutral" } }
  if ($null -ne $dias) {
    if ($dias -gt 0 -and $dias -lt 7 -and $teve) { return @{ status = "critico_baixo"; motivo = ("Cobertura {0:N1} dias" -f $dias); tom = "danger" } }
    if ($dias -ge 7 -and $dias -lt 14 -and $teve) { return @{ status = "atencao_baixo"; motivo = ("Cobertura {0:N1} dias" -f $dias); tom = "warn" } }
    if ($dias -ge 60 -and $e.valor -ge 50000) { return @{ status = "excesso"; motivo = ("Cobertura {0:N1} dias" -f $dias); tom = "warn" } }
  }
  return @{ status = "saudavel"; motivo = "Dentro da faixa operacional"; tom = "ok" }
}

$rowsOut = @()
foreach ($e in $estoques) {
  $v = Resolve-VendaG $e
  $cob = Get-Cob $e.valor $v $e.diasCobertura
  $cls = Classify $e $v $cob
  $rowsOut += [pscustomobject]@{
    nome = if ($v) { $v.nome } else { $e.nome }
    key = $e.key; secao = $e.secao; dept = $e.dept
    skus = $e.skus; valorEstoque = $e.valor; qtdEstoque = $e.qtd
    diasCobertura = $cob.dias; semanasCobertura = $cob.semanas
    qtdMediaSemanal4s = if ($v) { $v.qtdMediaSemanal } else { $null }
    vendaMediaSemanal4s = if ($v) { $v.vendaMediaSemanal } else { $null }
    cmvMediaSemanal4s = if ($v) { $v.cmvMediaSemanal } else { $null }
    qtdTotal4s = if ($v) { $v.qtdTotal4s } else { $null }
    qtdsPorSemana = if ($v) { @($v.qtdsPorSemana) } else { @() }
    status = $cls.status; motivo = $cls.motivo; tom = $cls.tom
  }
}
function PickS([string]$st) { return @($rowsOut | Where-Object { $_.status -eq $st } | Sort-Object { if ($st -eq "excesso") { -$_.valorEstoque } else { $_.nome } }) }
$ruptura = PickS "ruptura"; $critico = PickS "critico_baixo"; $atencao = PickS "atencao_baixo"; $excesso = PickS "excesso"; $saudavel = PickS "saudavel"

$lojaIds = @($lojaMeta.Keys | Sort-Object { [int]($_ -replace "\D", "0") })
$lojasOut = @($lojaIds | ForEach-Object { $lojaMeta[$_] })
$linhasOut = @()
foreach ($row in $mx.Values) {
  $vals = @(); $qtds = @(); $tot = 0.0; $cd = 0.0
  foreach ($id in $lojaIds) {
    $v = 0.0; $q = 0.0
    if ($row.by.ContainsKey($id)) { $v = [double]$row.by[$id].valor; $q = [double]$row.by[$id].qtd }
    $vals += [math]::Round($v, 0); $qtds += [math]::Round($q, 0); $tot += $v
    if ($id -eq "70") { $cd = $v }
  }
  if ($tot -le 0) { continue }
  $linhasOut += [ordered]@{
    subgrupo = [string]$row.subgrupo; grupo = [string]$row.grupo; secao = [string]$row.secao
    valores = $vals; qtds = $qtds; total = [math]::Round($tot, 0); cd = [math]::Round($cd, 0)
  }
}
$totEmpresa = [math]::Round((($storeVal.Values | Measure-Object -Sum).Sum), 0)
$totCd = if ($storeVal.ContainsKey("70")) { [math]::Round([double]$storeVal["70"], 0) } else { 0 }
$distribuicao = [ordered]@{
  lojas = $lojasOut
  linhas = @($linhasOut | Sort-Object { -$_.cd } | Select-Object -First 400)
  totais = [ordered]@{
    empresa = $totEmpresa; cd = $totCd; lojas = $totEmpresa - $totCd
    loja17 = $(if ($storeVal.ContainsKey("17")) { [math]::Round([double]$storeVal["17"], 0) } else { 0 })
    subgrupos = $linhasOut.Count; mover = 0
  }
}

$fornRows = @()
foreach ($k in $forn.Keys) {
  $o = $forn[$k]
  $diasL = if ($o.mediaL -gt 0) { [math]::Round($o.l / $o.mediaL, 1) } else { $null }
  $diasA = if (($o.mediaL + $o.mediaCd) -gt 0) { [math]::Round(($o.l + $o.cd) / ($o.mediaL + $o.mediaCd), 1) } else { $diasL }
  $st = if ($o.l -le 0) { "ruptura" } elseif ($diasL -ne $null -and $diasL -gt 27) { "acima" } else { "ok" }
  $fornRows += [pscustomobject]@{
    nome = $o.nome; venda = [math]::Round($o.mediaL, 2); part = 0
    estoqueLojas = [math]::Round($o.l, 2); estoqueAll = [math]::Round($o.l + $o.cd, 2)
    estoqueCd = [math]::Round($o.cd, 2)
    diasLojas = $diasL; diasAll = $diasA; meta = 27; status = $st
  }
}

$estPayload = [ordered]@{
  meta = [ordered]@{
    titulo = "Radar de Estoque Critico"
    posicaoEm = $posicao
    nivel = "Grupo (Categoria 3)"
    fonteEstoque = $kit.est.Name
    baseVenda = "Cobertura = estoque R$ / CMV medio semanal 2026 (4 semanas do dashboard). Estoque so das lojas presentes no arquivo."
    periodosVenda = $periodos
    lojasNoArquivo = @($lojasOut | ForEach-Object { $_.nome })
    regras = [ordered]@{
      ruptura = "Estoque valor = 0 em $posicao E houve venda (4 semanas)"
      critico_baixo = "Cobertura abaixo de 7 dias"
      atencao_baixo = "Cobertura entre 7 e 14 dias"
      excesso = "Cobertura acima de 60 dias e valor >= 50000"
    }
    geradoEm = (Get-Date -Format "yyyy-MM-dd HH:mm")
  }
  totais = [ordered]@{
    grupos = $rowsOut.Count
    valorEstoque = [math]::Round((($rowsOut | Measure-Object valorEstoque -Sum).Sum), 0)
    ruptura = $ruptura.Count; criticoBaixo = $critico.Count; atencaoBaixo = $atencao.Count
    excesso = $excesso.Count; saudavel = $saudavel.Count
    valorEmExcesso = [math]::Round((($excesso | Measure-Object valorEstoque -Sum).Sum), 0)
    valorEmCriticoBaixo = [math]::Round((($critico | Measure-Object valorEstoque -Sum).Sum), 0)
  }
  ruptura = @($ruptura | Select-Object -First 40)
  criticoBaixo = @($critico | Select-Object -First 40)
  atencaoBaixo = @($atencao | Select-Object -First 30)
  excesso = @($excesso | Select-Object -First 40)
  topExcesso = @($excesso | Select-Object -First 12)
  topRuptura = @($ruptura | Select-Object -First 12)
  topCritico = @($critico | Select-Object -First 12)
  porStatus = @(
    [ordered]@{ status = "ruptura"; label = "Ruptura"; count = $ruptura.Count; tom = "danger" }
    [ordered]@{ status = "critico_baixo"; label = "Critico baixo"; count = $critico.Count; tom = "danger" }
    [ordered]@{ status = "atencao_baixo"; label = "Atencao baixo"; count = $atencao.Count; tom = "warn" }
    [ordered]@{ status = "excesso"; label = "Excesso"; count = $excesso.Count; tom = "warn" }
    [ordered]@{ status = "saudavel"; label = "Saudavel"; count = $saudavel.Count; tom = "ok" }
  )
  grupos = @($rowsOut | ForEach-Object {
    [ordered]@{ nome = $_.nome; secao = $_.secao; dept = $_.dept; valorEstoque = $_.valorEstoque; qtdEstoque = $_.qtdEstoque; diasCobertura = $_.diasCobertura; status = $_.status }
  })
  distribuicao = $distribuicao
  fornecedores = [ordered]@{
    meta = [ordered]@{ fonte = $kit.est.Name; demanda = "Media de venda custo do proprio arquivo de estoque (Venda GBO nao tem fornecedor)"; metaDias = 27 }
    rowsTodas = @($fornRows | Sort-Object estoqueLojas -Descending)
    rowsMesma = @($fornRows | Sort-Object estoqueLojas -Descending)
    totais = [ordered]@{
      todas = [ordered]@{
        venda = [math]::Round((($fornRows | Measure-Object venda -Sum).Sum), 2)
        estoqueLojas = [math]::Round((($fornRows | Measure-Object estoqueLojas -Sum).Sum), 2)
        estoqueCd = [math]::Round((($fornRows | Measure-Object estoqueCd -Sum).Sum), 2)
        diasLojas = $null
      }
    }
  }
}
$estPayload.fornecedores.totais.mesma = $estPayload.fornecedores.totais.todas
$totF = $estPayload.fornecedores.totais.todas
if ($totF.venda -gt 0) { $totF.diasLojas = [math]::Round($totF.estoqueLojas / ($totF.venda / 7), 1) }

$jsPath = Join-Path $Root "estoque-data.js"
$jsonPath = Join-Path $Root "entradas\estoque\estoque-critico.json"
New-Item -ItemType Directory -Path (Split-Path $jsonPath) -Force | Out-Null
$jsonPretty = $estPayload | ConvertTo-Json -Depth 8
$jsonCompact = $estPayload | ConvertTo-Json -Depth 8 -Compress
[IO.File]::WriteAllText($jsonPath, $jsonPretty, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($jsPath, ("window.ESTOQUE_DATA = {0};" -f $jsonCompact), [Text.UTF8Encoding]::new($false))
Write-Host "Radar OK. Ruptura=$($ruptura.Count) Critico=$($critico.Count) Excesso=$($excesso.Count) Grupos=$($rowsOut.Count)"
Write-Host "Pronto. Proxima semana: substitua os 4 arquivos em entradas\semana-atual e rode .\atualizar-semana.ps1 no PowerShell."
