<#
  Cruza Estoque 5 (loja x fornecedor) com a venda 18-24/09/2026.
  Acrescenta window.ESTOQUE_DATA.fornecedores sem apagar o radar de grupos.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$MetaDias = 27.0

function Norm([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "" }
  $n = $s.Trim().ToUpperInvariant().Normalize([Text.NormalizationForm]::FormD)
  $n = [regex]::Replace($n, "\p{Mn}", "")
  return ([regex]::Replace($n, "[^A-Z0-9]+", " ")).Trim()
}
function Parse-D([string]$s) {
  $d = 0.0
  [void][double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d)
  return $d
}
function Is-13([string]$a) {
  return [bool]($a -match "^(01|05|07|08|09|10|11|12|13|14|15|16|17)\s")
}
function Is-12([string]$a) {
  return [bool]($a -match "^(01|05|07|08|09|10|11|12|13|14|15|16)\s")
}

$estSrc = Join-Path $Root "entradas\estoque\Estoque 5.xlsx"
$venSrc = Join-Path $Root "entradas\semana-nova\Venda Todas Lojas 18a24Set2026.xlsx"
if (-not (Test-Path -LiteralPath $estSrc)) { throw "Estoque 5.xlsx nao encontrado" }
if (-not (Test-Path -LiteralPath $venSrc)) { throw "Venda 18a24Set2026 nao encontrada" }

$tmp = Join-Path $env:TEMP "build-fornecedores"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

function Expand-X([string]$src, [string]$name) {
  $d = Join-Path $tmp $name
  if (Test-Path $d) { Remove-Item $d -Recurse -Force }
  New-Item $d -ItemType Directory | Out-Null
  Copy-Item -LiteralPath $src (Join-Path $d "f.zip")
  Expand-Archive (Join-Path $d "f.zip") (Join-Path $d "c") -Force
  return (Join-Path $d "c\xl\worksheets\sheet1.xml")
}

Write-Host "Estoque 5..."
$estSheet = Expand-X $estSrc "est5"
$raw = [IO.File]::ReadAllText($estSheet, [Text.Encoding]::UTF8)
$rowMatches = [regex]::Matches($raw, '<x:row>(.*?)</x:row>')
$cellRe = [regex]'<x:c\b[^>]*>(?:<x:is><x:t>([^<]*)</x:t></x:is>|<x:v>([^<]*)</x:v>)?</x:c>|<x:c\b[^>]*/>'
$forn13 = @{}; $forn12 = @{}; $fornCd = @{}; $fornAll = @{}
$n = 0
foreach ($m in $rowMatches) {
  $n++
  $cells = New-Object System.Collections.Generic.List[string]
  foreach ($c in $cellRe.Matches($m.Groups[1].Value)) {
    if ($c.Groups[1].Success) { $cells.Add($c.Groups[1].Value) }
    elseif ($c.Groups[2].Success) { $cells.Add($c.Groups[2].Value) }
    else { $cells.Add("") }
  }
  if ($n -eq 1) { continue }
  $a = $(if ($cells.Count -gt 0) { [System.Net.WebUtility]::HtmlDecode($cells[0]) } else { "" })
  $b = $(if ($cells.Count -gt 1) { [System.Net.WebUtility]::HtmlDecode($cells[1]) } else { "" })
  $val = $(if ($cells.Count -gt 3) { Parse-D $cells[3] } else { 0 })
  if ($a -match "Filtro|Exported" -or $a -eq "Total" -or -not $b -or $b -eq "Total") { continue }
  $nk = Norm $b
  if (-not $fornAll.ContainsKey($nk)) {
    $fornAll[$nk] = @{ nome = $b; all = 0.0; l13 = 0.0; l12 = 0.0; cd = 0.0 }
  }
  $fornAll[$nk].all += $val
  if ($a -match "^70") { $fornAll[$nk].cd += $val }
  if (Is-13 $a) { $fornAll[$nk].l13 += $val }
  if (Is-12 $a) { $fornAll[$nk].l12 += $val }
}
Write-Host ("  fornecedores estoque={0}" -f $fornAll.Count)

Write-Host "Venda 18-24/09/2026..."
$venSheetDir = Join-Path $tmp "ven26"
if (Test-Path $venSheetDir) { Remove-Item $venSheetDir -Recurse -Force }
New-Item $venSheetDir -ItemType Directory | Out-Null
Copy-Item -LiteralPath $venSrc (Join-Path $venSheetDir "f.zip")
Expand-Archive (Join-Path $venSheetDir "f.zip") (Join-Path $venSheetDir "c") -Force
[xml]$ssXml = Get-Content (Join-Path $venSheetDir "c\xl\sharedStrings.xml") -Encoding UTF8
$ns = New-Object System.Xml.XmlNamespaceManager($ssXml.NameTable)
$ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
$ss = New-Object System.Collections.Generic.List[string]
foreach ($si in $ssXml.SelectNodes("//x:sst/x:si", $ns)) {
  $ts = $si.SelectNodes(".//x:t", $ns)
  if ($ts.Count -eq 0) { [void]$ss.Add("") } else { [void]$ss.Add((($ts | ForEach-Object InnerText) -join "")) }
}
$settings = New-Object System.Xml.XmlReaderSettings
$settings.IgnoreWhitespace = $true
$vr = [System.Xml.XmlReader]::Create((Join-Path $venSheetDir "c\xl\worksheets\sheet1.xml"), $settings)
$venda13 = @{}; $venda12 = @{}
$row = @{}; $col = ""; $tAttr = ""; $inRow = $false
while ($vr.Read()) {
  if ($vr.NodeType -eq "Element" -and $vr.LocalName -eq "row") { $row = @{}; $inRow = $true }
  elseif ($vr.NodeType -eq "Element" -and $vr.LocalName -eq "c" -and $inRow) {
    $ref = $vr.GetAttribute("r")
    if ($ref -match "^([A-Z]+)") { $col = $Matches[1] } else { $col = "?" }
    $tAttr = $vr.GetAttribute("t")
  }
  elseif ($vr.NodeType -eq "Element" -and $vr.LocalName -eq "v" -and $inRow) {
    $val = $vr.ReadElementContentAsString()
    if ($tAttr -eq "s") {
      $ii = [int]$val
      $row[$col] = $(if ($ii -ge 0 -and $ii -lt $ss.Count) { $ss[$ii] } else { $val })
    } else { $row[$col] = $val }
  }
  elseif ($vr.NodeType -eq "EndElement" -and $vr.LocalName -eq "row") {
    $a = [string]$row["A"]; $b = [string]$row["B"]; $c = [string]$row["C"]
    $cT = [string]::IsNullOrWhiteSpace($c) -or $c -eq "Total"
    $bT = [string]::IsNullOrWhiteSpace($b) -or $b -eq "Total"
    if ((-not $bT) -and $cT -and $a -match "^\d+\s*-") {
      $nk = Norm $b
      $v = Parse-D $row["G"]
      if (Is-13 $a) {
        if (-not $venda13.ContainsKey($nk)) { $venda13[$nk] = @{ nome = $b; venda = 0.0 } }
        $venda13[$nk].venda += $v
      }
      if (Is-12 $a) {
        if (-not $venda12.ContainsKey($nk)) { $venda12[$nk] = @{ nome = $b; venda = 0.0 } }
        $venda12[$nk].venda += $v
      }
    }
    $inRow = $false
  }
}
$vr.Close()

function Build-Rows($vendaMap, $use12) {
  $totV = 0.0
  foreach ($x in $vendaMap.Values) { $totV += $x.venda }
  $rows = @()
  foreach ($k in $vendaMap.Keys) {
    $vv = $vendaMap[$k].venda
    $nome = $vendaMap[$k].nome
    $e = $fornAll[$k]
    $e13 = $(if ($e) { if ($use12) { $e.l12 } else { $e.l13 } } else { 0.0 })
    $ecd = $(if ($e) { $e.cd } else { 0.0 })
    $eall = $e13 + $ecd
    $dias13 = $(if ($vv -gt 0) { $e13 / ($vv / 7.0) } else { $null })
    $diasAll = $(if ($vv -gt 0) { $eall / ($vv / 7.0) } else { $null })
    $status = "ok"
    if ($e13 -le 0 -and $vv -gt 0) { $status = "ruptura" }
    elseif ($null -ne $dias13 -and $dias13 -lt 7) { $status = "critico" }
    elseif ($null -ne $dias13 -and $dias13 -lt 14) { $status = "atencao" }
    elseif ($null -ne $dias13 -and $dias13 -ge 60 -and $e13 -ge 50000) { $status = "excesso" }
    elseif ($null -ne $dias13 -and $dias13 -gt $MetaDias) { $status = "acima" }
    $delta = $(if ($null -ne $dias13) { $dias13 - $MetaDias } else { $null })
    $rows += [ordered]@{
      nome = $nome
      venda = [math]::Round($vv, 2)
      part = $(if ($totV) { [math]::Round(100.0 * $vv / $totV, 2) } else { 0 })
      estoqueLojas = [math]::Round($e13, 2)
      estoqueCd = [math]::Round($ecd, 2)
      estoqueAll = [math]::Round($eall, 2)
      diasLojas = $(if ($null -ne $dias13) { [math]::Round($dias13, 2) } else { $null })
      diasAll = $(if ($null -ne $diasAll) { [math]::Round($diasAll, 2) } else { $null })
      meta = $MetaDias
      delta = $(if ($null -ne $delta) { [math]::Round($delta, 2) } else { $null })
      over = [bool]($null -ne $dias13 -and $dias13 -gt $MetaDias)
      status = $status
    }
  }
  $estL = 0.0; $estC = 0.0
  foreach ($r in $rows) { $estL += $r.estoqueLojas; $estC += $r.estoqueCd }
  $diasRede = $(if ($totV) { $estL / ($totV / 7.0) } else { 0 })
  return @{
    totV = $totV
    totL = $estL
    totC = $estC
    dias = $diasRede
    rows = @($rows | Sort-Object { -$_.venda })
  }
}

$todas = Build-Rows $venda13 $false
$mesma = Build-Rows $venda12 $true

$payload = [ordered]@{
  meta = [ordered]@{
    titulo = "Gabarito fornecedor 27 d"
    fonteEstoque = "Estoque 5.xlsx"
    fonteVenda = "Venda Todas Lojas 18a24Set2026.xlsx"
    periodoVenda = "18/09/2026 a 24/09/2026"
    metaDias = $MetaDias
    regra = "Dias = estoque das lojas / (venda da semana / 7). Meta = 27 dias (mesmo alvo da loja). CD 70 entra so no recorte com CD."
    geradoEm = (Get-Date -Format "yyyy-MM-dd HH:mm")
  }
  totais = [ordered]@{
    todas = [ordered]@{
      venda = [math]::Round($todas.totV, 2)
      estoqueLojas = [math]::Round($todas.totL, 2)
      estoqueCd = [math]::Round($todas.totC, 2)
      diasLojas = [math]::Round($todas.dias, 2)
      fornecedores = $todas.rows.Count
      acimaMeta = @($todas.rows | Where-Object { $_.over }).Count
      ruptura = @($todas.rows | Where-Object { $_.status -eq "ruptura" }).Count
    }
    mesma = [ordered]@{
      venda = [math]::Round($mesma.totV, 2)
      estoqueLojas = [math]::Round($mesma.totL, 2)
      estoqueCd = [math]::Round($mesma.totC, 2)
      diasLojas = [math]::Round($mesma.dias, 2)
      fornecedores = $mesma.rows.Count
      acimaMeta = @($mesma.rows | Where-Object { $_.over }).Count
      ruptura = @($mesma.rows | Where-Object { $_.status -eq "ruptura" }).Count
    }
  }
  rowsTodas = @($todas.rows)
  rowsMesma = @($mesma.rows)
}

$jsPath = Join-Path $Root "estoque-data.js"
$jsonPath = Join-Path $Root "entradas\estoque\estoque-critico.json"
$rawJs = [IO.File]::ReadAllText($jsPath, [Text.UTF8Encoding]::new($false))
if ($rawJs -notmatch 'window\.ESTOQUE_DATA\s*=') { throw "estoque-data.js sem ESTOQUE_DATA" }
$json = $rawJs -replace '^\s*window\.ESTOQUE_DATA\s*=\s*', '' -replace ';\s*$', ''
$data = $json | ConvertFrom-Json
$data | Add-Member -NotePropertyName fornecedores -NotePropertyValue $payload -Force
$utf8 = [Text.UTF8Encoding]::new($false)
$pretty = $data | ConvertTo-Json -Depth 8
$compact = $data | ConvertTo-Json -Depth 8 -Compress
[IO.File]::WriteAllText($jsonPath, $pretty, $utf8)
[IO.File]::WriteAllText($jsPath, ("window.ESTOQUE_DATA = {0};" -f $compact), $utf8)
Write-Host ("OK fornecedores Todas={0}  Mesma={1}  dias13={2:N1}" -f $todas.rows.Count, $mesma.rows.Count, $todas.dias)
Write-Host ("Acima 27d={0}  ruptura={1}" -f $payload.totais.todas.acimaMeta, $payload.totais.todas.ruptura)
