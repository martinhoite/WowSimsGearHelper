param(
  [Parameter(Mandatory = $false)]
  [string]$Version
)

$ErrorActionPreference = "Stop"

function Get-DefaultVersion {
  $corePath = "Core.lua"
  if (-not (Test-Path -LiteralPath $corePath)) {
    throw "Core.lua not found. Run this script from the repository root."
  }

  $coreText = Get-Content -LiteralPath $corePath -Raw
  $match = [regex]::Match($coreText, 'WSGH\.VERSION\s*=\s*"([^"]+)"')
  if (-not $match.Success) {
    throw "Could not parse WSGH.VERSION from Core.lua."
  }

  return $match.Groups[1].Value
}

function Get-ExactSection {
  param(
    [string]$TargetVersion,
    [string[]]$SourceLines
  )

  $out = New-Object System.Collections.Generic.List[string]
  $inSection = $false
  $exactHeaderPattern = "^## \[$([regex]::Escape($TargetVersion))\]"

  foreach ($line in $SourceLines) {
    if ($line -match $exactHeaderPattern) {
      $inSection = $true
      $out.Add($line)
      continue
    }
    if ($inSection -and $line -match "^## \[") {
      break
    }
    if ($inSection) {
      $out.Add($line)
    }
  }

  if ($out.Count -eq 0) {
    $seenHeader = $false
    $inFirstSection = $false
    foreach ($line in $SourceLines) {
      if ($line -match "^## \[") {
        if (-not $seenHeader) {
          $seenHeader = $true
          $inFirstSection = $true
          $out.Add($line)
          continue
        }
        if ($inFirstSection) {
          break
        }
      }
      if ($inFirstSection) {
        $out.Add($line)
      }
    }
  }

  return ($out -join "`n").TrimEnd()
}

function Get-MinorSections {
  param(
    [string]$MinorKey,
    [string[]]$SourceLines
  )

  $out = New-Object System.Collections.Generic.List[string]
  $inSection = $false
  $minorHeaderPattern = "^## \[$([regex]::Escape($MinorKey))\."

  foreach ($line in $SourceLines) {
    if ($line -match "^## \[") {
      $inSection = ($line -match $minorHeaderPattern)
    }
    if ($inSection) {
      $out.Add($line)
    }
  }

  return ($out -join "`n").TrimEnd()
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-DefaultVersion
}

$changelogPath = "CHANGELOG.md"
if (-not (Test-Path -LiteralPath $changelogPath)) {
  throw "CHANGELOG.md not found. Run this script from the repository root."
}

$lines = Get-Content -LiteralPath $changelogPath

$minorKey = if ($Version -match '^([0-9]+\.[0-9]+)\.') {
  $Matches[1]
} else {
  $parts = $Version -split '\.'
  if ($parts.Count -ge 2) {
    "$($parts[0]).$($parts[1])"
  } else {
    $Version
  }
}

$githubBody = Get-ExactSection -TargetVersion $Version -SourceLines $lines
if ([string]::IsNullOrWhiteSpace($githubBody)) {
  $githubBody = "Release $Version"
}

$curseforgeBody = Get-MinorSections -MinorKey $minorKey -SourceLines $lines
if ([string]::IsNullOrWhiteSpace($curseforgeBody)) {
  $curseforgeBody = $githubBody
}
if ([string]::IsNullOrWhiteSpace($curseforgeBody)) {
  $curseforgeBody = "Release $Version"
}

$fullChangelogUrl = "https://github.com/martinhoite/WowSimsGearHelper/blob/main/CHANGELOG.md"
$curseforgeBody = ("Full changelog:`n$fullChangelogUrl`n`n" + $curseforgeBody.Trim())

Write-Host "=== VERSION ==="
Write-Host $Version
Write-Host "=== MINOR KEY ==="
Write-Host $minorKey
Write-Host "=== GITHUB BODY (exact tag section) ==="
Write-Host $githubBody
Write-Host "=== CURSEFORGE BODY (same x.Y.*) ==="
Write-Host $curseforgeBody
