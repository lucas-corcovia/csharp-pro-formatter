<#
.SYNOPSIS
    Hook PostToolUse da skill csharp-pro-formatter (Claude Code e Codex).

.DESCRIPTION
    Le o JSON do evento no stdin, descobre quais linhas de .cs o agente acabou de escrever e roda o
    scan-cs.ps1 somente nessas linhas (o legado do arquivo nao e acusado). Se houver violacao, devolve
    a lista no stderr com exit 2, o que faz o agente receber o feedback e corrigir na hora.
    Nunca altera arquivos. Qualquer erro interno termina com exit 0 para nao travar o agente.

    Claude Code: tool_input.file_path + new_string | content | edits[].new_string
    Codex:       tool_input.command com o patch do apply_patch (*** Add File / *** Update File)
#>

$ErrorActionPreference = 'Stop'
$maxReported = 40

function Get-LineNumber {
    param([string]$Text, [int]$Index)

    $count = 1

    for ($i = 0; $i -lt $Index; $i++) {
        if ($Text[$i] -eq "`n") { $count++ }
    }

    return $count
}

function Add-SnippetRange {
    param([hashtable]$Lines, [string]$ContentLf, [string]$Snippet)

    if ([string]::IsNullOrEmpty($Snippet)) { return }

    $snippetLf = $Snippet -replace "`r`n", "`n"
    $breaks = ([regex]::Matches($snippetLf, "`n")).Count
    $index = $ContentLf.IndexOf($snippetLf, [System.StringComparison]::Ordinal)
    $guard = 0

    while ($index -ge 0 -and $guard -lt 50) {
        $start = Get-LineNumber $ContentLf $index

        for ($n = $start; $n -le $start + $breaks; $n++) { $Lines[$n] = $true }

        $index = $ContentLf.IndexOf($snippetLf, $index + [Math]::Max(1, $snippetLf.Length), [System.StringComparison]::Ordinal)
        $guard++
    }
}

function Get-ClaudeTargets {
    param($ToolInput)

    $file = [string]$ToolInput.file_path

    if (-not $file.EndsWith('.cs', [System.StringComparison]::OrdinalIgnoreCase)) { return @() }
    if (-not (Test-Path -LiteralPath $file)) { return @() }

    $content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
    $contentLf = $content -replace "`r`n", "`n"
    $lines = @{}
    $names = @($ToolInput.PSObject.Properties | ForEach-Object { $_.Name })

    if ($names -contains 'content') {
        $total = ([regex]::Matches($contentLf, "`n")).Count + 1

        for ($n = 1; $n -le $total; $n++) { $lines[$n] = $true }
    }

    if ($names -contains 'new_string') { Add-SnippetRange $lines $contentLf ([string]$ToolInput.new_string) }

    if ($names -contains 'edits') {
        foreach ($edit in @($ToolInput.edits)) { Add-SnippetRange $lines $contentLf ([string]$edit.new_string) }
    }

    return @([pscustomobject]@{ File = $file; Content = $content; Lines = $lines; AddedText = $null })
}

function Get-CodexTargets {
    param($ToolInput, [string]$BaseDir)

    $command = $ToolInput.command

    if ($command -is [System.Array]) { $command = $command -join "`n" }

    $command = [string]$command

    if ($command -notmatch '\*\*\* (Add|Update) File:') { return @() }

    $added = @{}
    $current = $null

    foreach ($line in ($command -split "`r?`n")) {
        if ($line -match '^\*\*\* (Add|Update) File:\s*(.+?)\s*$') {
            $current = if ($Matches[2].EndsWith('.cs', [System.StringComparison]::OrdinalIgnoreCase)) { $Matches[2] } else { $null }

            if ($current -and -not $added.ContainsKey($current)) { $added[$current] = @{} }
        }
        elseif ($line -match '^\*\*\* Move to:\s*(.+?)\s*$' -and $current) {
            $added[$Matches[1]] = $added[$current]
            $added.Remove($current)
            $current = $Matches[1]
        }
        elseif ($line -match '^\*\*\* ') {
            $current = $null
        }
        elseif ($current -and $line.StartsWith('+') -and -not $line.StartsWith('+++')) {
            $text = $line.Substring(1).TrimEnd()

            # Linhas triviais ('{', '}', em branco) existem no arquivo todo; nao servem para localizar o trecho.
            if ($text.Trim().Length -gt 1) { $added[$current][$text] = $true }
        }
    }

    $targets = @()

    foreach ($relative in $added.Keys) {
        $file = if ([System.IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $BaseDir $relative }

        if (-not (Test-Path -LiteralPath $file)) { continue }

        $targets += [pscustomobject]@{
            File      = $file
            Content   = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
            Lines     = $null
            AddedText = $added[$relative]
        }
    }

    return $targets
}

try {
    $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput(), [System.Text.Encoding]::UTF8)
    $stdin = $reader.ReadToEnd()

    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $payload = $stdin | ConvertFrom-Json
    $toolInput = $payload.tool_input

    if ($null -eq $toolInput) { exit 0 }

    . (Join-Path $PSScriptRoot 'scan-cs.ps1')

    $baseDir = if ($payload.cwd) { [string]$payload.cwd } else { (Get-Location).ProviderPath }
    $inputNames = @($toolInput.PSObject.Properties | ForEach-Object { $_.Name })
    $targets = if ($inputNames -contains 'file_path') { Get-ClaudeTargets $toolInput }
               elseif ($inputNames -contains 'command') { Get-CodexTargets $toolInput $baseDir }
               else { @() }

    $report = New-Object 'System.Collections.Generic.List[string]'
    $total = 0

    foreach ($target in @($targets)) {
        foreach ($v in @(Get-CsViolations -FilePath $target.File -Content $target.Content)) {
            $hit = if ($target.Lines) { $target.Lines.ContainsKey($v.Line) }
                   else { $target.AddedText.ContainsKey($v.Text.TrimEnd()) }

            if (-not $hit) { continue }

            $total++

            if ($report.Count -lt $maxReported * 2) {
                $snippet = $v.Text.Trim()

                if ($snippet.Length -gt 100) { $snippet = $snippet.Substring(0, 100) + '...' }

                $report.Add(("  {0}:{1} [{2}] {3}" -f $target.File, $v.Line, $v.Rule, $v.Message))
                $report.Add("      > $snippet")
            }
        }
    }

    if ($total -eq 0) { exit 0 }

    $message = New-Object System.Text.StringBuilder
    [void]$message.AppendLine('[csharp-pro-formatter] O codigo C# que voce acabou de escrever esta fora do padrao obrigatorio de formatacao.')
    [void]$message.AppendLine('Corrija AGORA as linhas abaixo seguindo a skill csharp-pro-formatter (somente layout; nao mude logica nem nomes):')

    foreach ($line in $report) { [void]$message.AppendLine($line) }

    if ($total -gt $maxReported) { [void]$message.AppendLine("  ... e mais $($total - $maxReported) violacao(oes).") }

    [void]$message.AppendLine('Falso positivo (ex.: string ou URL impossivel de quebrar)? Mantenha e explique ao usuario no resumo.')

    [Console]::Error.Write($message.ToString())
    exit 2
}
catch {
    exit 0
}
