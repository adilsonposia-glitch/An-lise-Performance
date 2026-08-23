<#
.SYNOPSIS
  Gera rede-data.js + entradas/rede/rede-semana-N.json a partir do CSV Visão Lojas.

.EXAMPLE
  .\build-rede.ps1 -Csv2026 "entradas\rede\Rede 14a 20Agosto2026 Visão Lojas  .csv" `
    -Periodo2025 "15/08/2025 a 21/08/2025" -Periodo2026 "14/08/2026 a 20/08/2026" -SemanaLabel "4ª Semana"
#>
[CmdletBinding()]
param(
  [string]$Csv2026 = "",
  [string]$Periodo2025 = "15/08/2025 a 21/08/2025",
  [string]$Periodo2026 = "14/08/2026 a 20/08/2026",
  [string]$SemanaLabel = "4ª Semana",
  [string]$OutlierLoja = "JD ESPERANCA - ATACADO"
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }
$RedeDir = Join-Path $Root "entradas\rede"

function Parse-BrNumber([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return 0.0 }
  $t = $s.Trim() -replace '%', '' -replace '\s', '' -replace '"', ''
  if ($t -eq '' -or $t -eq '-') { return 0.0 }
  # BR: 1.234,56  or plain 1234.56 / 1234,56
  if ($t -match '^\d{1,3}(\.\d{3})+(,\d+)?$') {
    $t = $t -replace '\.', '' -replace ',', '.'
  } elseif ($t -match '^\d+,\d+$') {
    $t = $t -replace ',', '.'
  }
  return [double]$t
}

function Get-VarPct([double]$a, [double]$b) {
  if ($a -eq 0) { if ($b -eq 0) { return 0.0 } else { return 100.0 } }
  return [math]::Round((($b - $a) / $a) * 100, 2)
}

if (-not $Csv2026) {
  $hit = Get-ChildItem -LiteralPath $RedeDir -File -Filter "*2026*Lojas*.csv" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $hit) { throw "CSV Visão Lojas 2026 nao encontrado em $RedeDir" }
  $Csv2026 = $hit.FullName
} elseif (-not [IO.Path]::IsPathRooted($Csv2026)) {
  $Csv2026 = Join-Path $Root $Csv2026
}
if (-not (Test-Path -LiteralPath $Csv2026)) { throw "Arquivo nao encontrado: $Csv2026" }

Write-Host "Lendo: $Csv2026"
$raw = Get-Content -LiteralPath $Csv2026 -Encoding UTF8
if ($raw.Count -lt 2) { throw "CSV vazio" }

# Parse header (comma CSV; quoted fields with commas rare in header)
$header = $raw[0].Split(',')
function Col([string[]]$cols, [string]$name) {
  for ($i = 0; $i -lt $cols.Count; $i++) {
    if ($cols[$i].Trim() -eq $name) { return $i }
  }
  return -1
}
$iAssoc = Col $header "NomeAssociado"
$iLoja = Col $header "NomeLoja"
$iV25 = Col $header "Venda Anterior"
$iV26 = Col $header "Venda Atual"
$iQ25 = Col $header "Qtde Itens Anterior"
$iQ26 = Col $header "Qtde Itens Atual"
$iM25 = Col $header "Mrkd Anterior"
$iM26 = Col $header "Mrkd Atual"
$iC25 = Col $header "Qtde Cupom Ant Frac"
$iC26 = Col $header "Qtde Cupom Atu Frac"
$iT25 = Col $header "Ticket Méd. Ant."
if ($iT25 -lt 0) { $iT25 = Col $header "Ticket Med. Ant." }
$iT26 = Col $header "Ticket Méd. Atu"
if ($iT26 -lt 0) { $iT26 = Col $header "Ticket Med. Atu" }

if ($iAssoc -lt 0 -or $iLoja -lt 0 -or $iV25 -lt 0 -or $iV26 -lt 0) {
  throw "Colunas obrigatorias ausentes no CSV"
}

function Split-CsvLine([string]$line) {
  $result = New-Object System.Collections.Generic.List[string]
  $sb = New-Object System.Text.StringBuilder
  $inQ = $false
  for ($i = 0; $i -lt $line.Length; $i++) {
    $ch = $line[$i]
    if ($ch -eq '"') { $inQ = -not $inQ; continue }
    if ($ch -eq ',' -and -not $inQ) {
      $result.Add($sb.ToString()); [void]$sb.Clear(); continue
    }
    [void]$sb.Append($ch)
  }
  $result.Add($sb.ToString())
  return , $result.ToArray()
}

$lojas = @()
for ($r = 1; $r -lt $raw.Count; $r++) {
  $line = $raw[$r]
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  $c = Split-CsvLine $line
  $assoc = $c[$iAssoc].Trim()
  $loja = $c[$iLoja].Trim()
  if (-not $assoc -or -not $loja) { continue }
  $v25 = Parse-BrNumber $c[$iV25]
  $v26 = Parse-BrNumber $c[$iV26]
  if ($v25 -eq 0 -and $v26 -eq 0) { continue }
  $lojas += [pscustomobject]@{
    associado = $assoc
    loja = $loja
    venda2025 = $v25
    venda2026 = $v26
    delta = [math]::Round($v26 - $v25, 2)
    varPct = Get-VarPct $v25 $v26
    qtd2025 = Parse-BrNumber $c[$iQ25]
    qtd2026 = Parse-BrNumber $c[$iQ26]
    cupom2025 = Parse-BrNumber $c[$iC25]
    cupom2026 = Parse-BrNumber $c[$iC26]
    mrkd2025 = Parse-BrNumber $c[$iM25]
    mrkd2026 = Parse-BrNumber $c[$iM26]
    tkt2025 = Parse-BrNumber $c[$iT25]
    tkt2026 = Parse-BrNumber $c[$iT26]
  }
}

Write-Host ("Lojas lidas: {0}" -f $lojas.Count)

$assocNames = @($lojas | Select-Object -ExpandProperty associado -Unique | Sort-Object)
$associados = @()
foreach ($name in $assocNames) {
  $rows = @($lojas | Where-Object { $_.associado -eq $name })
  $v25 = ($rows | Measure-Object venda2025 -Sum).Sum
  $v26 = ($rows | Measure-Object venda2026 -Sum).Sum
  $q25 = ($rows | Measure-Object qtd2025 -Sum).Sum
  $q26 = ($rows | Measure-Object qtd2026 -Sum).Sum
  $c25 = ($rows | Measure-Object cupom2025 -Sum).Sum
  $c26 = ($rows | Measure-Object cupom2026 -Sum).Sum
  # margem ponderada por venda
  $mrkd25num = 0.0; $mrkd26num = 0.0
  foreach ($row in $rows) {
    $mrkd25num += $row.mrkd2025 * $row.venda2025
    $mrkd26num += $row.mrkd2026 * $row.venda2026
  }
  $mrkd25 = if ($v25) { [math]::Round($mrkd25num / $v25, 2) } else { 0 }
  $mrkd26 = if ($v26) { [math]::Round($mrkd26num / $v26, 2) } else { 0 }
  $tkt25 = if ($c25) { [math]::Round($v25 / $c25, 2) } else { 0 }
  $tkt26 = if ($c26) { [math]::Round($v26 / $c26, 2) } else { 0 }
  $associados += [ordered]@{
    associado = $name
    lojas = $rows.Count
    venda2025 = [math]::Round($v25, 0)
    venda2026 = [math]::Round($v26, 0)
    delta = [math]::Round($v26 - $v25, 0)
    varPct = Get-VarPct $v25 $v26
    varQtd = Get-VarPct $q25 $q26
    varCupom = Get-VarPct $c25 $c26
    mrkd2025 = $mrkd25
    mrkd2026 = $mrkd26
    tkt2025 = $tkt25
    tkt2026 = $tkt26
  }
}
$associados = @($associados | Sort-Object { $_.delta } -Descending)

$totV25 = ($lojas | Measure-Object venda2025 -Sum).Sum
$totV26 = ($lojas | Measure-Object venda2026 -Sum).Sum
$totQ25 = ($lojas | Measure-Object qtd2025 -Sum).Sum
$totQ26 = ($lojas | Measure-Object qtd2026 -Sum).Sum
$totC25 = ($lojas | Measure-Object cupom2025 -Sum).Sum
$totC26 = ($lojas | Measure-Object cupom2026 -Sum).Sum
$mrkd25n = 0.0; $mrkd26n = 0.0
foreach ($row in $lojas) {
  $mrkd25n += $row.mrkd2025 * $row.venda2025
  $mrkd26n += $row.mrkd2026 * $row.venda2026
}

# Outlier atacado (se existir)
$outlier = $lojas | Where-Object { $_.loja -like "*$OutlierLoja*" -or $_.loja -match 'ESPERANCA.*ATACADO' } | Select-Object -First 1
$varSemAtacado = Get-VarPct $totV25 $totV26
$outlierNote = $null
$alvoradaSemOutlier = $null
if ($outlier) {
  $v25s = $totV25 - $outlier.venda2025
  $v26s = $totV26 - $outlier.venda2026
  $varSemAtacado = Get-VarPct $v25s $v26s
  $alv = $associados | Where-Object { $_.associado -eq $outlier.associado } | Select-Object -First 1
  if ($alv) {
    $a25 = $alv.venda2025 - $outlier.venda2025
    $a26 = $alv.venda2026 - $outlier.venda2026
    $alvoradaSemOutlier = Get-VarPct $a25 $a26
  }
  $outlierNote = ("{0} ({1}) concentra {2} ({3}%). Sem esse ponto, a Rede varia ~{4}%." -f `
    $outlier.loja, $outlier.associado,
    ("{0:N0}" -f $outlier.delta),
    ("{0:N1}" -f $outlier.varPct),
    ("{0:N1}" -f $varSemAtacado))
  if ($null -ne $alvoradaSemOutlier) {
    $outlierNote += (" {0} sem outlier: ~{1}%." -f $outlier.associado, ("{0:N1}" -f $alvoradaSemOutlier))
  }
}

$positivos = @($associados | Where-Object { $_.delta -gt 0 }).Count
$lider = $associados[0]

$topLojas = @($lojas | Sort-Object delta -Descending | Select-Object -First 5 | ForEach-Object {
  [ordered]@{ associado = $_.associado; loja = $_.loja; delta = [math]::Round($_.delta, 0); varPct = [math]::Round($_.varPct, 1) }
})
$bottomLojas = @($lojas | Sort-Object delta | Select-Object -First 5 | ForEach-Object {
  [ordered]@{ associado = $_.associado; loja = $_.loja; delta = [math]::Round($_.delta, 0); varPct = [math]::Round($_.varPct, 1) }
})

$csvName = [IO.Path]::GetFileName($Csv2026)
$payload = [ordered]@{
  meta = [ordered]@{
    periodo2025 = $Periodo2025
    periodo2026 = $Periodo2026
    semanaLabel = $SemanaLabel
    base = "Mesma Base de Lojas"
    metodo2026 = "Venda Atual do arquivo Visão Lojas (semana Sex→Qui)"
    metodo2025 = "Venda Anterior do mesmo arquivo Visão Lojas (YoY na mesma base)"
    arquivos = @($csvName)
    outlierNote = $outlierNote
  }
  totais = [ordered]@{
    venda2025 = [math]::Round($totV25, 0)
    venda2026 = [math]::Round($totV26, 0)
    delta = [math]::Round($totV26 - $totV25, 0)
    varPct = Get-VarPct $totV25 $totV26
    lojas = $lojas.Count
    associados = $associados.Count
    positivos = $positivos
    lider = $lider.associado
    varQtd = Get-VarPct $totQ25 $totQ26
    varCupom = Get-VarPct $totC25 $totC26
    mrkd2025 = if ($totV25) { [math]::Round($mrkd25n / $totV25, 2) } else { 0 }
    mrkd2026 = if ($totV26) { [math]::Round($mrkd26n / $totV26, 2) } else { 0 }
    tkt2025 = if ($totC25) { [math]::Round($totV25 / $totC25, 2) } else { 0 }
    tkt2026 = if ($totC26) { [math]::Round($totV26 / $totC26, 2) } else { 0 }
    varSemAtacado = $varSemAtacado
  }
  associados = $associados
  topLojas = $topLojas
  bottomLojas = $bottomLojas
}

$jsonPath = Join-Path $RedeDir "rede-semana-4.json"
$jsPath = Join-Path $Root "rede-data.js"
$json = $payload | ConvertTo-Json -Depth 8 -Compress
# PowerShell ConvertTo-Json may use weird formatting; write readable + JS
$jsonPretty = $payload | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($jsonPath, $jsonPretty, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($jsPath, ("window.REDE_DATA = {0};" -f $json), [Text.UTF8Encoding]::new($false))

Write-Host "OK -> $jsonPath"
Write-Host "OK -> $jsPath"
Write-Host ("Rede varPct={0}% delta={1:N0} associados={2} (positivos={3}) lider={4}" -f `
  $payload.totais.varPct, $payload.totais.delta, $payload.totais.associados, $positivos, $lider.associado)
if ($outlierNote) { Write-Host "Outlier: $outlierNote" }
