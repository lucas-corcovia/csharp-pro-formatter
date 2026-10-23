<#
.SYNOPSIS
    Scanner read-only de layout C# da skill csharp-pro-formatter.

.DESCRIPTION
    Aponta violacoes de formatacao em arquivos .cs (nunca altera nada):
      LONG                     linha acima do limite de colunas
      CODE_AFTER_OPEN_BRACE    codigo depois de '{' na mesma linha  ->  if (x) { Faz();
      CODE_AROUND_CLOSE_BRACE  codigo antes/depois de '}'           ->  return x;}   }return y;   } else
      BRACE_END_OF_LINE        '{' no fim de uma linha com codigo   ->  try {   if (x) {
      MULTI_STATEMENT          mais de uma instrucao na mesma linha ->  a = 1; b = 2;
      SAME_LINE_BODY           corpo na mesma linha do if/for/else  ->  if (x) return;
      KEYWORD_SPACE            falta espaco apos palavra-chave      ->  if(x)
      SPACE_AFTER_COMMA        falta espaco apos virgula            ->  Metodo(a,b)
      DOUBLE_BLANK             duas linhas em branco seguidas
      BLANK_AFTER_OPEN_BRACE   linha em branco logo apos '{'
      BLANK_BEFORE_CLOSE_BRACE linha em branco logo antes de '}'
      MISSING_BLANK_BEFORE_BLOCK  if/for/foreach/while/switch/try/using/lock colado na instrucao anterior
      MISSING_BLANK_AFTER_BLOCK   instrucao colada no '}' ou no corpo sem chaves de um if/else/for/while
      INDENT                  indentacao que nao e multipla de 4 espacos
      TAB                      indentacao com tab
      TRAILING_WS              espacos no fim da linha

    Strings, chars e comentarios sao ignorados nas checagens de codigo.
    Respeita o .editorconfig mais proximo: max_line_length e
    csharp_new_line_before_open_brace = none (desliga as regras de Allman).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scan-cs.ps1 -Path .\src
    powershell -NoProfile -ExecutionPolicy Bypass -File scan-cs.ps1 -Path .\src -Summary
    powershell -NoProfile -ExecutionPolicy Bypass -File scan-cs.ps1 -Path .\src -Json > baseline.json
#>
[CmdletBinding()]
param(
    [string[]]$Path = @('.'),
    [int]$MaxLength = 0,
    [switch]$Json,
    [switch]$Summary
)

$script:DefaultMaxLength = 120
$script:ExcludedDirPattern = '[\\/](bin|obj|Migrations|node_modules|\.git|\.vs|packages|TestResults)[\\/]'
$script:ExcludedNamePattern = '(\.Designer|\.g|\.g\.i|\.generated)\.cs$|^AssemblyInfo\.cs$'
$script:AccessorPattern = '^\s*((public|private|protected|internal|required)\s+)*(get|set|init|add|remove)\b'
$script:QueryKeywordPattern = '^(from|where|select|orderby|join|let|group|into|on|equals|by|ascending|descending)\b'
$script:BlockStatementPattern = '^(if|for|foreach|while|switch|lock|fixed|using)\s*\(|^(try|do)$'
$script:BracelessOwnerPattern = '^(else\b|(if|for|foreach|while|lock|fixed|using)\s*\()'
# O que pode vir colado depois de '}' ou do corpo sem chaves: continuacao do mesmo bloco/expressao.
$script:GlueAfterBlockPattern = '^([\)\]\};,\.\?:#]|&&|\|\||=>|(else|catch|finally|and|or|when|with)\b|while\b.*;$)'
$script:EditorConfigCache = @{}

function Test-CsExcluded {
    param([string]$FullName)

    if ($FullName -match $script:ExcludedDirPattern) { return $true }

    $name = [System.IO.Path]::GetFileName($FullName)

    return ($name -match $script:ExcludedNamePattern)
}

function Get-CsFiles {
    param([string[]]$Paths)

    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p -PathType Container) {
            Get-ChildItem -LiteralPath $p -Recurse -File -Filter '*.cs' -ErrorAction SilentlyContinue |
                Where-Object { -not (Test-CsExcluded $_.FullName) } |
                ForEach-Object { $_.FullName }
        }
        elseif (Test-Path -LiteralPath $p -PathType Leaf) {
            $full = (Resolve-Path -LiteralPath $p).ProviderPath

            if ($full -like '*.cs' -and -not (Test-CsExcluded $full)) { $full }
        }
        else {
            Write-Warning "Caminho nao encontrado: $p"
        }
    }
}

function Get-EditorConfigSettings {
    param([string]$Directory)

    if ($script:EditorConfigCache.ContainsKey($Directory)) { return $script:EditorConfigCache[$Directory] }

    $settings = @{ MaxLength = 0; KAndR = $false }
    $dir = $Directory

    while ($dir) {
        $file = Join-Path $dir '.editorconfig'

        if (Test-Path -LiteralPath $file) {
            $text = [System.IO.File]::ReadAllText($file)

            if ($settings.MaxLength -eq 0 -and $text -match '(?m)^\s*max_line_length\s*=\s*(\d+)') {
                $settings.MaxLength = [int]$Matches[1]
            }

            if ($text -match '(?m)^\s*csharp_new_line_before_open_brace\s*=\s*none') { $settings.KAndR = $true }
            if ($text -match '(?m)^\s*root\s*=\s*true') { break }
        }

        $parent = [System.IO.Path]::GetDirectoryName($dir)

        if ($parent -eq $dir) { break }

        $dir = $parent
    }

    $script:EditorConfigCache[$Directory] = $settings

    return $settings
}

function Get-QuoteRun {
    param([string]$Line, [int]$Index)

    $run = 0

    while ($Index + $run -lt $Line.Length -and $Line[$Index + $run] -eq '"') { $run++ }

    return $run
}

# Devolve, para cada linha, o "codigo puro": comentarios removidos e conteudo de strings/chars esvaziado.
function ConvertTo-CodeView {
    param([string[]]$Lines)

    $mode = 'Normal'
    $rawQuotes = 0
    $result = New-Object 'System.Collections.Generic.List[object]'

    foreach ($line in $Lines) {
        $startMode = $mode

        if ($mode -eq 'Normal' -and $line.IndexOfAny([char[]]@('"', "'", '/')) -lt 0) {
            $result.Add([pscustomobject]@{ Code = $line; StartMode = $startMode })
            continue
        }

        $sb = New-Object System.Text.StringBuilder
        $i = 0
        $n = $line.Length

        while ($i -lt $n) {
            $ch = $line[$i]
            $next = if ($i + 1 -lt $n) { $line[$i + 1] } else { [char]0 }

            if ($mode -eq 'Block') {
                if ($ch -eq '*' -and $next -eq '/') { $mode = 'Normal'; $i += 2 } else { $i++ }
            }
            elseif ($mode -eq 'Verbatim') {
                if ($ch -eq '"' -and $next -eq '"') { $i += 2 }
                elseif ($ch -eq '"') { $mode = 'Normal'; [void]$sb.Append('"'); $i++ }
                else { $i++ }
            }
            elseif ($mode -eq 'Raw') {
                if ($ch -eq '"' -and (Get-QuoteRun $line $i) -ge $rawQuotes) {
                    $mode = 'Normal'
                    [void]$sb.Append('"')
                    $i += $rawQuotes
                }
                else { $i++ }
            }
            elseif ($ch -eq '/' -and $next -eq '/') {
                break
            }
            elseif ($ch -eq '/' -and $next -eq '*') {
                $mode = 'Block'
                $i += 2
            }
            elseif ($ch -eq '"') {
                $run = Get-QuoteRun $line $i
                $prev = if ($i -gt 0) { $line[$i - 1] } else { [char]0 }
                $prev2 = if ($i -gt 1) { $line[$i - 2] } else { [char]0 }

                if ($run -ge 3) {
                    $mode = 'Raw'
                    $rawQuotes = $run
                    [void]$sb.Append('"')
                    $i += $run
                }
                elseif ($prev -eq '@' -or ($prev -eq '$' -and $prev2 -eq '@')) {
                    $mode = 'Verbatim'
                    [void]$sb.Append('"')
                    $i++
                }
                else {
                    $j = $i + 1

                    while ($j -lt $n -and $line[$j] -ne '"') {
                        if ($line[$j] -eq '\') { $j++ }
                        $j++
                    }

                    [void]$sb.Append('""')
                    $i = $j + 1
                }
            }
            elseif ($ch -eq "'") {
                $j = $i + 1

                if ($j -lt $n -and $line[$j] -eq '\') { $j += 2 } else { $j++ }
                while ($j -lt $n -and $line[$j] -ne "'") { $j++ }

                [void]$sb.Append("''")
                $i = $j + 1
            }
            else {
                [void]$sb.Append($ch)
                $i++
            }
        }

        $result.Add([pscustomobject]@{ Code = $sb.ToString(); StartMode = $startMode })
    }

    return ,$result
}

function Get-CsViolations {
    param(
        [string]$FilePath,
        [string]$Content,
        [int]$MaxLength = 0,
        [switch]$IgnoreEditorConfig
    )

    if (-not $PSBoundParameters.ContainsKey('Content')) {
        $Content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
    }

    $violations = New-Object 'System.Collections.Generic.List[object]'

    if ($Content.Length -gt 0 -and $Content.Substring(0, [Math]::Min(2000, $Content.Length)) -match '<auto-generated') {
        return $violations
    }

    $settings = @{ MaxLength = 0; KAndR = $false }

    if ($FilePath -and -not $IgnoreEditorConfig) {
        $settings = Get-EditorConfigSettings ([System.IO.Path]::GetDirectoryName($FilePath))
    }

    $limit = if ($MaxLength -gt 0) { $MaxLength }
             elseif ($settings.MaxLength -gt 0) { $settings.MaxLength }
             else { $script:DefaultMaxLength }

    $kAndR = $settings.KAndR
    $lines = $Content.TrimStart([char]0xFEFF) -split "`r?`n"

    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
        $lines = @($lines | Select-Object -First ($lines.Count - 1))
    }

    if ($lines.Count -eq 0) { return $violations }

    $views = ConvertTo-CodeView $lines

    # Linha de codigo de verdade (nao branca, nao so comentario, nao conteudo de string multilinha).
    $isCode = {
        param($i)

        $v = $views[$i]

        return ($v.StartMode -ne 'Block' -and $v.StartMode -ne 'Verbatim' -and $v.StartMode -ne 'Raw' `
            -and $v.Code.Trim().Length -gt 0)
    }

    $indentOf = { param($i) $lines[$i].Length - $lines[$i].TrimStart(' ').Length }

    for ($idx = 0; $idx -lt $lines.Count; $idx++) {
        $raw = $lines[$idx]
        $view = $views[$idx]
        $lineNo = $idx + 1
        $found = @{}

        $add = {
            param($rule, $message)

            if (-not $found.ContainsKey($rule)) {
                $found[$rule] = $true
                $violations.Add([pscustomobject]@{
                    File    = $FilePath
                    Line    = $lineNo
                    Rule    = $rule
                    Message = $message
                    Text    = $raw
                })
            }
        }

        # Linha que comeca dentro de string multilinha: o conteudo e dado, nao layout.
        if ($view.StartMode -eq 'Verbatim' -or $view.StartMode -eq 'Raw') { continue }

        $trimmed = $raw.Trim()
        $isBlank = $trimmed.Length -eq 0

        if ($raw -match '^\s*\t') { & $add 'TAB' 'Indentacao com tab; use 4 espacos.' }

        if ($raw -match '[ \t]+$') { & $add 'TRAILING_WS' 'Espacos no fim da linha.' }

        $width = ($raw -replace "`t", '    ').Length
        $isUrlComment = $trimmed.StartsWith('//') -and $trimmed -match 'https?://'

        if ($width -gt $limit -and -not $isUrlComment) {
            & $add 'LONG' "Linha com $width colunas (maximo $limit); quebre a linha."
        }

        if ($isBlank) {
            $prev = if ($idx -gt 0) { $lines[$idx - 1].Trim() } else { $null }
            $next = if ($idx + 1 -lt $lines.Count) { $lines[$idx + 1].Trim() } else { $null }

            if ($idx -gt 0 -and $prev.Length -eq 0) { & $add 'DOUBLE_BLANK' 'Duas linhas em branco seguidas.' }
            if ($prev -eq '{') { & $add 'BLANK_AFTER_OPEN_BRACE' "Linha em branco logo apos '{'." }
            if ($null -ne $next -and $next.StartsWith('}')) {
                & $add 'BLANK_BEFORE_CLOSE_BRACE' "Linha em branco logo antes de '}'."
            }

            continue
        }

        if ($view.StartMode -eq 'Block') { continue }

        # Blocos separados por linha em branco: nada de 'var' colado em 'if' nem '}' colado em 'await'.
        $head = if ($view.Code.Trim().Length -gt 0) { $view.Code.Trim() } else { $trimmed }
        $currentIndent = & $indentOf $idx

        if ($idx -gt 0 -and $head -notmatch $script:GlueAfterBlockPattern -and $head -notmatch $script:AccessorPattern) {
            if ($head -cmatch $script:BlockStatementPattern) {
                # Comentario logo acima pertence ao bloco; a linha em branco vai antes dele.
                $p = $idx - 1

                while ($p -ge 0 -and $lines[$p].Trim().Length -gt 0 -and $views[$p].StartMode -notin @('Raw', 'Verbatim') `
                    -and -not (& $isCode $p)) { $p-- }

                if ($p -ge 0 -and $lines[$p].Trim().Length -gt 0) {
                    $prevHead = $views[$p].Code.Trim()
                    $stacked = $head -cmatch '^(using|fixed)\s*\(' -and $prevHead -cmatch '^(using|fixed)\s*\('

                    if ((& $indentOf $p) -ge $currentIndent -and -not $stacked -and $prevHead -ne '{' `
                        -and $prevHead -notmatch '^(#|case\b|default\s*:)') {
                        & $add 'MISSING_BLANK_BEFORE_BLOCK' "Falta linha em branco antes do bloco; separe-o da instrucao anterior."
                    }
                }
            }
            elseif (& $isCode ($idx - 1)) {
                $prevHead = $views[$idx - 1].Code.Trim()

                if ($prevHead -eq '}') {
                    & $add 'MISSING_BLANK_AFTER_BLOCK' "Falta linha em branco depois de '}'; separe o proximo trecho do bloco."
                }
                elseif ((& $indentOf ($idx - 1)) -gt $currentIndent -and $prevHead.EndsWith(';')) {
                    # Fim do corpo sem chaves de um if/else/for/while: sobe ate a instrucao dona.
                    $o = $idx - 1

                    while ($o -ge 0 -and (-not (& $isCode $o) -or (& $indentOf $o) -gt $currentIndent)) { $o-- }

                    if ($o -ge 0 -and (& $indentOf $o) -eq $currentIndent `
                        -and $views[$o].Code.Trim() -cmatch $script:BracelessOwnerPattern) {
                        & $add 'MISSING_BLANK_AFTER_BLOCK' 'Falta linha em branco depois do corpo do if/else/for/while.'
                    }
                }
            }
        }

        $code = $view.Code.TrimEnd()
        $ct = $code.Trim()

        if ($ct.Length -eq 0) { continue }

        $indent = $raw.Length - $raw.TrimStart(' ').Length

        if ($raw -notmatch '^\s*\t' -and $indent % 4 -ne 0 -and $ct -notmatch $script:QueryKeywordPattern) {
            & $add 'INDENT' "Indentacao de $indent espacos; use multiplos de 4."
        }

        if ($code -cmatch '\b(if|for|foreach|while|switch|catch|using|lock|fixed)\(') {
            & $add 'KEYWORD_SPACE' "Falta espaco entre a palavra-chave e '('."
        }

        if ($code -match ',(?=[^\s,\]\)>])') { & $add 'SPACE_AFTER_COMMA' 'Falta espaco apos a virgula.' }

        # Chaves: pares abertos e fechados na mesma linha sao blocos de uma linha;
        # o resto abre ou fecha blocos de varias linhas.
        $stack = New-Object 'System.Collections.Generic.Stack[int]'

        for ($i = 0; $i -lt $code.Length; $i++) {
            $ch = $code[$i]

            if ($ch -eq '{') {
                $stack.Push($i)
            }
            elseif ($ch -eq '}') {
                if ($stack.Count -gt 0) {
                    $open = $stack.Pop()
                    $inner = $code.Substring($open + 1, $i - $open - 1)

                    if ($inner.Contains(';') -and $inner -notmatch $script:AccessorPattern) {
                        & $add 'CODE_AFTER_OPEN_BRACE' 'Bloco com instrucoes numa linha so; abra o bloco em linhas.'
                    }
                }
                else {
                    $before = $code.Substring(0, $i).Trim()
                    $after = $code.Substring($i + 1).Trim()

                    if ($before.Length -gt 0) {
                        & $add 'CODE_AROUND_CLOSE_BRACE' "Codigo antes de '}'; a chave de fechamento fica sozinha."
                    }

                    if ($after -match '^(else|catch|finally)\b') {
                        if (-not $kAndR) {
                            & $add 'CODE_AROUND_CLOSE_BRACE' "'else/catch/finally' vai na linha seguinte a '}'."
                        }
                    }
                    elseif ($after.Length -gt 0 -and $after -notmatch '^([\)\]\;\,\.\?\}]|while\b)') {
                        & $add 'CODE_AROUND_CLOSE_BRACE' "Codigo depois de '}'; continue na linha seguinte."
                    }
                }
            }
        }

        foreach ($open in $stack) {
            $before = $code.Substring(0, $open).Trim()
            $after = $code.Substring($open + 1).Trim()

            if ($after.Length -gt 0) {
                & $add 'CODE_AFTER_OPEN_BRACE' "Codigo depois de '{'; o conteudo do bloco vai nas linhas seguintes."
            }
            elseif ($before.Length -gt 0 -and -not $kAndR) {
                & $add 'BRACE_END_OF_LINE' "'{' no fim da linha; no estilo Allman ela fica sozinha na linha de baixo."
            }
        }

        # Mais de uma instrucao: conta ';' fora de parenteses/colchetes, ignorando '{ get; set; }'.
        $flat = [regex]::Replace($code, '\{[^{}]*\}', {
            param($m)
            if ($m.Value.Substring(1) -match $script:AccessorPattern) { '{}' } else { $m.Value }
        })
        $depth = 0
        $semicolons = 0

        foreach ($ch in $flat.ToCharArray()) {
            if ($ch -eq '(' -or $ch -eq '[') { $depth++ }
            elseif ($ch -eq ')' -or $ch -eq ']') { $depth-- }
            elseif ($ch -eq ';' -and $depth -le 0) { $semicolons++ }
        }

        if ($semicolons -gt 1) { & $add 'MULTI_STATEMENT' 'Mais de uma instrucao na mesma linha.' }

        # Corpo na mesma linha do if/for/while/else.
        if ($ct -cmatch '^(else\s+)?(if|while|for|foreach|lock|using|fixed)\s*\(') {
            $openParen = $ct.IndexOf('(')
            $level = 0
            $close = -1

            for ($i = $openParen; $i -lt $ct.Length; $i++) {
                if ($ct[$i] -eq '(') { $level++ }
                elseif ($ct[$i] -eq ')') {
                    $level--

                    if ($level -eq 0) { $close = $i; break }
                }
            }

            if ($close -ge 0) {
                $rest = $ct.Substring($close + 1).Trim()

                if ($rest.Length -gt 0 -and $rest -ne ';' -and -not $rest.StartsWith('{')) {
                    & $add 'SAME_LINE_BODY' 'Corpo na mesma linha da condicao; mova para a linha de baixo.'
                }
            }
        }
        elseif ($ct -cmatch '^else\s+(?!if\b)[^\s{]') {
            & $add 'SAME_LINE_BODY' "Corpo na mesma linha do 'else'; mova para a linha de baixo."
        }
    }

    return $violations
}

function Invoke-CsScan {
    param([string[]]$Paths, [int]$MaxLength, [switch]$AsJson, [switch]$SummaryOnly)

    $files = @(Get-CsFiles $Paths)
    $all = New-Object 'System.Collections.Generic.List[object]'

    foreach ($file in $files) {
        foreach ($v in (Get-CsViolations -FilePath $file -MaxLength $MaxLength)) { $all.Add($v) }
    }

    $byRule = [ordered]@{}

    foreach ($group in ($all | Group-Object Rule | Sort-Object Count -Descending)) {
        $byRule[$group.Name] = $group.Count
    }

    $filesWithViolations = @($all | Select-Object -ExpandProperty File -Unique).Count

    if ($AsJson) {
        $report = [ordered]@{
            filesScanned        = $files.Count
            filesWithViolations = $filesWithViolations
            totalViolations     = $all.Count
            byRule              = $byRule
            violations          = @($all | ForEach-Object {
                [ordered]@{ file = $_.File; line = $_.Line; rule = $_.Rule; message = $_.Message; text = $_.Text }
            })
        }

        ConvertTo-Json -InputObject $report -Depth 4
    }
    else {
        if (-not $SummaryOnly) {
            foreach ($v in $all) {
                Write-Output ("{0}:{1}: [{2}] {3}" -f $v.File, $v.Line, $v.Rule, $v.Message)

                $snippet = $v.Text.Trim()

                if ($snippet.Length -gt 100) { $snippet = $snippet.Substring(0, 100) + '...' }

                Write-Output "    > $snippet"
            }

            Write-Output ''
        }

        Write-Output ("Arquivos analisados: {0} | com violacao: {1} | violacoes: {2}" -f `
            $files.Count, $filesWithViolations, $all.Count)

        foreach ($key in $byRule.Keys) { Write-Output ("  {0,-28} {1}" -f $key, $byRule[$key]) }
    }

    $script:ScanViolationCount = $all.Count
}

if ($MyInvocation.InvocationName -ne '.') {
    $script:ScanViolationCount = 0

    Invoke-CsScan -Paths $Path -MaxLength $MaxLength -AsJson:$Json -SummaryOnly:$Summary

    if ($script:ScanViolationCount -gt 0) { exit 1 }

    exit 0
}
