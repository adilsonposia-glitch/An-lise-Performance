<#
.SYNOPSIS
  Cruza EstoquesEm21Ago*.xlsx (Grupo) com venda média (qtd) das 4 semanas do data.json.
  Gera estoque-data.js + entradas/estoque/estoque-critico.json

.EXAMPLE
  .\build-estoque.ps1
#>
[CmdletBinding()]
param(
  [string]$EstoqueXlsx = "",
  [string]$EstoqueCsv = "",
  [string]$PosicaoData = "18/09/2026",
  [double]$DiasCriticoBaixo = 7,
  [double]$DiasAtencaoBaixo = 14,
  [double]$DiasExcesso = 60,
  [double]$ValorMinExcesso = 50000
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }
$DataJsonPath = Join-Path $Root "data.json"
$OutDir = Join-Path $Root "entradas\estoque"
$JsPath = Join-Path $Root "estoque-data.js"
$JsonPath = Join-Path $OutDir "estoque-critico.json"

function Normalize-Name([string]$name) {
  $n = $name.Trim().ToUpperInvariant()
  $n = $n.Normalize([Text.NormalizationForm]::FormD)
  $n = [regex]::Replace($n, "\p{Mn}", "")
  return $n
}

function Get-NameKey([string]$name) {
  $n = Normalize-Name $name
  # "BOVINO (2588)" -> chave por codigo se houver, senao nome base
  if ($n -match '\((\d+)\)\s*$') { return "ID:$($Matches[1])" }
  return ($n -replace '\s*\(\d+\)\s*$', '').Trim()
}

function Test-Excluded([string]$name) {
  $n = Normalize-Name $name
  $base = ($n -replace "\s*\(\d+\)\s*$", "").Trim()
  foreach ($p in @("^NAO REVENDA\b","^INATIVOS\b","^SERVICOS\b","^SERVICO\b","^RECICLAVEIS\b","^FRETE\b","^COMODATO\b","^MATERIA PRIMA\b")) {
    if ($base -match $p) { return $true }
  }
  return $false
}

$EstoqueDir = Join-Path $Root "entradas\estoque"
if (-not $EstoqueCsv) {
  $csvHit = Get-ChildItem -LiteralPath $EstoqueDir -File -Filter "PosicaoEstoques*.csv" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($csvHit) { $EstoqueCsv = $csvHit.FullName }
}
if (-not $EstoqueXlsx) {
  $hit = Get-ChildItem -LiteralPath (Join-Path $Root "entradas\semana-nova") -File -Filter "Estoques*.xlsx" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $hit) {
    $hit = Get-ChildItem -LiteralPath $EstoqueDir -File -Filter "Estoque*.xlsx" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 1
  }
  if ($hit) { $EstoqueXlsx = $hit.FullName }
}

function Get-BaseNameKey([string]$name) {
  $n = Normalize-Name $name
  return ($n -replace '\s*\(\d+\)\s*$', '').Trim()
}

function Test-SkipStore([string]$loja) {
  $n = Normalize-Name $loja
  if ($n -match 'CENTRAL|\b70\b') { return $true }
  if ($n -match 'P\.?\s*LUCAS|\b17\s*-') { return $true }
  if ($n -match '^02\s*-' -or $n -match '^04\s*-') { return $true }
  return $false
}

function Parse-BrNum($s) {
  if ($null -eq $s) { return 0 }
  $t = ([string]$s).Trim().Trim('"')
  if (-not $t) { return 0 }
  return [double]($t -replace '\.', '' -replace ',', '.')
}

$estoques = @()
$fonteNome = $null

if ($EstoqueCsv -and (Test-Path -LiteralPath $EstoqueCsv)) {
  $fonteNome = [IO.Path]::GetFileName($EstoqueCsv)
  Write-Host "Estoque CSV (12 lojas mesma base, sem 70/17): $EstoqueCsv"
  $raw = [IO.File]::ReadAllText($EstoqueCsv, [Text.Encoding]::GetEncoding(1252))
  $lines = $raw -split "`r?`n"
  $hdr = $lines[0] -split ';'
  # colunas por nome aproximado
  function Find-Col([string[]]$h, [string]$needle) {
    for ($i = 0; $i -lt $h.Count; $i++) {
      $n = Normalize-Name ($h[$i].Trim().Trim('"'))
      if ($n -match $needle) { return $i }
    }
    return -1
  }
  $iPath = Find-Col $hdr 'NIVEL\s*4'
  if ($iPath -lt 0) { $iPath = 1 }
  $iSku = Find-Col $hdr 'ITENS|SKU'
  $iQtd = Find-Col $hdr 'QUANTIDADE EM ESTOQUE'
  $iCusto = Find-Col $hdr 'CUSTO LIQUIDO'
  $iMedia = Find-Col $hdr 'MEDIA VDA'
  $iDias = Find-Col $hdr 'DIAS DE ESTOQUE'
  $iPend = Find-Col $hdr 'PEND. PED.COMPRA|PEND.*COMPRA'
  $acc = @{}
  for ($li = 1; $li -lt $lines.Count; $li++) {
    if ([string]::IsNullOrWhiteSpace($lines[$li])) { continue }
    $cols = $lines[$li] -split ';'
    if ($cols.Count -le $iPath) { continue }
    $path = $cols[$iPath].Trim().Trim('"')
    if ($path -notmatch ':') { continue }
    $loja, $rest = $path.Split(':', 2)
    $loja = $loja.Trim()
    if ($loja -match 'TOTAL') { continue }
    if (Test-SkipStore $loja) { continue }
    $parts = @($rest.Split('\') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($parts.Count -lt 3) { continue }
    $grupo = $parts[2]
    if ([string]::IsNullOrWhiteSpace($grupo)) { continue }
    $key = Get-NameKey $grupo
    $skus = if ($iSku -ge 0) { Parse-BrNum $cols[$iSku] } else { 0 }
    $valor = if ($iCusto -ge 0) { Parse-BrNum $cols[$iCusto] } else { 0 }
    $media = if ($iMedia -ge 0) { Parse-BrNum $cols[$iMedia] } else { 0 }
    $dias = if ($iDias -ge 0) { Parse-BrNum $cols[$iDias] } else { $null }
    $pend = if ($iPend -ge 0) { Parse-BrNum $cols[$iPend] } else { 0 }
    if ($valor -lt 0) { continue }
    if (-not $acc.ContainsKey($key)) {
      $acc[$key] = [pscustomobject]@{
        nome = $grupo.Trim()
        key = $key
        skus = 0.0
        valor = 0.0
        mediaCustoDia = 0.0
        diasCobertura = $null
        estoquePendente = 0.0
        excluido = [bool](Test-Excluded $grupo)
      }
    }
    $acc[$key].skus += $skus
    $acc[$key].valor += $valor
    $acc[$key].mediaCustoDia += $media
    $acc[$key].estoquePendente += $pend
    if ($null -ne $dias) { $acc[$key].diasCobertura = $dias }
  }
  $estoques = @($acc.Values | ForEach-Object {
    $_.skus = [math]::Round($_.skus, 0)
    $_.valor = [math]::Round($_.valor, 2)
    $_.mediaCustoDia = [math]::Round($_.mediaCustoDia, 2)
    $_.estoquePendente = [math]::Round($_.estoquePendente, 2)
    $_
  })
} else {
  if (-not $EstoqueXlsx) { throw "Arquivo de estoque nao encontrado (PosicaoEstoques*.csv ou Estoques*.xlsx)" }
  $fonteNome = [IO.Path]::GetFileName($EstoqueXlsx)
  Write-Host "Estoque: $EstoqueXlsx"

# --- Parse xlsx sheet1 ---
$Tmp = Join-Path $env:TEMP ("estoq_build_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
  Copy-Item -LiteralPath $EstoqueXlsx (Join-Path $Tmp "f.zip")
  Expand-Archive (Join-Path $Tmp "f.zip") -DestinationPath (Join-Path $Tmp "c") -Force
  $shared = @()
  $ssPath = Join-Path $Tmp "c\xl\sharedStrings.xml"
  if (Test-Path $ssPath) {
    [xml]$ss = Get-Content $ssPath -Encoding UTF8
    foreach ($si in $ss.sst.si) {
      if ($null -ne $si.t) { $shared += [string]$si.t }
      else { $shared += (($si.r | ForEach-Object { $_.t }) -join "") }
    }
  }
  [xml]$xml = Get-Content (Join-Path $Tmp "c\xl\worksheets\sheet1.xml") -Encoding UTF8
  $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
  $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")

  function Cell-Val($c) {
    $t = $c.GetAttribute("t")
    if ($t -eq "s") {
      $v = $c.SelectSingleNode("x:v", $ns)
      return $shared[[int]$v.InnerText]
    }
    if ($t -eq "inlineStr") {
      $node = $c.SelectSingleNode("x:is/x:t", $ns)
      return $(if ($node) { $node.InnerText } else { "" })
    }
    $v = $c.SelectSingleNode("x:v", $ns)
    if ($null -eq $v -or [string]::IsNullOrWhiteSpace($v.InnerText)) { return $null }
    return [double]$v.InnerText
  }

  $estoques = @()
  $isHeader = $true
  foreach ($row in $xml.SelectNodes("//x:sheetData/x:row", $ns)) {
    $vals = @($row.SelectNodes("x:c", $ns) | ForEach-Object { Cell-Val $_ })
    if ($isHeader) { $isHeader = $false; continue }
    $nome = [string]$vals[0]
    if ([string]::IsNullOrWhiteSpace($nome)) { continue }
    if ($nome -match '^(TOTAL|Total|SOMA|Filtro)') { continue }
    $skus = if ($vals.Count -gt 1 -and $null -ne $vals[1]) { [double]$vals[1] } else { 0 }
    $valor = if ($vals.Count -gt 2 -and $null -ne $vals[2]) { [double]$vals[2] } else { 0 }
    $media = if ($vals.Count -gt 3 -and $null -ne $vals[3]) { [double]$vals[3] } else { $null }
    $dias = if ($vals.Count -gt 4 -and $null -ne $vals[4]) { [double]$vals[4] } else { $null }
    $pend = if ($vals.Count -gt 5 -and $null -ne $vals[5]) { [double]$vals[5] } else { 0 }
    $estoques += [pscustomobject]@{
      nome = $nome.Trim()
      key = Get-NameKey $nome
      skus = [math]::Round($skus, 0)
      valor = [math]::Round($valor, 2)
      mediaCustoDia = if ($null -eq $media) { $null } else { [math]::Round($media, 2) }
      diasCobertura = if ($null -eq $dias) { $null } else { [math]::Round($dias, 1) }
      estoquePendente = [math]::Round($pend, 2)
      excluido = [bool](Test-Excluded $nome)
    }
  }
} finally {
  Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
}

Write-Host ("Grupos estoque: {0}" -f $estoques.Count)

# --- 4 semanas qtd media do data.json ---
if (-not (Test-Path $DataJsonPath)) { throw 'data.json ausente - rode build-data.ps1 antes.' }
$bundle = Get-Content $DataJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$series = @{}
$periodos = @()
foreach ($w in @($bundle.weeks | Sort-Object ordem)) {
  if (-not $w.hasData) { continue }
  $periodos += [ordered]@{
    ordem = [int]$w.ordem
    label = [string]$w.label
    periodo2026 = [string]$w.meta.periodo2026
  }
  $ord = [int]$w.ordem
  $gru = @($w.phases | Where-Object { $_.key -eq "grupos" } | Select-Object -First 1)
  if (-not $gru) { continue }
  $rows = $gru.bases.mesma.rows
  if (-not $rows) { $rows = $gru.bases.todas.rows }
  foreach ($r in @($rows)) {
    $key = Get-NameKey ([string]$r.nome)
    if (-not $series.ContainsKey($key)) {
      $series[$key] = [ordered]@{
        nome = [string]$r.nome
        key = $key
        qtd = @{}
        venda = @{}
        lucro = @{}
      }
    }
    $series[$key].qtd[$ord] = [double]$r.qtd2026
    $series[$key].venda[$ord] = [double]$r.venda2026
    $series[$key].lucro[$ord] = [double]$r.lucro2026
  }
}

function Get-Aligned($byOrdem) {
  $list = [System.Collections.Generic.List[object]]::new()
  foreach ($p in $periodos) {
    $ord = [int]$p.ordem
    if ($byOrdem -and $byOrdem.ContainsKey($ord)) {
      $list.Add([math]::Round([double]$byOrdem[$ord], 2))
    } else {
      $list.Add($null)
    }
  }
  return , $list.ToArray()
}

function Get-EmptyQtds {
  $list = [System.Collections.Generic.List[object]]::new()
  foreach ($p in $periodos) { $list.Add($null) }
  return , $list.ToArray()
}

function Get-AvgPresent($arr) {
  $present = @($arr | Where-Object { $null -ne $_ })
  if ($present.Count) { return ($present | Measure-Object -Average).Average }
  return 0
}

$vendaMap = @{}
foreach ($key in $series.Keys) {
  $qtds = Get-Aligned $series[$key].qtd
  $vendas = Get-Aligned $series[$key].venda
  $cmvByOrdem = @{}
  foreach ($ord in @($series[$key].venda.Keys)) {
    $vendaW = [double]$series[$key].venda[$ord]
    $lucroW = 0
    if ($series[$key].lucro.ContainsKey($ord)) { $lucroW = [double]$series[$key].lucro[$ord] }
    $cmvByOrdem[$ord] = $vendaW - $lucroW
  }
  $cmvs = Get-Aligned $cmvByOrdem
  $qPresent = @($qtds | Where-Object { $null -ne $_ })
  $vendaMap[$key] = [ordered]@{
    nome = $series[$key].nome
    semanas = $qPresent.Count
    qtdMediaSemanal = [math]::Round((Get-AvgPresent $qtds), 2)
    qtdTotal4s = if ($qPresent.Count) { [math]::Round(($qPresent | Measure-Object -Sum).Sum, 2) } else { 0 }
    qtdsPorSemana = $qtds
    vendaMediaSemanal = [math]::Round((Get-AvgPresent $vendas), 2)
    cmvMediaSemanal = [math]::Round((Get-AvgPresent $cmvs), 2)
  }
}
Write-Host ("Grupos com venda 4s: {0}" -f $vendaMap.Count)

$vendaByBase = @{}
foreach ($key in $vendaMap.Keys) {
  $base = Get-BaseNameKey $vendaMap[$key].nome
  if ($base -and -not $vendaByBase.ContainsKey($base)) {
    $vendaByBase[$base] = $vendaMap[$key]
  }
}

function Resolve-Venda($e) {
  if ($vendaMap.ContainsKey($e.key)) { return $vendaMap[$e.key] }
  $base = Get-BaseNameKey $e.nome
  if ($base -and $vendaByBase.ContainsKey($base)) { return $vendaByBase[$base] }
  return $null
}

function Get-Cobertura($valor, $v, $excelDias) {
  if ($valor -le 0) {
    return @{ dias = 0; semanas = 0; demanda = $null; base = "zerado" }
  }
  $demanda = $null
  $base = $null
  if ($v -and [double]$v.cmvMediaSemanal -gt 0) {
    $demanda = [double]$v.cmvMediaSemanal
    $base = "cmv4s"
  } elseif ($v -and [double]$v.vendaMediaSemanal -gt 0) {
    $demanda = [double]$v.vendaMediaSemanal
    $base = "venda4s"
  } elseif ($null -ne $excelDias) {
    return @{
      dias = [double]$excelDias
      semanas = [math]::Round([double]$excelDias / 7.0, 2)
      demanda = $null
      base = "excel"
    }
  }
  if ($null -ne $demanda -and $demanda -gt 0) {
    $sem = $valor / $demanda
    return @{
      dias = [math]::Round($sem * 7.0, 1)
      semanas = [math]::Round($sem, 2)
      demanda = [math]::Round($demanda, 0)
      base = $base
    }
  }
  return @{ dias = $null; semanas = $null; demanda = $null; base = $null }
}

# --- Classificacao ---
function Classify-Row($e, $v, $cob) {
  $qAvg = if ($v) { [double]$v.qtdMediaSemanal } else { 0 }
  $teveVenda = $qAvg -gt 0 -or ($null -ne $e.mediaCustoDia -and $e.mediaCustoDia -gt 0) -or ($v -and [double]$v.vendaMediaSemanal -gt 0)
  $dias = $cob.dias

  if ($e.excluido) {
    return @{ status = "fora_escopo"; motivo = "Categoria operacional/excluida"; tom = "neutral" }
  }
  if ($e.valor -le 0 -and $teveVenda) {
    return @{ status = "ruptura"; motivo = "Estoque zerado em $PosicaoData com historico de venda"; tom = "danger" }
  }
  if ($e.valor -le 0 -and -not $teveVenda) {
    return @{ status = "zerado_sem_giro"; motivo = "Zerado sem venda nas 4 semanas"; tom = "neutral" }
  }
  if ($null -ne $dias) {
    if ($dias -gt 0 -and $dias -lt $DiasCriticoBaixo -and $teveVenda) {
      return @{ status = "critico_baixo"; motivo = ("Cobertura {0:N1} dias / {1:N1} sem (abaixo de {2}d)" -f $dias, $cob.semanas, $DiasCriticoBaixo); tom = "danger" }
    }
    if ($dias -ge $DiasCriticoBaixo -and $dias -lt $DiasAtencaoBaixo -and $teveVenda) {
      return @{ status = "atencao_baixo"; motivo = ("Cobertura {0:N1} dias / {1:N1} sem (abaixo de {2}d)" -f $dias, $cob.semanas, $DiasAtencaoBaixo); tom = "warn" }
    }
    if ($dias -ge $DiasExcesso -and $e.valor -ge $ValorMinExcesso) {
      return @{ status = "excesso"; motivo = ("Cobertura {0:N1} dias / {1:N1} sem (acima de {2}d) com estoque material" -f $dias, $cob.semanas, $DiasExcesso); tom = "warn" }
    }
  } elseif ($teveVenda -and $e.valor -gt 0) {
    return @{ status = "sem_cobertura"; motivo = "Sem demanda das 4 semanas para calcular cobertura"; tom = "neutral" }
  }
  return @{ status = "saudavel"; motivo = "Dentro da faixa operacional"; tom = "ok" }
}

$rowsOut = @()
foreach ($e in $estoques) {
  $v = Resolve-Venda $e
  $cob = Get-Cobertura $e.valor $v $e.diasCobertura
  $cls = Classify-Row $e $v $cob
  $rowsOut += [pscustomobject]@{
    nome = if ($v) { $v.nome } else { $e.nome }
    key = if ($v) { Get-NameKey $v.nome } else { $e.key }
    skus = $e.skus
    valorEstoque = $e.valor
    mediaVendaCustoDia = $e.mediaCustoDia
    diasCobertura = $cob.dias
    semanasCobertura = $cob.semanas
    estoquePendente = $e.estoquePendente
    qtdMediaSemanal4s = if ($v) { $v.qtdMediaSemanal } else { $null }
    vendaMediaSemanal4s = if ($v) { $v.vendaMediaSemanal } else { $null }
    cmvMediaSemanal4s = if ($v) { $v.cmvMediaSemanal } else { $null }
    qtdTotal4s = if ($v) { $v.qtdTotal4s } else { $null }
    qtdsPorSemana = if ($v) { @($v.qtdsPorSemana) } else { @(Get-EmptyQtds) }
    semanasComVenda = if ($v) { $v.semanas } else { 0 }
    status = $cls.status
    motivo = $cls.motivo
    tom = $cls.tom
  }
}

function Pick([string]$status) {
  return @($rowsOut | Where-Object { $_.status -eq $status } | Sort-Object {
    if ($status -eq "excesso") { -$_.valorEstoque }
    elseif ($status -in @("ruptura","critico_baixo","atencao_baixo")) { -$_.qtdMediaSemanal4s }
    else { $_.nome }
  })
}

$ruptura = Pick "ruptura"
$critico = Pick "critico_baixo"
$atencao = Pick "atencao_baixo"
$excesso = Pick "excesso"
$saudavel = Pick "saudavel"

$totValor = ($rowsOut | Measure-Object valorEstoque -Sum).Sum
$valorRupturaPotencial = ($ruptura | Measure-Object qtdMediaSemanal4s -Sum).Sum  # qtd, not value
$valorExcesso = ($excesso | Measure-Object valorEstoque -Sum).Sum
$valorCritico = ($critico | Measure-Object valorEstoque -Sum).Sum

$payload = [ordered]@{
  meta = [ordered]@{
    titulo = "Radar de Estoque Critico"
    posicaoEm = $PosicaoData
    nivel = "Grupo (Categoria 3)"
    fonteEstoque = $fonteNome
    baseVenda = "Cobertura = estoque R$ / CMV medio semanal 2026 (mesma base, 4 semanas)"
    periodosVenda = $periodos
    regras = [ordered]@{
      ruptura = ('Estoque valor = 0 em {0} E houve venda (4 semanas ou media custo > 0)' -f $PosicaoData)
      critico_baixo = ('Cobertura (estoque / CMV semanal x 7) abaixo de {0} dias' -f $DiasCriticoBaixo)
      atencao_baixo = ('Cobertura entre {0} e {1} dias' -f $DiasCriticoBaixo, $DiasAtencaoBaixo)
      excesso = ('Cobertura acima de {0} dias e valor estoque >= {1}' -f $DiasExcesso, $ValorMinExcesso)
    }
    geradoEm = (Get-Date -Format "yyyy-MM-dd HH:mm")
  }
  totais = [ordered]@{
    grupos = $rowsOut.Count
    valorEstoque = [math]::Round($totValor, 0)
    ruptura = $ruptura.Count
    criticoBaixo = $critico.Count
    atencaoBaixo = $atencao.Count
    excesso = $excesso.Count
    saudavel = $saudavel.Count
    valorEmExcesso = [math]::Round($valorExcesso, 0)
    valorEmCriticoBaixo = [math]::Round($valorCritico, 0)
  }
  ruptura = @($ruptura | Select-Object -First 40)
  criticoBaixo = @($critico | Select-Object -First 40)
  atencaoBaixo = @($atencao | Select-Object -First 30)
  excesso = @($excesso | Select-Object -First 40)
  topExcesso = @($excesso | Select-Object -First 12)
  topRuptura = @($ruptura | Sort-Object { -$_.qtdMediaSemanal4s } | Select-Object -First 12)
  topCritico = @($critico | Sort-Object { $_.diasCobertura } | Select-Object -First 12)
  porStatus = @(
    [ordered]@{ status = "ruptura"; label = "Ruptura"; count = $ruptura.Count; tom = "danger" }
    [ordered]@{ status = "critico_baixo"; label = "Critico baixo"; count = $critico.Count; tom = "danger" }
    [ordered]@{ status = "atencao_baixo"; label = "Atencao baixo"; count = $atencao.Count; tom = "warn" }
    [ordered]@{ status = "excesso"; label = "Excesso"; count = $excesso.Count; tom = "warn" }
    [ordered]@{ status = "saudavel"; label = "Saudavel"; count = $saudavel.Count; tom = "ok" }
  )
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$jsonPretty = $payload | ConvertTo-Json -Depth 8
$jsonCompact = ($payload | ConvertTo-Json -Depth 8 -Compress)
[IO.File]::WriteAllText($JsonPath, $jsonPretty, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($JsPath, ("window.ESTOQUE_DATA = {0};" -f $jsonCompact), [Text.UTF8Encoding]::new($false))

Write-Host "OK -> $JsonPath"
Write-Host "OK -> $JsPath"
Write-Host ("Ruptura={0} Critico={1} Atencao={2} Excesso={3} Saudavel={4}" -f `
  $ruptura.Count, $critico.Count, $atencao.Count, $excesso.Count, $saudavel.Count)
Write-Host ("Valor excesso=R$ {0:N0} | Valor critico baixo=R$ {1:N0}" -f $valorExcesso, $valorCritico)
