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
  [string]$PosicaoData = "21/08/2026",
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

if (-not $EstoqueXlsx) {
  $hit = Get-ChildItem -LiteralPath (Join-Path $Root "entradas\semana-nova") -File -Filter "Estoques*.xlsx" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $hit) { throw "Arquivo Estoques*.xlsx nao encontrado em entradas\semana-nova" }
  $EstoqueXlsx = $hit.FullName
}

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
  $gru = @($w.phases | Where-Object { $_.key -eq "grupos" } | Select-Object -First 1)
  if (-not $gru) { continue }
  $rows = $gru.bases.mesma.rows
  if (-not $rows) { $rows = $gru.bases.todas.rows }
  foreach ($r in @($rows)) {
    $key = Get-NameKey ([string]$r.nome)
    if (-not $series.ContainsKey($key)) {
      $series[$key] = [ordered]@{ nome = [string]$r.nome; key = $key; qtds = [System.Collections.Generic.List[double]]::new() }
    }
    $series[$key].qtds.Add([double]$r.qtd2026)
  }
}

$vendaMap = @{}
foreach ($key in $series.Keys) {
  $qs = @($series[$key].qtds)
  $avg = if ($qs.Count) { ($qs | Measure-Object -Average).Average } else { 0 }
  $vendaMap[$key] = [ordered]@{
    nome = $series[$key].nome
    semanas = $qs.Count
    qtdMediaSemanal = [math]::Round($avg, 2)
    qtdTotal4s = [math]::Round(($qs | Measure-Object -Sum).Sum, 2)
    qtds = @($qs | ForEach-Object { [math]::Round($_, 2) })
  }
}
Write-Host ("Grupos com venda 4s: {0}" -f $vendaMap.Count)

# --- Classificacao ---
function Classify-Row($e, $v) {
  $qAvg = if ($v) { [double]$v.qtdMediaSemanal } else { 0 }
  $teveVenda = $qAvg -gt 0 -or ($null -ne $e.mediaCustoDia -and $e.mediaCustoDia -gt 0)
  $dias = $e.diasCobertura
  $semanasCob = if ($null -ne $dias) { [math]::Round($dias / 7.0, 2) } else { $null }

  # cobertura em semanas de venda (estoque vs demanda semanal a custo)
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
      return @{ status = "critico_baixo"; motivo = ("Cobertura {0:N1} dias (abaixo de {1}d = 1 semana de venda)" -f $dias, $DiasCriticoBaixo); tom = "danger" }
    }
    if ($dias -ge $DiasCriticoBaixo -and $dias -lt $DiasAtencaoBaixo -and $teveVenda) {
      return @{ status = "atencao_baixo"; motivo = ("Cobertura {0:N1} dias (abaixo de {1}d)" -f $dias, $DiasAtencaoBaixo); tom = "warn" }
    }
    if ($dias -ge $DiasExcesso -and $e.valor -ge $ValorMinExcesso) {
      return @{ status = "excesso"; motivo = ("Cobertura {0:N1} dias (acima de {1}d) com estoque material" -f $dias, $DiasExcesso); tom = "warn" }
    }
  } elseif ($teveVenda -and $e.valor -gt 0 -and $null -eq $e.mediaCustoDia) {
    return @{ status = "sem_cobertura"; motivo = "Sem media de venda a custo para calcular cobertura"; tom = "neutral" }
  }
  return @{ status = "saudavel"; motivo = "Dentro da faixa operacional"; tom = "ok" }
}

$rowsOut = @()
foreach ($e in $estoques) {
  $v = $null
  if ($vendaMap.ContainsKey($e.key)) { $v = $vendaMap[$e.key] }
  $cls = Classify-Row $e $v
  $dias = $e.diasCobertura
  $rowsOut += [pscustomobject]@{
    nome = $e.nome
    key = $e.key
    skus = $e.skus
    valorEstoque = $e.valor
    mediaVendaCustoDia = $e.mediaCustoDia
    diasCobertura = $dias
    semanasCobertura = if ($null -ne $dias) { [math]::Round($dias / 7.0, 2) } else { $null }
    estoquePendente = $e.estoquePendente
    qtdMediaSemanal4s = if ($v) { $v.qtdMediaSemanal } else { $null }
    qtdTotal4s = if ($v) { $v.qtdTotal4s } else { $null }
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
    fonteEstoque = [IO.Path]::GetFileName($EstoqueXlsx)
    baseVenda = "Qtd media semanal 2026 - Mesma base - 4 semanas do data.json"
    periodosVenda = $periodos
    regras = [ordered]@{
      ruptura = ('Estoque valor = 0 em {0} E houve venda (4 semanas ou media custo > 0)' -f $PosicaoData)
      critico_baixo = ('Dias de cobertura abaixo de {0} (menos de 1 semana de venda)' -f $DiasCriticoBaixo)
      atencao_baixo = ('Dias de cobertura entre {0} e {1}' -f $DiasCriticoBaixo, $DiasAtencaoBaixo)
      excesso = ('Dias de cobertura acima de {0} e valor estoque >= {1}' -f $DiasExcesso, $ValorMinExcesso)
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
