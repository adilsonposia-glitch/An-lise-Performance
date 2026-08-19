<#
.SYNOPSIS
  Gera / atualiza data.json + data.js a partir dos Excel da semana comercial.

.DESCRIPTION
  Mantém até 4 semanas no bundle (1a..4ª Semana).
  - Dados atuais do projeto = 1ª Semana (já migrados).
  - Novas semanas: coloque os .xlsx em entradas\semana-nova e rode este script.
  - Semanas sem dados aparecem na UI como "sem dados".
  - Ao ultrapassar 4 semanas, a mais antiga sai do bundle (arquivo permanece em historico\).

.PARAMETER InputDir
  Pasta com os Excel da semana a ingerir. Default: entradas\semana-nova

.PARAMETER Periodo2025
  Texto do período base, ex: "18/07/2025 a 24/07/2025"

.PARAMETER Periodo2026
  Texto do período atual, ex: "17/07/2026 a 23/07/2026"

.PARAMETER AnoBase
  Ano base (default 2025)

.PARAMETER AnoAtual
  Ano atual (default 2026)

.PARAMETER ReplaceWeek
  Se informado (1..4), substitui essa semana em vez de preencher o próximo slot vazio.

.PARAMETER InitOnly
  Apenas garante a estrutura de 4 semanas a partir do data.json atual (sem ler Excel).

.EXAMPLE
  .\build-data.ps1 -Periodo2025 "25/07/2025 a 31/07/2025" -Periodo2026 "24/07/2026 a 30/07/2026"
#>

[CmdletBinding()]
param(
  [string]$InputDir = "",
  [string]$Periodo2025 = "",
  [string]$Periodo2026 = "",
  [int]$AnoBase = 2025,
  [int]$AnoAtual = 2026,
  [ValidateRange(1, 4)]
  [int]$ReplaceWeek = 0,
  [switch]$InitOnly
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }
if (-not $InputDir) { $InputDir = Join-Path $Root "entradas\semana-nova" }

$WeekLabels = @("1ª Semana", "2ª Semana", "3ª Semana", "4ª Semana")
$HistoricoDir = Join-Path $Root "historico"
$DataJsonPath = Join-Path $Root "data.json"
$DataJsPath = Join-Path $Root "data.js"
$TmpRoot = Join-Path $env:TEMP ("xlsx_perf_" + [guid]::NewGuid().ToString("N"))

function Get-WeekLabel([int]$ordem) {
  if ($ordem -ge 1 -and $ordem -le 4) { return $WeekLabels[$ordem - 1] }
  return "${ordem}ª Semana"
}

function New-EmptyWeek([int]$ordem) {
  return [ordered]@{
    key = "semana-$ordem"
    label = (Get-WeekLabel $ordem)
    ordem = $ordem
    hasData = $false
    meta = $null
    storeMeta = $null
    phases = $null
  }
}

function Normalize-Name([string]$name) {
  $n = $name.Trim().ToUpperInvariant()
  $n = $n.Normalize([Text.NormalizationForm]::FormD)
  $n = [regex]::Replace($n, "\p{Mn}", "")
  return $n
}

function Test-Excluded([string]$name) {
  $n = Normalize-Name $name
  $base = ($n -replace "\s*\(\d+\)\s*$", "").Trim()
  $patterns = @(
    "^NAO REVENDA\b", "^INATIVOS\b", "^SERVICOS\b", "^SERVICO\b",
    "^RECICLAVEIS\b", "^RECICLAVEL\b", "^FRETE\b"
  )
  foreach ($p in $patterns) {
    if ($base -match $p -or $n -match $p) { return $true }
  }
  return $false
}

function Find-ExtractedDir([string]$pattern) {
  $d = Get-ChildItem $TmpRoot -Directory | Where-Object { $_.Name -like $pattern } | Select-Object -First 1
  if (-not $d) { throw "Pasta/arquivo nao encontrado no extrato: $pattern" }
  return $d.Name
}

function Find-OptionalDir([string]$pattern) {
  $d = Get-ChildItem $TmpRoot -Directory | Where-Object { $_.Name -like $pattern } | Select-Object -First 1
  if ($d) { return $d.Name }
  return $null
}

function Get-SafeExtractName([string]$baseName) {
  # Remove espacos laterais e chars invalidos; Windows nao cria pasta com espaco no fim
  $n = $baseName.Trim() -replace '[<>:"/\\|?*]', '_'
  $n = $n -replace '\s+', ' '
  if ([string]::IsNullOrWhiteSpace($n)) { $n = "arquivo" }
  return $n
}

function Expand-Excels([string]$dir) {
  if (-not (Test-Path $dir)) {
    throw "Pasta de entrada nao encontrada: $dir`nColoque os .xlsx em entradas\semana-nova"
  }
  $files = @(Get-ChildItem -Path $dir -Filter "*.xlsx" -File)
  if ($files.Count -eq 0) {
    throw "Nenhum .xlsx em: $dir"
  }
  New-Item -ItemType Directory -Path $TmpRoot -Force | Out-Null
  $used = @{}
  foreach ($f in $files) {
    $safe = Get-SafeExtractName $f.BaseName
    if ($used.ContainsKey($safe)) {
      $i = 2
      while ($used.ContainsKey("$safe ($i)")) { $i++ }
      $safe = "$safe ($i)"
    }
    $used[$safe] = $true
    $dest = Join-Path $TmpRoot $safe
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $zip = Join-Path $dest "file.zip"
    Copy-Item $f.FullName $zip -Force
    Expand-Archive -Path $zip -DestinationPath (Join-Path $dest "content") -Force
    Write-Host "  extraiu: $($f.Name) -> $safe"
  }
}

function Parse-Sheet([string]$folderName) {
  $sheetPath = Join-Path $TmpRoot "$folderName\content\xl\worksheets\sheet1.xml"
  if (-not (Test-Path $sheetPath)) { throw "sheet1.xml ausente em $folderName" }
  [xml]$xml = Get-Content $sheetPath -Encoding UTF8
  $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
  $rows = $xml.SelectNodes("//x:sheetData/x:row", $ns)
  $data = @()
  $isHeader = $true
  foreach ($row in $rows) {
    $cells = $row.SelectNodes("x:c", $ns)
    $vals = @()
    foreach ($c in $cells) {
      $t = $c.GetAttribute("t")
      if ($t -eq "inlineStr") {
        $node = $c.SelectSingleNode("x:is/x:t", $ns)
        if ($null -eq $node) { $vals += "" } else { $vals += $node.InnerText }
      } else {
        $v = $c.SelectSingleNode("x:v", $ns)
        if ($null -eq $v -or [string]::IsNullOrWhiteSpace($v.InnerText)) { $vals += $null }
        else { $vals += [double]$v.InnerText }
      }
    }
    if ($isHeader) { $isHeader = $false; continue }
    if ($vals.Count -eq 0) { continue }
    $name = ([string]$vals[0]).Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    if ($name -match "^(TOTAL|Total|SOMA|Soma|Filtros|Filtro|Parametro|Parâmetro|Data |Ano |Nome do|nomereduzido)") { continue }
    if ($name.Length -gt 80) { continue }
    if (Test-Excluded $name) { continue }
    $venda = if ($vals.Count -gt 1 -and $null -ne $vals[1]) { [double]$vals[1] } else { 0 }
    if ($venda -eq 0 -and ($vals.Count -le 14 -or $null -eq $vals[14] -or [double]$vals[14] -eq 0)) { continue }
    $lucro = if ($vals.Count -gt 14 -and $null -ne $vals[14]) { [double]$vals[14] } else { 0 }
    $qtd = if ($vals.Count -gt 20 -and $null -ne $vals[20]) { [double]$vals[20] } else { 0 }
    $clientes = if ($vals.Count -gt 28 -and $null -ne $vals[28]) { [double]$vals[28] } else { $null }
    $ticket = if ($vals.Count -gt 31 -and $null -ne $vals[31]) { [double]$vals[31] } else { $null }
    $margem = if ($venda -ne 0) { $lucro / $venda } else { 0 }
    $data += [pscustomobject]@{
      nome = $name
      venda = [math]::Round($venda, 2)
      quantidade = [math]::Round($qtd, 2)
      lucro = [math]::Round($lucro, 2)
      margem = [math]::Round($margem, 6)
      clientes = if ($null -eq $clientes) { $null } else { [math]::Round($clientes, 0) }
      ticket = if ($null -eq $ticket) { $null } else { [math]::Round($ticket, 2) }
    }
  }
  return $data
}

function Compare-Years($y25, $y26) {
  $map25 = @{}
  foreach ($r in $y25) { $map25[$r.nome] = $r }
  $map26 = @{}
  foreach ($r in $y26) { $map26[$r.nome] = $r }
  $names = @($map25.Keys + $map26.Keys | Select-Object -Unique | Sort-Object)
  $rows = @()
  foreach ($n in $names) {
    $a = $map25[$n]; $b = $map26[$n]
    $v25 = if ($a) { $a.venda } else { 0 }; $v26 = if ($b) { $b.venda } else { 0 }
    $q25 = if ($a) { $a.quantidade } else { 0 }; $q26 = if ($b) { $b.quantidade } else { 0 }
    $l25 = if ($a) { $a.lucro } else { 0 }; $l26 = if ($b) { $b.lucro } else { 0 }
    $m25 = if ($a) { $a.margem } else { 0 }; $m26 = if ($b) { $b.margem } else { 0 }
    $c25 = if ($a) { $a.clientes } else { $null }; $c26 = if ($b) { $b.clientes } else { $null }
    $t25 = if ($a) { $a.ticket } else { $null }; $t26 = if ($b) { $b.ticket } else { $null }
    $varVendaPct = if ($v25 -ne 0) { ($v26 - $v25) / $v25 } elseif ($v26 -ne 0) { 1 } else { 0 }
    $varQtdPct = if ($q25 -ne 0) { ($q26 - $q25) / $q25 } elseif ($q26 -ne 0) { 1 } else { 0 }
    $varLucroPct = if ($l25 -ne 0) { ($l26 - $l25) / $l25 } elseif ($l26 -ne 0) { 1 } else { 0 }
    $varClientesPct = $null
    if ($null -ne $c25 -and $null -ne $c26 -and $c25 -ne 0) { $varClientesPct = ($c26 - $c25) / $c25 }
    elseif ($null -ne $c25 -and $null -ne $c26) { $varClientesPct = 0 }
    $deltaLucro = $l26 - $l25
    $rows += [pscustomobject]@{
      nome = $n
      venda2025 = $v25; venda2026 = $v26; deltaVenda = [math]::Round($v26 - $v25, 2)
      varVendaPct = [math]::Round($varVendaPct, 6)
      qtd2025 = $q25; qtd2026 = $q26
      deltaQtd = [math]::Round($q26 - $q25, 2); varQtdPct = [math]::Round($varQtdPct, 6)
      lucro2025 = $l25; lucro2026 = $l26; deltaLucro = [math]::Round($deltaLucro, 2)
      varLucroPct = [math]::Round($varLucroPct, 6)
      margem2025 = [math]::Round($m25 * 100, 2); margem2026 = [math]::Round($m26 * 100, 2)
      varMargemPp = [math]::Round(($m26 - $m25) * 100, 2)
      clientes2025 = $c25; clientes2026 = $c26
      varClientesPct = if ($null -eq $varClientesPct) { $null } else { [math]::Round($varClientesPct, 6) }
      ticket2025 = $t25; ticket2026 = $t26
      progresso = if ($deltaLucro -ge 0) { "progressao" } else { "regressao" }
      nova = [bool](($v25 -le 0) -and ($v26 -gt 0))
    }
  }
  return $rows
}

function Build-Base($cmp, $hasClients) {
  $totV25 = ($cmp | Measure-Object venda2025 -Sum).Sum
  $totV26 = ($cmp | Measure-Object venda2026 -Sum).Sum
  $totQ25 = ($cmp | Measure-Object qtd2025 -Sum).Sum
  $totQ26 = ($cmp | Measure-Object qtd2026 -Sum).Sum
  $totL25 = ($cmp | Measure-Object lucro2025 -Sum).Sum
  $totL26 = ($cmp | Measure-Object lucro2026 -Sum).Sum
  $m25 = if ($totV25) { $totL25 / $totV25 * 100 } else { 0 }
  $m26 = if ($totV26) { $totL26 / $totV26 * 100 } else { 0 }
  $melhores = @($cmp | Sort-Object deltaLucro -Descending | Select-Object -First 3)
  $topNames = @($melhores | ForEach-Object { $_.nome })
  $neg = @($cmp | Where-Object { $_.deltaLucro -lt 0 } | Sort-Object deltaLucro)
  if ($neg.Count -gt 0) { $agressores = @($neg | Select-Object -First 5) }
  else { $agressores = @($cmp | Where-Object { $topNames -notcontains $_.nome } | Sort-Object deltaLucro | Select-Object -First 5) }
  $totC25 = $null; $totC26 = $null; $varC = $null
  if ($hasClients) {
    $totC25 = ($cmp | Where-Object { $null -ne $_.clientes2025 } | Measure-Object clientes2025 -Sum).Sum
    $totC26 = ($cmp | Where-Object { $null -ne $_.clientes2026 } | Measure-Object clientes2026 -Sum).Sum
    if ($totC25) { $varC = [math]::Round(($totC26 - $totC25) / $totC25, 6) }
  }
  return [ordered]@{
    totals = [ordered]@{
      venda2025 = [math]::Round($totV25, 2); venda2026 = [math]::Round($totV26, 2)
      varVendaPct = if ($totV25) { [math]::Round(($totV26 - $totV25) / $totV25, 6) } else { 0 }
      qtd2025 = [math]::Round($totQ25, 2); qtd2026 = [math]::Round($totQ26, 2)
      varQtdPct = if ($totQ25) { [math]::Round(($totQ26 - $totQ25) / $totQ25, 6) } else { 0 }
      lucro2025 = [math]::Round($totL25, 2); lucro2026 = [math]::Round($totL26, 2)
      varLucroPct = if ($totL25) { [math]::Round(($totL26 - $totL25) / $totL25, 6) } else { 0 }
      margem2025 = [math]::Round($m25, 2); margem2026 = [math]::Round($m26, 2)
      varMargemPp = [math]::Round($m26 - $m25, 2)
      clientes2025 = $totC25; clientes2026 = $totC26; varClientesPct = $varC
    }
    agressores = @($agressores)
    melhores = @($melhores)
    rows = @($cmp | Sort-Object { $_.deltaLucro })
  }
}

function Build-PhaseFromFiles($key, $label, $file25, $file26, $hasClients) {
  $cmp = @(Compare-Years (Resolve-SheetRows $file25) (Resolve-SheetRows $file26))
  $base = Build-Base $cmp $hasClients
  return [ordered]@{
    key = $key; label = $label; hasClients = $hasClients
    totals = $base.totals; agressores = $base.agressores; melhores = $base.melhores; rows = $base.rows
  }
}

function Build-DualPhase($key, $label, $todas25, $todas26, $mesma25, $mesma26, $hasClients) {
  $todas = Build-PhaseFromFiles $key $label $todas25 $todas26 $hasClients
  $mesma = Build-PhaseFromFiles $key $label $mesma25 $mesma26 $hasClients
  return [ordered]@{
    key = $key; label = $label; hasClients = $hasClients
    sources = [ordered]@{
      todas = [ordered]@{ y2025 = $todas25; y2026 = $todas26 }
      mesma = [ordered]@{ y2025 = $mesma25; y2026 = $mesma26 }
    }
    bases = [ordered]@{
      todas = [ordered]@{ totals = $todas.totals; agressores = $todas.agressores; melhores = $todas.melhores; rows = $todas.rows }
      mesma = [ordered]@{ totals = $mesma.totals; agressores = $mesma.agressores; melhores = $mesma.melhores; rows = $mesma.rows }
    }
  }
}

function First-ExistingDir([string[]]$patterns) {
  foreach ($p in $patterns) {
    $hit = Find-OptionalDir $p
    if ($hit) { return $hit }
  }
  return $null
}

function Test-IsLoja17([string]$name) {
  $n = Normalize-Name $name
  return [bool]($n -match 'LOJA\s*17\b' -or $n -match '\bL17\b')
}

function Get-ExtractYear([string]$name) {
  $n = Normalize-Name $name
  # Compacta espacos em periodos: "07A 13AGO2026" -> "07A13AGO2026"
  $compact = ($n -replace '\s+', '')
  # Prefixo de periodo: 24A30JULHO26 / 25A31JULHO25 / 07A13AGOSTO26 / AGO2026
  if ($n -match '(?:^|\b)(?:\d{1,2}A\d{1,2}[A-Z]+)?2026(?:\b|$)' -or $n -match '(?:JULHO|AGOSTO|AGO)\s*26\b' -or $n -match '(?:^|\b)\d{1,2}A\d{1,2}[A-Z]+26\b' -or $compact -match '(?:JULHO|AGOSTO|AGO)2026' -or $compact -match '\d{1,2}A\d{1,2}[A-Z]+26') { return 2026 }
  if ($n -match '(?:^|\b)(?:\d{1,2}A\d{1,2}[A-Z]+)?2025(?:\b|$)' -or $n -match '(?:JULHO|AGOSTO|AGO)\s*25\b' -or $n -match '(?:^|\b)\d{1,2}A\d{1,2}[A-Z]+25\b' -or $compact -match '(?:JULHO|AGOSTO|AGO)2025' -or $compact -match '\d{1,2}A\d{1,2}[A-Z]+25') { return 2025 }
  if ($n -match '(?:^|\b)2026\b' -or $compact -match '2026') { return 2026 }
  if ($n -match '(?:^|\b)2025\b' -or $compact -match '2025') { return 2025 }
  return $null
}

function Get-ExtractKind([string]$name) {
  $n = Normalize-Name $name
  # Categorias mercadologicas primeiro (nomes tambem podem terminar com "Lojas")
  if ($n -match 'DEPARTAMENTO') { return "departamento" }
  if ($n -match 'SECAO') { return "secao" }
  if ($n -match 'GRUPO') { return "grupo" }
  # Fase Lojas: "Lojas.xlsx", "Lojas Todas as Lojas", "Lojas Mesmas Lojas", legado 2025Lojas
  if ($n -match '(?:^|\d\s|\b)LOJAS?\b' -or $n -match 'LLOJAS' -or $n -match 'LOJKAS') { return "lojas" }
  return $null
}

function Get-ExtractBase([string]$name) {
  $n = Normalize-Name $name
  if ($n -match 'MESMA') { return "mesma" }
  if ($n -match 'TODAS') { return "todas" }
  return $null
}

function Find-Loja17ByKind([string]$kind) {
  foreach ($d in @(Get-ChildItem $TmpRoot -Directory)) {
    if (-not (Test-IsLoja17 $d.Name)) { continue }
    if ((Get-ExtractYear $d.Name) -ne 2026) { continue }
    if ((Get-ExtractKind $d.Name) -eq $kind) { return $d.Name }
  }
  return $null
}

function Find-ByRole([int]$year, [string]$kind, [string]$base) {
  $dirs = @(Get-ChildItem $TmpRoot -Directory)
  foreach ($d in $dirs) {
    # Loja 17 fica separada — nunca vira "todas"/"mesma" da rede
    if (Test-IsLoja17 $d.Name) { continue }
    $y = Get-ExtractYear $d.Name
    $k = Get-ExtractKind $d.Name
    $b = Get-ExtractBase $d.Name
    if ($y -ne $year) { continue }
    if ($k -ne $kind) { continue }
    if ($null -ne $base) {
      if ($b -eq $base) { return $d.Name }
      # Arquivo unico do ano (ex: "25a31Julho25 Departamentos") conta como "todas"
      if ($base -eq "todas" -and $null -eq $b) { return $d.Name }
    } else {
      return $d.Name
    }
  }
  return $null
}

function Merge-MetricRows($rowsA, $rowsB) {
  $map = @{}
  foreach ($r in (@($rowsA) + @($rowsB))) {
    if (-not $r) { continue }
    $key = [string]$r.nome
    if ($map.ContainsKey($key)) {
      $prev = $map[$key]
      $venda = [double]$prev.venda + [double]$r.venda
      $qtd = [double]$prev.quantidade + [double]$r.quantidade
      $lucro = [double]$prev.lucro + [double]$r.lucro
      $cPrev = $prev.clientes; $cNew = $r.clientes
      $clientes = $null
      if ($null -ne $cPrev -or $null -ne $cNew) {
        $cSum = 0.0
        if ($null -ne $cPrev) { $cSum += [double]$cPrev }
        if ($null -ne $cNew) { $cSum += [double]$cNew }
        $clientes = [math]::Round($cSum, 0)
      }
      $ticket = $null
      if ($null -ne $clientes -and $clientes -ne 0) { $ticket = [math]::Round($venda / $clientes, 2) }
      $margem = if ($venda -ne 0) { $lucro / $venda } else { 0 }
      $map[$key] = [pscustomobject]@{
        nome = $key
        venda = [math]::Round($venda, 2)
        quantidade = [math]::Round($qtd, 2)
        lucro = [math]::Round($lucro, 2)
        margem = [math]::Round($margem, 6)
        clientes = $clientes
        ticket = $ticket
      }
    } else {
      $map[$key] = $r
    }
  }
  return @($map.Values | Sort-Object nome)
}

function New-MergeToken([string]$mesmaFolder, [string]$loja17Folder) {
  return ("__MERGE__|{0}|{1}" -f $mesmaFolder, $loja17Folder)
}

function Test-IsMergeToken([string]$name) {
  return [bool]($name -like "__MERGE__|*")
}

function Resolve-SheetRows([string]$folderOrMerge) {
  if (Test-IsMergeToken $folderOrMerge) {
    $parts = $folderOrMerge.Split("|")
    $mesma = Parse-Sheet $parts[1]
    $loja17 = Parse-Sheet $parts[2]
    Write-Host ("  merge Todas 2026: {0} + {1}" -f $parts[1], $parts[2])
    return (Merge-MetricRows $mesma $loja17)
  }
  return (Parse-Sheet $folderOrMerge)
}

function New-Loja17StoreRow([string]$departamentoFolder) {
  $rows = @(Parse-Sheet $departamentoFolder)
  $venda = ($rows | Measure-Object venda -Sum).Sum
  $qtd = ($rows | Measure-Object quantidade -Sum).Sum
  $lucro = ($rows | Measure-Object lucro -Sum).Sum
  $cliParts = @($rows | Where-Object { $null -ne $_.clientes })
  $clientes = $null
  if ($cliParts.Count -gt 0) { $clientes = [math]::Round(($cliParts | Measure-Object clientes -Sum).Sum, 0) }
  $ticket = if ($null -ne $clientes -and $clientes -ne 0) { [math]::Round($venda / $clientes, 2) } else { $null }
  $margem = if ($venda -ne 0) { $lucro / $venda } else { 0 }
  return [pscustomobject]@{
    nome = "17 - P.LUCAS"
    venda = [math]::Round($venda, 2)
    quantidade = [math]::Round($qtd, 2)
    lucro = [math]::Round($lucro, 2)
    margem = [math]::Round($margem, 6)
    clientes = $clientes
    ticket = $ticket
  }
}

function Resolve-PhaseDirs([string]$kind, [string]$label) {
  $todas25 = Find-ByRole 2025 $kind "todas"
  $todas26 = Find-ByRole 2026 $kind "todas"
  $mesma25 = Find-ByRole 2025 $kind "mesma"
  $mesma26 = Find-ByRole 2026 $kind "mesma"

  # Fallbacks para nomes legados estritos
  if (-not $todas25 -or -not $todas26 -or -not $mesma25 -or -not $mesma26) {
    if ($kind -eq "departamento") {
      if (-not $todas25) { $todas25 = First-ExistingDir @("2025DepartamentosTodas*", "2025Departamentos") }
      if (-not $todas26) { $todas26 = First-ExistingDir @("2026DepartamentosTodas*", "2026Departamentos") }
      if (-not $mesma25) { $mesma25 = Find-OptionalDir "2025DepartamentoMesmas*" }
      if (-not $mesma26) { $mesma26 = Find-OptionalDir "2026DepartamentoMesmas*" }
    } elseif ($kind -eq "grupo") {
      if (-not $todas25) { $todas25 = First-ExistingDir @("2025GruposTodas*", "2025Grupos") }
      if (-not $todas26) { $todas26 = First-ExistingDir @("2026GruposTodas*", "2026Grupos") }
      if (-not $mesma25) { $mesma25 = Find-OptionalDir "2025GrupoMesmas*" }
      if (-not $mesma26) { $mesma26 = Find-OptionalDir "2026GrupoMesmas*" }
    } elseif ($kind -eq "secao") {
      if (-not $todas25) {
        $todas25 = (Get-ChildItem $TmpRoot -Directory | Where-Object { $_.Name -like "2025Se*" -and $_.Name -notlike "*Mesmas*" } | Select-Object -First 1).Name
      }
      if (-not $todas26) {
        $todas26 = (Get-ChildItem $TmpRoot -Directory | Where-Object { $_.Name -like "2026Se*" -and $_.Name -notlike "*Mesmas*" } | Select-Object -First 1).Name
      }
      if (-not $mesma25) {
        $mesma25 = (Get-ChildItem $TmpRoot -Directory | Where-Object { $_.Name -like "2025Se*Mesmas*" } | Select-Object -First 1).Name
      }
      if (-not $mesma26) {
        $mesma26 = (Get-ChildItem $TmpRoot -Directory | Where-Object { $_.Name -like "2026Se*Mesmas*" } | Select-Object -First 1).Name
      }
    }
  }

  if (-not $mesma26) {
    throw ("Excel {0} Mesmas Lojas 2026 nao encontrado." -f $label)
  }

  # Sem export Todas 2026: sintetiza MesmaBase + Loja 17
  if (-not $todas26) {
    $loja17 = Find-Loja17ByKind $kind
    if ($loja17) {
      $todas26 = New-MergeToken $mesma26 $loja17
      Write-Host ("  {0}: Todas 2026 sintetizado = MesmaBase + Loja17" -f $label)
    }
  }

  if (-not $todas25 -or -not $todas26) {
    throw ("Excel {0} (todas) incompleto. Achados: 2025={1} 2026={2}" -f $label, $todas25, $todas26)
  }
  if (-not $mesma25) {
    Write-Host ("  aviso: {0} Mesmas 2025 ausente — usando arquivo Todas/unico 2025." -f $label)
    $mesma25 = $todas25
  }
  Write-Host ("  {0}: todas25={1}" -f $label, $todas25)
  Write-Host ("  {0}: todas26={1}" -f $label, $todas26)
  Write-Host ("  {0}: mesma25={1}" -f $label, $mesma25)
  Write-Host ("  {0}: mesma26={1}" -f $label, $mesma26)
  return @{ todas25 = $todas25; todas26 = $todas26; mesma25 = $mesma25; mesma26 = $mesma26 }
}

function Resolve-LojasDirs {
  # Preferir "Todas as Lojas"; aceita arquivo unico do ano e nomes com periodo (24a31julho2026...)
  $l25 = Find-ByRole 2025 "lojas" "todas"
  if (-not $l25) { $l25 = Find-ByRole 2025 "lojas" $null }
  $l26 = Find-ByRole 2026 "lojas" "todas"
  if (-not $l26) { $l26 = Find-ByRole 2026 "lojas" $null }

  if (-not $l25) {
    $l25 = First-ExistingDir @("2025Todas as Lojas", "2025 Todas as Lojas", "2025Lojas")
  }
  if (-not $l26) {
    $l26 = First-ExistingDir @("2026 Todas as Lojas", "2026Todas as Lojas", "2026LLojas", "2026Lojas")
  }

  # Ultimo recurso: qualquer extrato classificado como lojas do ano
  if (-not $l25 -or -not $l26) {
    $cands25 = @(Get-ChildItem $TmpRoot -Directory | Where-Object {
      (Get-ExtractYear $_.Name) -eq 2025 -and (Get-ExtractKind $_.Name) -eq "lojas"
    } | Sort-Object { if ((Get-ExtractBase $_.Name) -eq "todas") { 0 } elseif ($null -eq (Get-ExtractBase $_.Name)) { 1 } else { 2 } })
    $cands26 = @(Get-ChildItem $TmpRoot -Directory | Where-Object {
      (Get-ExtractYear $_.Name) -eq 2026 -and (Get-ExtractKind $_.Name) -eq "lojas"
    } | Sort-Object { if ((Get-ExtractBase $_.Name) -eq "todas") { 0 } elseif ($null -eq (Get-ExtractBase $_.Name)) { 1 } else { 2 } })
    if (-not $l25 -and $cands25) { $l25 = $cands25[0].Name }
    if (-not $l26 -and $cands26) { $l26 = $cands26[0].Name }
  }
  if (-not $l25 -or -not $l26) { return $null }
  return @{ y25 = $l25; y26 = $l26 }
}

function New-EmptyLojasPhase {
  $emptyBase = [ordered]@{
    totals = [ordered]@{
      venda2025 = 0; venda2026 = 0; varVendaPct = 0
      qtd2025 = 0; qtd2026 = 0; varQtdPct = 0
      lucro2025 = 0; lucro2026 = 0; varLucroPct = 0
      margem2025 = 0; margem2026 = 0; varMargemPp = 0
      clientes2025 = 0; clientes2026 = 0; varClientesPct = 0
    }
    agressores = @()
    melhores = @()
    rows = @()
  }
  return [ordered]@{
    key = "lojas"; label = "Lojas"; hasClients = $true
    storeMeta = [ordered]@{
      allCount = 0; comparableCount = 0; novasCount = 0; novasNames = @()
    }
    bases = [ordered]@{ todas = $emptyBase; mesma = $emptyBase }
  }
}

function Build-LojasBases {
  $dirs = Resolve-LojasDirs
  if (-not $dirs) {
    Write-Host "  aviso: Excel de Lojas ausente — fase Lojas fica vazia (demais fases seguem)."
    return (New-EmptyLojasPhase)
  }
  Write-Host ("  Lojas: 2025={0}" -f $dirs.y25)
  Write-Host ("  Lojas: 2026={0}" -f $dirs.y26)
  $rows25 = @(Parse-Sheet $dirs.y25)
  $rows26 = @(Parse-Sheet $dirs.y26)

  # Se 2026 e so MesmaBase, acrescenta Loja 17 (totais do Excel Loja17 Departamento)
  $y26Base = Get-ExtractBase $dirs.y26
  $l17dep = Find-Loja17ByKind "departamento"
  $src26Label = $dirs.y26
  if ($l17dep -and ($y26Base -eq "mesma" -or $null -eq (Find-ByRole 2026 "lojas" "todas"))) {
    $jaTem17 = @($rows26 | Where-Object {
      $nn = Normalize-Name $_.nome
      $nn -match '(?:^|\b)17\b' -or $nn -match 'P\.?\s*LUCAS'
    }).Count -gt 0
    if (-not $jaTem17) {
      $synth = New-Loja17StoreRow $l17dep
      $rows26 += $synth
      $src26Label = ("{0} + Loja17({1})" -f $dirs.y26, $synth.nome)
      Write-Host ("  Lojas: Todas 2026 = MesmaBase + {0} (venda={1})" -f $synth.nome, $synth.venda)
    }
  }

  $withCli25 = @($rows25 | Where-Object { $null -ne $_.clientes }).Count
  $withCli26 = @($rows26 | Where-Object { $null -ne $_.clientes }).Count
  if ($withCli25 -eq 0 -or $withCli26 -eq 0) {
    Write-Host "  AVISO: coluna Quantidade de Clientes vazia no Excel de Lojas (2025=$withCli25 lojas, 2026=$withCli26 lojas)."
    Write-Host "         Reexporte sem filtro de Categoria 1 / Eixo Y Dinamico — so Agrupamento Lojas, como na 1a semana."
  }
  $all = @(Compare-Years $rows25 $rows26)
  $mesma = @($all | Where-Object { $_.venda2025 -gt 0 -and $_.venda2026 -gt 0 })
  $novas = @($all | Where-Object { $_.venda2025 -le 0 -and $_.venda2026 -gt 0 })
  return [ordered]@{
    key = "lojas"; label = "Lojas"; hasClients = $true
    sources = [ordered]@{
      todas = [ordered]@{ y2025 = $dirs.y25; y2026 = $src26Label }
      mesma = [ordered]@{ y2025 = $dirs.y25; y2026 = $dirs.y26 }
    }
    storeMeta = [ordered]@{
      allCount = $all.Count
      comparableCount = $mesma.Count
      novasCount = $novas.Count
      novasNames = @($novas | ForEach-Object { $_.nome })
    }
    bases = [ordered]@{
      todas = (Build-Base $all $true)
      mesma = (Build-Base $mesma $true)
    }
  }
}

function Resolve-DeptDirs { return (Resolve-PhaseDirs "departamento" "Departamentos") }
function Resolve-SecDirs { return (Resolve-PhaseDirs "secao" "Secao") }
function Resolve-GrupoDirs { return (Resolve-PhaseDirs "grupo" "Grupos") }

function Build-WeekPayload {
  param(
    [string]$Periodo2025,
    [string]$Periodo2026,
    [int]$AnoBase,
    [int]$AnoAtual
  )

  $dep = Resolve-DeptDirs
  $sec = Resolve-SecDirs
  $gru = Resolve-GrupoDirs

  $phases = @(
    (Build-DualPhase "departamentos" "Departamentos" $dep.todas25 $dep.todas26 $dep.mesma25 $dep.mesma26 $false),
    (Build-LojasBases),
    (Build-DualPhase "secao" "Mercadologico - Secao" $sec.todas25 $sec.todas26 $sec.mesma25 $sec.mesma26 $false),
    (Build-DualPhase "grupos" "Mercadologico - Grupos" $gru.todas25 $gru.todas26 $gru.mesma25 $gru.mesma26 $false)
  )

  $storeMeta = ($phases | Where-Object { $_.key -eq "lojas" }).storeMeta

  return [ordered]@{
    meta = [ordered]@{
      titulo = "Analise de Performance Comercial"
      periodoLabel = "Sexta a Quinta - Ano contra Ano"
      periodo2025 = $Periodo2025
      periodo2026 = $Periodo2026
      anoBase = $AnoBase
      anoAtual = $AnoAtual
      excluidos = @("NAO REVENDA", "INATIVOS", "SERVICOS", "RECICLAVEIS", "FRETE")
      geradoEm = (Get-Date -Format "yyyy-MM-dd HH:mm")
    }
    storeMeta = $storeMeta
    phases = $phases
  }
}

function Read-Bundle {
  if (-not (Test-Path $DataJsonPath)) {
    return [ordered]@{
      maxWeeks = 4
      selectedWeek = 1
      weeks = @(1..4 | ForEach-Object { New-EmptyWeek $_ })
    }
  }
  $raw = Get-Content $DataJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($raw.weeks) {
    $weeks = @()
    for ($i = 1; $i -le 4; $i++) {
      $found = $raw.weeks | Where-Object { [int]$_.ordem -eq $i } | Select-Object -First 1
      if (-not $found) { $found = $raw.weeks[$i - 1] }
      if ($found -and $found.hasData -and $found.phases) {
        $weeks += [ordered]@{
          key = if ($found.key) { $found.key } else { "semana-$i" }
          label = if ($found.label) { $found.label } else { Get-WeekLabel $i }
          ordem = $i
          hasData = $true
          meta = $found.meta
          storeMeta = $found.storeMeta
          phases = $found.phases
        }
      } else {
        $weeks += (New-EmptyWeek $i)
      }
    }
    return [ordered]@{
      maxWeeks = 4
      selectedWeek = if ($raw.selectedWeek) { [int]$raw.selectedWeek } else { 1 }
      weeks = $weeks
    }
  }
  if ($raw.phases) {
    return [ordered]@{
      maxWeeks = 4
      selectedWeek = 1
      weeks = @(
        [ordered]@{
          key = "semana-1"; label = (Get-WeekLabel 1); ordem = 1; hasData = $true
          meta = $raw.meta; storeMeta = $raw.storeMeta; phases = $raw.phases
        },
        (New-EmptyWeek 2), (New-EmptyWeek 3), (New-EmptyWeek 4)
      )
    }
  }
  throw "data.json em formato desconhecido"
}

function Save-WeekArchive($weekObj) {
  if (-not (Test-Path $HistoricoDir)) { New-Item -ItemType Directory -Path $HistoricoDir | Out-Null }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $name = "semana-$($weekObj.ordem)"
  if ($weekObj.meta -and $weekObj.meta.periodo2026) {
    $safe = ($weekObj.meta.periodo2026 -replace "[^\d]", "")
    if ($safe) { $name = "semana-$($weekObj.ordem)_$safe" }
  }
  $path = Join-Path $HistoricoDir "$name`_$stamp.json"
  $utf8 = New-Object System.Text.UTF8Encoding $false
  $json = ($weekObj | ConvertTo-Json -Depth 100)
  [System.IO.File]::WriteAllText($path, $json, $utf8)
  # tambem salva ponteiro estavel da ordem
  $stable = Join-Path $HistoricoDir ("semana-{0}.json" -f $weekObj.ordem)
  [System.IO.File]::WriteAllText($stable, $json, $utf8)
  Write-Host "  historico: $(Split-Path $path -Leaf)"
}

function Write-Bundle($bundle) {
  $utf8 = New-Object System.Text.UTF8Encoding $false
  $json = ($bundle | ConvertTo-Json -Depth 100)
  [System.IO.File]::WriteAllText($DataJsonPath, $json, $utf8)
  $js = "// Dados pre-processados (historico das 4 ultimas semanas)`r`nwindow.PERFORMANCE_DATA = " + $json + ";`r`n"
  [System.IO.File]::WriteAllText($DataJsPath, $js, $utf8)
}

function Add-WeekToBundle($bundle, $payload, [int]$replaceWeek) {
  $weekBody = [ordered]@{
    meta = $payload.meta
    storeMeta = $payload.storeMeta
    phases = $payload.phases
  }

  if ($replaceWeek -ge 1) {
    $slot = $replaceWeek
    $weekObj = [ordered]@{
      key = "semana-$slot"
      label = (Get-WeekLabel $slot)
      ordem = $slot
      hasData = $true
      meta = $weekBody.meta
      storeMeta = $weekBody.storeMeta
      phases = $weekBody.phases
    }
    $bundle.weeks[$slot - 1] = $weekObj
    Save-WeekArchive $weekObj
    $bundle.selectedWeek = $slot
    return $bundle
  }

  # Preenche proximo slot vazio
  $emptyIdx = -1
  for ($i = 0; $i -lt 4; $i++) {
    if (-not $bundle.weeks[$i].hasData) { $emptyIdx = $i; break }
  }

  if ($emptyIdx -ge 0) {
    $slot = $emptyIdx + 1
    $weekObj = [ordered]@{
      key = "semana-$slot"
      label = (Get-WeekLabel $slot)
      ordem = $slot
      hasData = $true
      meta = $weekBody.meta
      storeMeta = $weekBody.storeMeta
      phases = $weekBody.phases
    }
    $bundle.weeks[$emptyIdx] = $weekObj
    Save-WeekArchive $weekObj
    $bundle.selectedWeek = $slot
    return $bundle
  }

  # Rolling: descarta a mais antiga (1a), desloca 2->1, 3->2, 4->3, nova vira 4a
  Write-Host "Rolling: removendo $($bundle.weeks[0].label) do filtro (copia em historico\)."
  Save-WeekArchive $bundle.weeks[0]

  $shifted = @()
  for ($i = 1; $i -le 3; $i++) {
    $src = $bundle.weeks[$i]
    $shifted += [ordered]@{
      key = "semana-$i"
      label = (Get-WeekLabel $i)
      ordem = $i
      hasData = [bool]$src.hasData
      meta = $src.meta
      storeMeta = $src.storeMeta
      phases = $src.phases
    }
  }
  $newWeek = [ordered]@{
    key = "semana-4"
    label = (Get-WeekLabel 4)
    ordem = 4
    hasData = $true
    meta = $weekBody.meta
    storeMeta = $weekBody.storeMeta
    phases = $weekBody.phases
  }
  $shifted += $newWeek
  $bundle.weeks = $shifted
  Save-WeekArchive $newWeek
  $bundle.selectedWeek = 4
  return $bundle
}

# --- main ---
try {
  New-Item -ItemType Directory -Path (Join-Path $Root "entradas\semana-nova") -Force | Out-Null
  New-Item -ItemType Directory -Path $HistoricoDir -Force | Out-Null

  $bundle = Read-Bundle

  if ($InitOnly) {
    # Garante arquivo estavel da 1ª Semana no historico
    $w1 = $bundle.weeks | Where-Object { $_.ordem -eq 1 -and $_.hasData } | Select-Object -First 1
    if ($w1) { Save-WeekArchive $w1 }
    Write-Bundle $bundle
    Write-Host "InitOnly OK - bundle com 4 slots. Semanas com dados:"
    $bundle.weeks | ForEach-Object { Write-Host ("  {0}: hasData={1}" -f $_.label, $_.hasData) }
    return
  }

  if (-not $Periodo2025 -or -not $Periodo2026) {
    throw "Informe -Periodo2025 e -Periodo2026 (ex: '18/07/2025 a 24/07/2025')."
  }

  Write-Host "Lendo Excel de: $InputDir"
  Expand-Excels $InputDir

  Write-Host "Processando YoY..."
  $payload = Build-WeekPayload -Periodo2025 $Periodo2025 -Periodo2026 $Periodo2026 -AnoBase $AnoBase -AnoAtual $AnoAtual

  $bundle = Add-WeekToBundle $bundle $payload $ReplaceWeek
  Write-Bundle $bundle

  $dep = ($payload.phases | Where-Object { $_.key -eq "departamentos" }).bases.mesma.totals
  Write-Host ("OK - semana selecionada: {0}" -f (Get-WeekLabel $bundle.selectedWeek))
  Write-Host ("Mesma base Dep V26={0:N2}" -f $dep.venda2026)
  $bundle.weeks | ForEach-Object {
    $st = if ($_.hasData) { $_.meta.periodo2026 } else { "sem dados" }
    Write-Host ("  {0}: {1}" -f $_.label, $st)
  }
  Write-Host "Atualize o navegador (F5) em index.html"
}
finally {
  if (Test-Path $TmpRoot) { Remove-Item $TmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
