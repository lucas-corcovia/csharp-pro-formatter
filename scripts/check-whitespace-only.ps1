<#
.SYNOPSIS
    Prova que as alteracoes em .cs sao somente de formatacao (skill csharp-pro-formatter).

.DESCRIPTION
    Para cada .cs alterado em relacao a -Base (padrao HEAD), compara a versao do git com a do disco
    removendo todo espaco, tab e quebra de linha. Se sobrar diferenca, a alteracao mexeu em algo
    alem de layout (nome, logica, string, comentario) e o arquivo e listado. Read-only.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File check-whitespace-only.ps1 -Repo C:\repos\MeuProjeto
#>
[CmdletBinding()]
param(
    [string]$Repo = '.',
    [string]$Base = 'HEAD'
)

function Invoke-GitText {
    param([string]$WorkDir, [string[]]$Arguments)

    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = 'git'
    $info.Arguments = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $info.WorkingDirectory = $WorkDir
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    $process = [System.Diagnostics.Process]::Start($info)
    $output = $process.StandardOutput.ReadToEnd()
    [void]$process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output }
}

function Remove-AllWhitespace {
    param([string]$Text)

    return ($Text.TrimStart([char]0xFEFF) -replace '\s+', '')
}

$repoPath = (Resolve-Path -LiteralPath $Repo).ProviderPath
$top = (Invoke-GitText $repoPath @('rev-parse', '--show-toplevel')).Output.Trim()

if (-not $top) {
    Write-Output "Nao e um repositorio git: $repoPath"
    exit 2
}

$changed = (Invoke-GitText $top @('diff', '--name-only', '--diff-filter=M', $Base, '--', '*.cs')).Output -split "`n" |
    Where-Object { $_.Trim() }

$offenders = @()

foreach ($relative in $changed) {
    $relative = $relative.Trim()
    $old = (Invoke-GitText $top @('show', "$($Base):$relative")).Output
    $new = [System.IO.File]::ReadAllText((Join-Path $top $relative), [System.Text.Encoding]::UTF8)

    if ((Remove-AllWhitespace $old) -cne (Remove-AllWhitespace $new)) { $offenders += $relative }
}

Write-Output ("Arquivos .cs alterados: {0} | com mudanca alem de formatacao: {1}" -f @($changed).Count, $offenders.Count)

foreach ($file in $offenders) { Write-Output "  ALTERADO_ALEM_DE_FORMATACAO: $file" }

if ($offenders.Count -gt 0) { exit 1 }

exit 0
