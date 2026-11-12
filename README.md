# CSharp Pro Formatter

Skill para agentes de código (**Claude Code** e **OpenAI Codex**) que obriga o agente a escrever C# limpo, arejado e
bem formatado — e que varre um projeto inteiro corrigindo a formatação sem mudar lógica nem nomes.

Código amontoado é tratado como **defeito**, não como estilo:

```csharp
// Antes: o que o agente costuma entregar
var produto = await repositorio.ObterProdutoAsync(id, cancellationToken);
if (produto is null) return null;
if (precoAlterado) { Notificar("Preco", MensagensProduto.PrecoAlterado); return null; }
await repositorio.RegistrarHistoricoAsync(produto, cancellationToken);

// Depois: o que a skill garante
var produto = await repositorio.ObterProdutoAsync(id, cancellationToken);

if (produto is null)
    return null;

if (precoAlterado)
{
    Notificar("Preco", MensagensProduto.PrecoAlterado);
    return null;
}

await repositorio.RegistrarHistoricoAsync(produto, cancellationToken);
```

## O que a skill impõe

- **4 espaços** de indentação, nunca tab.
- **Chaves Allman**: `{` e `}` sozinhas na linha; `else`, `catch` e `finally` na linha seguinte.
- **Uma instrução por linha**: nada de bloco numa linha só nem corpo de `if` na mesma linha da condição.
- **Limite de 120 colunas** (ou o `max_line_length` do `.editorconfig`), com quebras naturais: antes de `&&`/`||`,
  um `.Metodo()` por linha em LINQ e parâmetros agrupados em linhas de continuação, sem um por linha por padrão.
- **Blocos nunca colados**: linha em branco antes de `if/for/foreach/while/switch/try/using` e depois de `}` ou do
  corpo sem chaves.
- Espaçamento correto (`if (x)`, `a + b`, `f(a, b)`), sem espaço no fim da linha e sem linhas em branco duplicadas.
- Convenções do projeto (`.editorconfig`, `CLAUDE.md`/`AGENTS.md`, padrão do código existente) vencem as da skill em
  nomenclatura e estrutura.

As regras completas estão em [`SKILL.md`](SKILL.md) e no catálogo de casos em
[`references/formatacao-detalhada.md`](references/formatacao-detalhada.md).

## Como funciona

| Modo | Quando | O que acontece |
|---|---|---|
| **A — Escrita** | Automático, sempre que o agente escreve ou edita C# | Escreve já formatado, roda o scanner nos arquivos tocados e corrige só as linhas que escreveu. |
| **B — Varredura** | Manual: `/csharp-pro-formatter` (Claude) ou `$csharp-pro-formatter` (Codex) | Percorre o repositório (ou a pasta indicada) arquivo por arquivo, com ledger para retomar, até zerar as violações. Prova no fim que só mudou formatação. |

Além da skill, há um **hook `PostToolUse`** que roda depois de cada edição de `.cs`, analisa apenas as linhas que o
agente acabou de escrever e devolve as violações para ele corrigir na hora. É a garantia determinística: o agente não
consegue "esquecer" a regra.

## Estrutura

```
csharp-pro-formatter/
├── SKILL.md                      # instruções da skill (lidas pelo agente)
├── INSTALACAO.md                 # passo a passo de instalação para humanos
├── agents/openai.yaml            # metadados para o Codex
├── references/
│   ├── formatacao-detalhada.md   # catálogo de casos: ruim x bom
│   ├── convencoes-csharp.md      # convenções para código novo
│   └── editorconfig-modelo.md    # .editorconfig sugerido
└── scripts/                      # PowerShell 5.1+, todos read-only
    ├── scan-cs.ps1               # scanner de violações de layout
    ├── hook-cs.ps1               # hook PostToolUse (Claude Code e Codex)
    └── check-whitespace-only.ps1 # prova que um diff só mudou espaços/quebras
```

## Instalação rápida

```bat
git clone https://github.com/lucas-corcovia/csharp-pro-formatter.git "%USERPROFILE%\.agents\skills\csharp-pro-formatter"
mklink /J "%USERPROFILE%\.claude\skills\csharp-pro-formatter" "%USERPROFILE%\.agents\skills\csharp-pro-formatter"
```

Depois configure o hook e a regra global seguindo o [`INSTALACAO.md`](INSTALACAO.md) e reinicie o agente.

## Scanner

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\scan-cs.ps1 -Path .\src -Summary
```

Lista violações no formato `arquivo:linha [REGRA]` e sai com código 1 se houver alguma. Aceita `-Json` (para
baseline) e `-MaxLength N`. Ignora `bin/`, `obj/`, `Migrations/`, arquivos gerados e o conteúdo de strings e
comentários.

Regras: `LONG`, `CODE_AFTER_OPEN_BRACE`, `CODE_AROUND_CLOSE_BRACE`, `BRACE_END_OF_LINE`, `MULTI_STATEMENT`,
`SAME_LINE_BODY`, `KEYWORD_SPACE`, `SPACE_AFTER_COMMA`, `DOUBLE_BLANK`, `BLANK_AFTER_OPEN_BRACE`,
`BLANK_BEFORE_CLOSE_BRACE`, `MISSING_BLANK_BEFORE_BLOCK`, `MISSING_BLANK_AFTER_BLOCK`, `INDENT`, `TAB`, `TRAILING_WS`.

## Requisitos

- Windows com PowerShell 5.1 ou superior.
- Claude Code e/ou OpenAI Codex com suporte a skills.
- Opcional: .NET SDK, para o passo mecânico com `dotnet format whitespace` na varredura.
