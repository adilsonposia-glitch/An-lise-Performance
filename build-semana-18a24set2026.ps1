<#
  Semana 18–24/09/2026 vs 19–25/09/2025.
  Lojas = Clientes (4)/(5). Dept/Seção/Grupo = matriz Venda Todas Lojas.
  Mesma base 2026 = sem loja 17.
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
$Tmp = Join-Path $env:TEMP "build-18a24set2026"
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

function Get-Shared($folder) {
  $p = Join-Path $Tmp "$folder\content\xl\sharedStrings.xml"
  [xml]$ssXml = Get-Content $p -Encoding UTF8
  $ns = New-Object System.Xml.XmlNamespaceManager($ssXml.NameTable)
  $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
  $ss = New-Object System.Collections.Generic.List[string]
  foreach ($si in $ssXml.SelectNodes("//x:sst/x:si", $ns)) {
    $ts = $si.SelectNodes(".//x:t", $ns)
    if ($ts.Count -eq 0) { [void]$ss.Add("") }
    else { [void]$ss.Add((($ts | ForEach-Object InnerText) -join "")) }
  }
  return $ss
}

function Read-MatrizLevels([string]$folder) {
  Write-Host "  matriz $folder ..."
  $ss = Get-Shared $folder
  $path = Join-Path $Tmp "$folder\content\xl\worksheets\sheet1.xml"
  $settings = New-Object System.Xml.XmlReaderSettings
  $settings.IgnoreWhitespace = $true
  $r = [System.Xml.XmlReader]::Create($path, $settings)
  $deptT = @{}; $secT = @{}; $gruT = @{}
  $deptM = @{}; $secM = @{}; $gruM = @{}
  $row = @{}; $col = ""; $tAttr = ""; $inRow = $false

  function Acc($map, $name, $v, $l, $q) {
    if ([string]::IsNullOrWhiteSpace($name) -or $name -eq "Total") { return }
    if (Test-Excluded $name) { return }
    if (-not $map.ContainsKey($name)) {
      $map[$name] = [pscustomobject]@{ nome = $name; venda = 0.0; quantidade = 0.0; lucro = 0.0; margem = 0.0; clientes = $null; ticket = $null }
    }
    $map[$name].venda += $v
    $map[$name].lucro += $l
    $map[$name].quantidade += $q
  }

  while ($r.Read()) {
    if ($r.NodeType -eq "Element" -and $r.LocalName -eq "row") { $row = @{}; $inRow = $true }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "c" -and $inRow) {
      $ref = $r.GetAttribute("r")
      if ($ref -match "^([A-Z]+)") { $col = $Matches[1] } else { $col = "?" }
      $tAttr = $r.GetAttribute("t")
    }
    elseif ($r.NodeType -eq "Element" -and $r.LocalName -eq "v" -and $inRow) {
      $val = $r.ReadElementContentAsString()
      if ($tAttr -eq "s") {
        $ii = [int]$val
        $row[$col] = $(if ($ii -ge 0 -and $ii -lt $ss.Count) { $ss[$ii] } else { $val })
      } else { $row[$col] = $val }
    }
    elseif ($r.NodeType -eq "EndElement" -and $r.LocalName -eq "row") {
      $a = [string]$row["A"]; $b = [string]$row["B"]; $c = [string]$row["C"]
      $d = [string]$row["D"]; $e = [string]$row["E"]; $f = [string]$row["F"]
      $v = Parse-Num $row["G"]; $l = Parse-Num $row["T"]; $q = Parse-Num $row["Z"]
      $cT = [string]::IsNullOrWhiteSpace($c) -or $c -eq "Total"
      $dT = [string]::IsNullOrWhiteSpace($d) -or $d -eq "Total"
      $eT = [string]::IsNullOrWhiteSpace($e) -or $e -eq "Total"
      $fT = [string]::IsNullOrWhiteSpace($f) -or $f -eq "Total"
      $is17 = Test-IsStoreLoja17 $a
      if ((-not $cT) -and $dT) {
        Acc $deptT $c $v $l $q
        if (-not $is17) { Acc $deptM $c $v $l $q }
      } elseif ((-not $dT) -and $eT) {
        Acc $secT $d $v $l $q
        if (-not $is17) { Acc $secM $d $v $l $q }
      } elseif ((-not $eT) -and $fT) {
        Acc $gruT $e $v $l $q
        if (-not $is17) { Acc $gruM $e $v $l $q }
      }
      $inRow = $false
    }
  }
  $r.Close()

  function Finish($map) {
    foreach ($k in @($map.Keys)) {
      $o = $map[$k]
      $o.venda = [math]::Round($o.venda, 2)
      $o.lucro = [math]::Round($o.lucro, 2)
      $o.quantidade = [math]::Round($o.quantidade, 2)
      $o.margem = $(if ($o.venda) { [math]::Round($o.lucro / $o.venda, 6) } else { 0 })
    }
    return @($map.Values | Sort-Object nome)
  }

  return @{
    deptTodas = (Finish $deptT); deptMesma = (Finish $deptM)
    secTodas = (Finish $secT); secMesma = (Finish $secM)
    gruTodas = (Finish $gruT); gruMesma = (Finish $gruM)
  }
}

function To-PhaseRows($rows) {
  return @($rows | ForEach-Object {
    [pscustomobject]@{
      nome = $_.nome
      venda = $_.venda
      quantidade = $_.quantidade
      lucro = $_.lucro
      margem = $_.margem
      clientes = $null
      ticket = $null
    }
  })
}

Write-Host "Extraindo arquivos..."
$cli4 = Get-ChildItem -LiteralPath $Sn -File | Where-Object { $_.Name -eq "Clientes (4).xlsx" } | Select-Object -First 1
$cli5 = Get-ChildItem -LiteralPath $Sn -File | Where-Object { $_.Name -match '^Clientes\s+\(5\)\.xlsx$' } | Select-Object -First 1
$v25 = Join-Path $Sn "Venda Todas Lojas 19a25Set2025.xlsx"
$v26 = Join-Path $Sn "Venda Todas Lojas 18a24Set2026.xlsx"
if (-not $cli4 -or -not $cli5) { throw "Clientes (4) ou Clientes (5) nao encontrados em $Sn" }
if (-not (Test-Path -LiteralPath $v25) -or -not (Test-Path -LiteralPath $v26)) { throw "Arquivos Venda Todas Lojas ausentes" }

$nCli25 = Expand-One $cli4.FullName "19a25Setembro2025 Visao Lojas"
$nCli26 = Expand-One $cli5.FullName "18a24Setembro2026 Todas Visao Lojas"
$nV25 = Expand-One $v25 "19a25Setembro2025 Matriz"
$nV26 = Expand-One $v26 "18a24Setembro2026 Matriz"

Write-Host "Lojas (Clientes 4 e 5)..."
$lojas25 = @(Parse-Sheet $nCli25)
$lojas26 = @(Parse-Sheet $nCli26)
Write-Host ("  2025={0} lojas  2026={1} lojas" -f $lojas25.Count, $lojas26.Count)

$m25 = Read-MatrizLevels $nV25
$m26 = Read-MatrizLevels $nV26

function New-MerchPhase($key, $label, $t25, $t26, $m25rows, $m26rows, $src25, $src26) {
  $todas = Build-Base @(Compare-Years $t25 $t26) $false
  $mesma = Build-Base @(Compare-Years $m25rows $m26rows) $false
  return [ordered]@{
    key = $key; label = $label; hasClients = $false
    sources = [ordered]@{
      todas = [ordered]@{ y2025 = $src25; y2026 = $src26 }
      mesma = [ordered]@{ y2025 = $src25; y2026 = "$src26 (sem Loja 17)" }
    }
    bases = [ordered]@{
      todas = [ordered]@{ totals = $todas.totals; agressores = $todas.agressores; melhores = $todas.melhores; rows = $todas.rows }
      mesma = [ordered]@{ totals = $mesma.totals; agressores = $mesma.agressores; melhores = $mesma.melhores; rows = $mesma.rows }
    }
  }
}

$allLojas = @(Compare-Years $lojas25 $lojas26)
$mesmaLojas = @($allLojas | Where-Object {
  $_.venda2025 -gt 0 -and $_.venda2026 -gt 0 -and -not (Test-IsStoreLoja17 $_.nome)
})
$novas = @($allLojas | Where-Object {
  (Test-IsStoreLoja17 $_.nome -and $_.venda2026 -gt 0) -or
  (-not (Test-IsStoreLoja17 $_.nome) -and $_.venda2025 -le 0 -and $_.venda2026 -gt 0)
})

$lojasPhase = [ordered]@{
  key = "lojas"; label = "Lojas"; hasClients = $true
  sources = [ordered]@{
    todas = [ordered]@{ y2025 = $nCli25; y2026 = $nCli26 }
    mesma = [ordered]@{ y2025 = $nCli25; y2026 = "$nCli26 (sem Loja 17)" }
  }
  storeMeta = [ordered]@{
    allCount = $allLojas.Count
    comparableCount = $mesmaLojas.Count
    novasCount = $novas.Count
    novasNames = @($novas | ForEach-Object { $_.nome })
  }
  bases = [ordered]@{
    todas = (Build-Base $allLojas $true)
    mesma = (Build-Base $mesmaLojas $true)
  }
}

$payload = [ordered]@{
  meta = [ordered]@{
    titulo = "Analise de Performance Comercial"
    periodoLabel = "Sexta a Quinta - Ano contra Ano"
    periodo2025 = "19/09/2025 a 25/09/2025"
    periodo2026 = "18/09/2026 a 24/09/2026"
    anoBase = 2025
    anoAtual = 2026
    excluidos = @("NAO REVENDA", "INATIVOS", "SERVICOS", "RECICLAVEIS", "FRETE")
    geradoEm = (Get-Date -Format "yyyy-MM-dd HH:mm")
  }
  storeMeta = $lojasPhase.storeMeta
  phases = @(
    (New-MerchPhase "departamentos" "Departamentos" $m25.deptTodas $m26.deptTodas $m25.deptMesma $m26.deptMesma $nV25 $nV26),
    $lojasPhase,
    (New-MerchPhase "secao" "Mercadologico - Secao" $m25.secTodas $m26.secTodas $m25.secMesma $m26.secMesma $nV25 $nV26),
    (New-MerchPhase "grupos" "Mercadologico - Grupos" $m25.gruTodas $m26.gruTodas $m25.gruMesma $m26.gruMesma $nV25 $nV26)
  )
}

$bundle = Read-Bundle
$bundle = Add-WeekToBundle $bundle $payload 0
Write-Bundle $bundle
Write-Host "OK semana 18-24/09 gravada (slot $($bundle.selectedWeek))"
$bundle.weeks | ForEach-Object {
  $st = if ($_.hasData) { $_.meta.periodo2026 } else { "sem dados" }
  Write-Host ("  {0}: {1}" -f $_.label, $st)
}
Write-Host ("Lojas Todas V26={0:N0} cli={1:N0}" -f $lojasPhase.bases.todas.totals.venda2026, $lojasPhase.bases.todas.totals.clientes2026)
Write-Host ("Lojas Mesma V26={0:N0}" -f $lojasPhase.bases.mesma.totals.venda2026)
Write-Host ("Dept Todas V26={0:N0}" -f $payload.phases[0].bases.todas.totals.venda2026)
