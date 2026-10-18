<#
  Semanas:
    25/09–01/10/2026 vs 26/09–02/10/2025
    02/10–08/10/2026 vs 03/10–09/10/2025
  Fonte: matriz Empresa × Cat1–4 (venda, lucro, qtd, clientes, ticket).
  Nova = sem venda em 2025 e com venda em 2026. Se a 17 ja vende no ano anterior, entra na mesma base.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
if (-not $Root) { $Root = Get-Location }
Set-Location $Root
. (Join-Path $Root "build-data.ps1")

$inv = [System.Globalization.CultureInfo]::InvariantCulture
$Sn = Join-Path $Root "entradas\semana-nova"
$Tmp = Join-Path $env:TEMP "build-25set-08out2026"
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

function Parse-EmpresaCat([string]$folder) {
  Write-Host "  lendo $folder ..."
  $path = Join-Path $Tmp "$folder\content\xl\worksheets\sheet1.xml"
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.IgnoreWhitespace = $true
  $r = [System.Xml.XmlReader]::Create($path, $settings)
  $lojas = @{}
  $merch = New-Object System.Collections.Generic.List[object]
  $vals = New-Object System.Collections.Generic.List[string]
  $inRow = $false
  $cellHadValue = $false
  $rowN = 0

  while ($r.Read()) {
    if ($r.NodeType -eq "Element" -and $r.LocalName -eq "row") {
      $vals.Clear()
      $inRow = $true
      $cellHadValue = $false
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "c" -and $inRow) {
      $cellHadValue = $false
      if ($r.IsEmptyElement) { [void]$vals.Add("") }
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "v" -and $inRow) {
      [void]$vals.Add($r.ReadElementContentAsString())
      $cellHadValue = $true
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "t" -and $inRow) {
      [void]$vals.Add($r.ReadElementContentAsString())
      $cellHadValue = $true
    }
    elseif ($r.NodeType -eq "EndElement" -and $r.LocalName -eq "c" -and $inRow) {
      if (-not $cellHadValue) { [void]$vals.Add("") }
    }
    elseif ($r.NodeType -eq "EndElement" -and $r.LocalName -eq "row") {
      $rowN++
      $inRow = $false
      if ($rowN -eq 1) { continue }
      if ($vals.Count -lt 6) { continue }
      $emp = [string]$vals[0]
      if (Test-FooterOrTotal $emp -and $emp.Trim() -ne "Total") { continue }
      $c1 = if ($vals.Count -gt 1) { [string]$vals[1] } else { "" }
      $c2 = if ($vals.Count -gt 2) { [string]$vals[2] } else { "" }
      $c3 = if ($vals.Count -gt 3) { [string]$vals[3] } else { "" }
      $c4 = if ($vals.Count -gt 4) { [string]$vals[4] } else { "" }
      $v = Parse-Num $(if ($vals.Count -gt 5) { $vals[5] } else { "" })
      $l = Parse-Num $(if ($vals.Count -gt 18) { $vals[18] } else { "" })
      $q = Parse-Num $(if ($vals.Count -gt 24) { $vals[24] } else { "" })
      $cli = Parse-Num $(if ($vals.Count -gt 32) { $vals[32] } else { "" })
      $tkt = Parse-Num $(if ($vals.Count -gt 35) { $vals[35] } else { "" })
      $empTot = Test-BlankCat $emp
      $c1b = Test-BlankCat $c1
      $c2b = Test-BlankCat $c2
      $c3b = Test-BlankCat $c3
      $c4b = Test-BlankCat $c4
      if ($empTot) { continue }
      if ($c1b) {
        $lojas[$emp] = [pscustomobject]@{
          nome = $emp
          venda = [math]::Round($v, 2)
          quantidade = [math]::Round($q, 2)
          lucro = [math]::Round($l, 2)
          margem = $(if ($v) { [math]::Round($l / $v, 6) } else { 0 })
          clientes = [math]::Round($cli, 0)
          ticket = $(if ($tkt) { [math]::Round($tkt, 2) } elseif ($cli) { [math]::Round($v / $cli, 2) } else { $null })
        }
      } elseif ($c2b) {
        if (-not (Test-Excluded $c1)) {
          [void]$merch.Add([pscustomobject]@{ emp = $emp; grain = "dept"; nome = $c1; venda = $v; lucro = $l; qtd = $q })
        }
      } elseif ($c3b) {
        if (-not (Test-Excluded $c2)) {
          [void]$merch.Add([pscustomobject]@{ emp = $emp; grain = "secao"; nome = $c2; venda = $v; lucro = $l; qtd = $q })
        }
      } elseif ($c4b) {
        if (-not (Test-Excluded $c3)) {
          [void]$merch.Add([pscustomobject]@{ emp = $emp; grain = "grupo"; nome = $c3; venda = $v; lucro = $l; qtd = $q })
        }
      }
    }
  }
  $r.Close()
  Write-Host ("    lojas={0} merch={1}" -f $lojas.Count, $merch.Count)
  return @{ lojas = @($lojas.Values); merch = $merch }
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
      $r.venda = 0
      $r.lucro = 0
      $r.quantidade = 0
      $r.margem = 0
      $r.clientes = 0
      $r.ticket = $null
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

function Build-WeekFromPair($file25, $file26, $periodo2025, $periodo2026, $src25, $src26) {
  $n25 = Expand-One (Join-Path $Sn $file25) $src25
  $n26 = Expand-One (Join-Path $Sn $file26) $src26
  $p25 = Parse-EmpresaCat $n25
  $p26 = Parse-EmpresaCat $n26
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

  Write-Host ("  Todas V26={0:N0} cli={1:N0}  Mesma V26={2:N0} lojas={3} novas={4}" -f `
    $lojasPhase.bases.todas.totals.venda2026, $lojasPhase.bases.todas.totals.clientes2026, `
    $lojasPhase.bases.mesma.totals.venda2026, $split.mesma.Count, ($novasNames -join ","))

  return [ordered]@{
    meta = [ordered]@{
      titulo = "Analise de Performance Comercial"
      periodoLabel = "Sexta a Quinta - Ano contra Ano"
      periodo2025 = $periodo2025
      periodo2026 = $periodo2026
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
}

Write-Host "Semana 25/09-01/10..."
$w1 = Build-WeekFromPair `
  "Venda 26Seta02Out25.xlsx" "Venda 25Seta01Out26.xlsx" `
  "26/09/2025 a 02/10/2025" "25/09/2026 a 01/10/2026" `
  "26a02Outubro2025 EmpresaCat" "25a01Outubro2026 EmpresaCat"

Write-Host "Semana 02/10-08/10..."
$w2 = Build-WeekFromPair `
  "Venda 03a09Out25.xlsx" "Venda 02a08Out26.xlsx" `
  "03/10/2025 a 09/10/2025" "02/10/2026 a 08/10/2026" `
  "03a09Outubro2025 EmpresaCat" "02a08Outubro2026 EmpresaCat"

$bundle = Read-Bundle
$bundle = Add-WeekToBundle $bundle $w1 0
$bundle = Add-WeekToBundle $bundle $w2 0
Write-Bundle $bundle
Write-Host "OK semanas gravadas (slot $($bundle.selectedWeek))"
$bundle.weeks | ForEach-Object {
  $st = if ($_.hasData) { "{0}  novas={1}" -f $_.meta.periodo2026, $_.storeMeta.novasCount } else { "sem dados" }
  Write-Host ("  {0}: {1}" -f $_.label, $st)
}
