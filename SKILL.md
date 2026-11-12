---
name: csharp-pro-formatter
description: OBRIGATÓRIA para qualquer código C#. Use SEMPRE, sem exceção, antes de escrever, gerar, editar, refatorar, corrigir ou revisar arquivos .cs ou trechos de C#/.NET (classes, métodos, controllers, services, handlers, testes, LINQ, EF Core), mesmo quando o pedido não fala em formatação. Define o padrão de layout obrigatório - indentação de 4 espaços, chaves no estilo Allman, uma instrução por linha, quebra de linha acima de 120 colunas, espaçamento e linhas em branco corretos, código limpo sem instruções amontoadas na mesma linha. Use também quando o usuário pedir para formatar, indentar, organizar, limpar, padronizar ou varrer o código C# do projeto - nesse modo varredura o agente percorre todas as classes do projeto e corrige a formatação sem mudar lógica nem nomes.
---

# CSharp Pro Formatter

Você escreve C# como um engenheiro sênior .NET que segue as convenções da Microsoft: código **arejado, indentado,
uma ideia por linha**, fácil de ler e de manter. Código amontoado é **defeito**, não estilo.

`<skill>` = a pasta onde este `SKILL.md` está. Os scripts ficam em `<skill>/scripts/` (PowerShell 5.1+, read-only).

## 0. Qual modo usar

| Situação | Modo |
|---|---|
| Você vai escrever ou editar C# por qualquer motivo (feature, bug, teste, refatoração, exemplo na resposta) | **A — Escrita** |
| O usuário invocou a skill diretamente (`/csharp-pro-formatter`, `$csharp-pro-formatter`) ou pediu para formatar/indentar/varrer o projeto, uma pasta ou um arquivo | **B — Varredura** |

Argumento opcional da invocação manual = pasta ou arquivo a varrer. Sem argumento: raiz do repositório atual.

## 1. Contrato inegociável

1. **Todo** código C# que você produz segue as regras da seção 2 — em arquivos e também em blocos de código na resposta.
2. Você **não entrega** trabalho em C# sem passar pela checklist da seção 6 e rodar o scanner nos arquivos tocados.
3. Feedback do hook `[csharp-pro-formatter]` ou violação do scanner **é corrigido na hora**, antes de qualquer outra
   coisa. Não justifique, não adie, não peça permissão para corrigir layout.
4. Formatação **nunca** muda comportamento: não renomeia, não reordena, não altera lógica, strings ou comentários.
5. Na dúvida entre "compacto" e "legível", escolha legível.

## 2. Regras de layout (obrigatórias)

### 2.1 Indentação e chaves
- **4 espaços** por nível. Nunca tab.
- **Estilo Allman**: `{` e `}` sempre **sozinhas na própria linha**, alinhadas com a instrução dona do bloco — vale para
  namespace, tipo, método, propriedade com corpo, `if/else`, `for/foreach/while/do`, `switch`, `try/catch/finally`,
  `using`, `lock`, lambdas de várias linhas e inicializadores de várias linhas.
- `else`, `else if`, `catch` e `finally` começam **na linha seguinte** ao `}`.
- Exceções permitidas numa linha só: auto-propriedade (`public int Id { get; set; }`), accessor curto
  (`{ get => _x; }`), bloco vazio `{ }` e inicializador curto **sem `;`** que caiba em 120 colunas
  (`new[] { 1, 2, 3 }`, `new Pessoa { Nome = nome }`).
- Conteúdo de `case` indentado um nível abaixo do `case`; `case` indentado um nível abaixo do `switch`.

### 2.2 Uma instrução por linha
- Nunca duas instruções na mesma linha (`a = 1; b = 2;`).
- Nunca código depois de `{` (`if (x) { Faz();`) nem antes/depois de `}` (`return x;}`, `}return y;`, `} else`).
- Nunca bloco inteiro numa linha (`catch (Exception) { return false; }`).
- Corpo de `if/else/for/foreach/while` **nunca** na mesma linha da condição (`if (x) return;` é proibido).
- Sem chaves só é aceito quando o corpo é **uma** instrução simples, **na linha de baixo e indentada**:

```csharp
if (cliente is null)
    return NotFound();
```

  Se qualquer ramo do `if/else` tiver chaves ou mais de uma linha, todos os ramos usam chaves.
- Uma declaração por linha (`int a = 1, b = 2;` → duas linhas).

### 2.3 Limite de 120 colunas e como quebrar
Passou de **120 colunas** (ou do `max_line_length` do `.editorconfig` do projeto), quebre. Linha de continuação recebe
**+4 espaços** em relação à linha que a iniciou. Escolha a quebra mais natural, nesta ordem:

1. **Condições longas** → quebre **antes** de `&&`, `||`, `??`, `?:`; um critério por linha.

```csharp
if (pedido.DataCriacao >= DateTime.Today.AddDays(-30)
    && pedido.IdCliente == cupom.IdCliente
    && pedido.Canal == cupom.Canal)
    return true;
```

2. **Cadeias fluentes / LINQ** → um `.Metodo()` por linha, ponto no início, +4 espaços.

```csharp
var ativos = await _context.Clientes
    .AsNoTracking()
    .Where(c => c.Ativo && c.IdFilial == idFilial)
    .OrderBy(c => c.Nome)
    .Select(c => new ClienteDto(c.Id, c.Nome))
    .ToListAsync(cancellationToken);
```

3. **Parâmetros ou argumentos** → mantenha na mesma linha quando couber. Se passar de 120 colunas, quebre em grupos
   naturais com vários parâmetros ou argumentos por linha; não coloque um por linha por padrão. Mantenha `(` na linha
   do nome e `)` junto ao último grupo.

```csharp
public async Task<Result<ContratoDto>> RenovarContratoAsync(int idContrato, DateTime dataRenovacao,
    bool manterDesconto, CancellationToken cancellationToken)
{
```

4. **Inicializadores** (objeto, coleção, anônimo) → um membro por linha, chaves Allman, vírgula no fim de cada linha.
5. **Ternário longo** → `?` e `:` no início das linhas de continuação.
6. **Strings longas** → extraia partes para variáveis, use interpolação ou raw string `"""`. Não concatene 5 `+` numa
   linha.
7. **Expressões aninhadas** (chamada dentro de chamada) → extraia para variáveis locais com nomes claros.
8. Atributos: um por linha, acima do membro (`[HttpGet]` / `[Authorize]` em linhas separadas).
9. Restrições genéricas longas: `where T : class` na linha de baixo, +4 espaços.

Detalhes e mais casos (switch expression, pattern matching, records, lambdas, `using`): leia
[references/formatacao-detalhada.md](references/formatacao-detalhada.md).

### 2.4 Linhas em branco — blocos nunca colados
Bloco colado em outro é defeito, igual a duas instruções na mesma linha. Obrigatório (o scanner acusa):

- **Antes** de todo `if`, `for`, `foreach`, `while`, `do`, `switch`, `try`, `using (...)`, `lock` que venha depois de
  outra instrução → uma linha em branco (`MISSING_BLANK_BEFORE_BLOCK`). Vale também para `if` de guarda seguidos:
  cada `if (...) return ...;` fica separado do próximo.
- **Depois** do fim de um bloco — o `}` ou a linha do corpo sem chaves de `if/else/for/foreach/while` — uma linha em
  branco antes da próxima instrução (`MISSING_BLANK_AFTER_BLOCK`).
- Exceções (continuam coladas): o primeiro item logo após `{`; `else`, `else if`, `catch`, `finally` e o `while (...);`
  do `do`; `}` seguido de outro `}`, `)`, `,`, `;` ou `.`; `using (...)` empilhados; accessors `get`/`set`/`init`.
- Comentário pertence ao código de baixo: a linha em branco vai **acima** do comentário.

Ruim (proibido):

```csharp
var produto = await repositorio.ObterProdutoAsync(id, cancellationToken);
if (produto is null)
    return null;
if (!Validar(request))
    return null;
var precoAlterado = produto.Preco != request.Preco;
if (precoAlterado)
{
    Notificar("Preco", MensagensProduto.PrecoAlterado);
}
await repositorio.RegistrarHistoricoAsync(produto, cancellationToken);
```

Bom (padrão obrigatório):

```csharp
var produto = await repositorio.ObterProdutoAsync(id, cancellationToken);

if (produto is null)
    return null;

if (!Validar(request))
    return null;

var precoAlterado = produto.Preco != request.Preco;

if (precoAlterado)
{
    Notificar("Preco", MensagensProduto.PrecoAlterado);
}

await repositorio.RegistrarHistoricoAsync(produto, cancellationToken);
```

Além disso:
- **Uma** linha em branco entre membros (campos de um mesmo grupo podem ficar juntos). Entre métodos, ela é
  obrigatória mesmo quando o próximo método começa com atributos: a linha em branco fica antes do primeiro atributo.
  Atributos continuam colados ao método que decoram.
- Exemplo — mantenha a separação entre os métodos e agrupe os parâmetros em vez de pôr um em cada linha:

```csharp
[HttpGet("movements")]
[OrganizationPermission(Permissions.ViewFinancial)]
public async Task<IActionResult> Movements(Guid organizationId, [FromQuery] FinancialQuery query,
    CancellationToken cancellationToken) =>
    CustomResponse(await financial.MovementsAsync(organizationId, query, cancellationToken));

[HttpGet("audits")]
[OrganizationPermission(Permissions.ViewFinancial)]
public async Task<IActionResult> Audits(Guid organizationId, [FromQuery] FinancialQuery query,
    CancellationToken cancellationToken) =>
    CustomResponse(await financial.AuditsAsync(organizationId, query, cancellationToken));
```

- **Não** separe instruções simples que fazem parte do mesmo grupo lógico só para inserir linhas em branco.
- **Uma** linha em branco separando grupos lógicos de instruções simples dentro do método: declarações → validação →
  ação → retorno.
- **Nunca** duas linhas em branco seguidas.
- **Nunca** linha em branco logo depois de `{` ou logo antes de `}`.
- Uma linha em branco entre o bloco de `using` e o `namespace`, e entre `namespace X;` e o tipo.

### 2.5 Espaçamento
- Espaço depois de `if`, `for`, `foreach`, `while`, `switch`, `catch`, `using`, `lock`: `if (x)`, nunca `if(x)`.
- Espaço dos dois lados de operadores binários e de atribuição: `a + b`, `x = y`, `a => b`, `x ?? y`.
- Espaço depois de vírgula e de `;` no `for`; nunca antes.
- Sem espaço: dentro de parênteses `( x )`, antes de `(` em chamada `Metodo (x)`, depois de cast `(int) x`,
  antes de `;`, entre `!` e o operando.
- `:` de herança com espaço dos dois lados: `class Cliente : Entidade, IAuditavel`.
- Sem espaços no fim da linha. Arquivo termina com uma quebra de linha.

### 2.6 Comentários
- Comentário `//` na própria linha, acima do código, com um espaço depois de `//`. Não ponha comentário no fim de
  linha de código.
- Prefira código autoexplicativo a comentário que repete o código. Comentário explica o **porquê**.
- `///` XML em membros públicos de APIs/bibliotecas.
- Em código existente, **não** reescreva texto de comentários nem apague código comentado: só alinhe a indentação.

### 2.7 Precedência
Convenções explícitas do projeto vencem as desta skill em **nomenclatura e estrutura**: `CLAUDE.md`/`AGENTS.md` do
repositório, `.editorconfig`, regras de analisadores e o padrão dominante do arquivo (ex.: se métodos privados do
projeto usam `_ValidarCupom`, mantenha). As regras de **layout** desta skill (seção 2) valem sempre que o projeto não
disser o contrário — o scanner lê `max_line_length` e `csharp_new_line_before_open_brace` do `.editorconfig`.

Para código **novo**, aplique também [references/convencoes-csharp.md](references/convencoes-csharp.md)
(nomenclatura, `var`, exceções, async, LINQ/EF Core, código limpo).

## 3. Exemplo de referência

Ruim (proibido):

```csharp
private static bool _ValidarCupom(bool promocaoAtiva, string codigo, int idCliente, string canal)
{
    if (promocaoAtiva) { CultureInfo.CurrentCulture = new CultureInfo("pt-BR");
        try {
            var cupom = CupomRepositorio.Obter(codigo);
            var regras = cupom.Regras.Split(";");
            if (Convert.ToDateTime(regras[0]) >= DateTime.Today.AddDays(-30)
                && idCliente == int.Parse(regras[1])
                && canal == regras[2])
                return true;}
        catch (FormatException){return false;}
    }return false;
}
```

Bom (padrão obrigatório):

```csharp
private static bool _ValidarCupom(bool promocaoAtiva, string codigo, int idCliente, string canal)
{
    if (promocaoAtiva)
    {
        CultureInfo.CurrentCulture = new CultureInfo("pt-BR");

        try
        {
            var cupom = CupomRepositorio.Obter(codigo);
            var regras = cupom.Regras.Split(";");

            if (Convert.ToDateTime(regras[0]) >= DateTime.Today.AddDays(-30)
                && idCliente == int.Parse(regras[1])
                && canal == regras[2])
                return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    return false;
}
```

## 4. Modo A — Escrita (automático)

1. **Antes de escrever**: olhe o `.editorconfig` do repositório (se houver) e um ou dois arquivos vizinhos para pegar
   as convenções do projeto (namespace com bloco ou file-scoped, prefixos, idioma dos nomes).
2. **Escreva já formatado** seguindo a seção 2. Não existe "formatar depois".
3. **Ao terminar cada arquivo**, rode o scanner nos arquivos que você criou ou alterou:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\scan-cs.ps1" -Path "caminho\Arquivo1.cs" "caminho\Arquivo2.cs"
```

4. Corrija **todas as violações nas linhas que você escreveu ou alterou** e rode de novo até zerar nelas.
   Violações em linhas antigas que você não tocou **não** são corrigidas numa tarefa de feature/bug (evita diff
   poluído e PR com ruído); se forem muitas, sugira ao usuário rodar o Modo B em separado.
5. Passe pela checklist da seção 6 antes de responder.

## 5. Modo B — Varredura do projeto (manual)

Objetivo: **todas** as classes do escopo formatadas, **sem nenhuma mudança além de layout**, sem retrabalho.

**Proibido na varredura**: renomear qualquer coisa; reordenar membros ou `using`; adicionar/remover `using`; trocar
`var`/tipos; converter namespace para file-scoped (ou o contrário); adicionar/remover chaves de `if` que já estão
corretas; alterar strings, comentários ou lógica; tocar em arquivos gerados.

### Passo 1 — Pré-checagem
- `git status --porcelain`: se houver alterações não commitadas, avise o usuário e pergunte se continua (a varredura
  deve gerar um diff separado e revisável). Sugira uma branch própria, ex.: `chore/formatacao-csharp`.
- Não faça commit, push nem PR sem o usuário pedir.

### Passo 2 — Inventário e baseline
- Escopo: o argumento recebido ou a raiz do repo. O scanner já exclui `bin/`, `obj/`, `Migrations/`, `.git/`,
  `*.Designer.cs`, `*.g.cs`, `*.generated.cs`, `AssemblyInfo.cs` e arquivos com `<auto-generated>`.
- Rode o baseline:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\scan-cs.ps1" -Path "<escopo>" -Summary
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\scan-cs.ps1" -Path "<escopo>" -Json > "$env:TEMP\csharp-pro-formatter\<repo>-baseline.json"
```

- Crie (ou **retome, se já existir**) o ledger `$env:TEMP\csharp-pro-formatter\<repo>-ledger.md` com uma linha por
  arquivo com violação: `- [ ] caminho\Arquivo.cs (N violações)`. É ele que impede retrabalho quando a sessão cai ou
  o contexto é compactado: arquivos marcados `[x]` não são reabertos.
- Mostre ao usuário o resumo do baseline (arquivos, violações por regra) e siga.

### Passo 3 — Passo mecânico
Se o .NET SDK estiver disponível, rode o formatador oficial no escopo (respeita o `.editorconfig`, não compila):

```powershell
dotnet format whitespace "<escopo>" --folder
```

Ele corrige indentação, chaves Allman, `else/catch` em linha nova e espaçamento. Ele **não** quebra linhas longas, não
abre blocos de uma linha (`catch (Exception) { return false; }`) e não separa grupos lógicos — isso é com você.
Sem SDK, pule para o Passo 4 e faça tudo manualmente.

### Passo 4 — Passo manual, arquivo por arquivo
Para cada arquivo pendente no ledger, em lotes de até ~20 arquivos:
1. Rode o scanner **no arquivo** e abra-o.
2. Corrija **todas** as violações apontadas e, ao ler o arquivo, também o que o scanner não detecta: linhas em
   branco entre membros e grupos lógicos (2.4), quebras naturais (2.3), alinhamento de continuação.
3. Rode o scanner de novo no arquivo até **zero**.
4. Marque `[x]` no ledger. Só então vá ao próximo.
Ao fim de cada lote, informe o progresso em uma linha (ex.: `lote 3/12 — 60/240 arquivos`).

### Passo 5 — Critério de conclusão (não encerre antes)
1. Scanner no escopo inteiro com **0 violações**. Falso positivo legítimo (ex.: URL ou string literal que não pode ser
   quebrada) é aceito **somente** se listado no relatório com arquivo:linha e motivo.
2. Prova de que só houve formatação:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\check-whitespace-only.ps1" -Repo "<raiz-do-repo>"
```

   Tem que sair com **0 arquivos com mudança além de formatação**. Se algum aparecer, desfaça a mudança indevida
   naquele arquivo (`git diff` nele) e refaça só o layout.
3. Se houver `.sln`/`.csproj`, rode `dotnet build` e confirme que continua compilando como antes.

### Passo 6 — Relatório final
- Escopo, arquivos analisados, arquivos alterados.
- Violações antes → depois, por regra.
- Falsos positivos mantidos (arquivo:linha e motivo).
- Resultado do `check-whitespace-only.ps1` e do build.
- Próximo passo sugerido (ex.: revisar o diff e commitar em um PR só de formatação).

## 6. Checklist final (toda entrega com C#)

- [ ] 4 espaços, sem tab; chaves Allman; `else/catch/finally` em linha nova.
- [ ] Uma instrução por linha; nada depois de `{` nem antes/depois de `}`; nenhum bloco numa linha só.
- [ ] Nenhum corpo de `if/for/while/else` na mesma linha da condição.
- [ ] Nenhuma linha acima de 120 colunas; quebras antes de `&&`/`||`, um `.Metodo()` por linha e parâmetros agrupados
      em quebras naturais, sem um por linha por padrão.
- [ ] Nenhum bloco colado: linha em branco antes de `if/for/foreach/while/switch/try/using` e depois de `}` ou do
  corpo sem chaves (`var` colado em `if` ou `}` colado em `await` é defeito).
- [ ] Linha em branco entre membros e entre grupos lógicos; nunca duas seguidas; nenhuma após `{` ou antes de `}`.
- [ ] Espaçamento correto (`if (x)`, `a + b`, `f(a, b)`), sem espaços no fim da linha.
- [ ] Convenções do projeto respeitadas; nada renomeado nem com lógica alterada por causa de formatação.
- [ ] `scan-cs.ps1` rodado nos arquivos tocados, sem violações nas linhas escritas.

## 7. Scripts

| Script | Uso |
|---|---|
| `scripts/scan-cs.ps1 -Path <arquivos/pastas> [-Summary] [-Json] [-MaxLength N]` | Lista violações `arquivo:linha [REGRA]`. Exit 1 se houver. |
| `scripts/check-whitespace-only.ps1 -Repo <raiz> [-Base HEAD]` | Prova que os `.cs` alterados só mudaram espaços/quebras. |
| `scripts/hook-cs.ps1` | Hook PostToolUse (Claude/Codex): acusa só as linhas que o agente acabou de escrever. |

Regras do scanner: `LONG`, `CODE_AFTER_OPEN_BRACE`, `CODE_AROUND_CLOSE_BRACE`, `BRACE_END_OF_LINE`, `MULTI_STATEMENT`,
`SAME_LINE_BODY`, `KEYWORD_SPACE`, `SPACE_AFTER_COMMA`, `DOUBLE_BLANK`, `BLANK_AFTER_OPEN_BRACE`,
`BLANK_BEFORE_CLOSE_BRACE`, `MISSING_BLANK_BEFORE_BLOCK`, `MISSING_BLANK_AFTER_BLOCK`, `INDENT`, `TAB`, `TRAILING_WS`.

Sugestão de `.editorconfig` para o usuário adotar no repositório (só sugira; não crie sem ele pedir):
[references/editorconfig-modelo.md](references/editorconfig-modelo.md).
