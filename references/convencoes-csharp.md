# Convenções C# para código novo

Aplique a código **novo** ou reescrito por pedido do usuário. Na varredura (Modo B) **nada daqui é aplicado** — ela é
só formatação. Convenções explícitas do projeto (`CLAUDE.md`/`AGENTS.md` do repo, `.editorconfig`, padrão dominante
do código existente) **vencem** as desta página.

## 1. Nomenclatura

| Elemento | Padrão | Exemplo |
|---|---|---|
| Namespace, classe, record, struct, enum, delegate | PascalCase | `MeuApp.Financeiro`, `ContratoService` |
| Interface | `I` + PascalCase | `IContratoRepository` |
| Método (inclusive função local) | PascalCase, começa com verbo | `CalcularMulta`, `ObterPorId` |
| Método assíncrono | sufixo `Async` | `SalvarAsync` |
| Propriedade, evento, constante, campo público | PascalCase | `ValorTotal`, `TaxaPadrao` |
| Parâmetro e variável local | camelCase | `idCliente`, `valorFinal` |
| Campo privado/interno | `_camelCase` | `_context`, `_logger` |
| Campo estático privado | `s_camelCase` (ou o padrão do projeto) | `s_cache` |
| Parâmetro de tipo genérico | `T` ou `T` + nome | `T`, `TEntidade` |
| Booleano | pergunta afirmativa | `EstaAtivo`, `PossuiContrato`, `PodeEditar` |
| Atributo / exceção | sufixos `Attribute` / `Exception` | `AuditavelAttribute`, `SaldoInsuficienteException` |
| Enum | singular; plural só em `[Flags]` | `EStatusContrato`, `Permissoes` |

Regras:
- Nomes descritivos e completos: sem abreviações obscuras, sem letras soltas (exceto `i`, `j`, `k` em laços e o
  parâmetro de lambda curta).
- Não repita o nome do tipo na propriedade: `Cliente.Nome`, não `Cliente.ClienteNome`.
- Evite nomes genéricos sem significado: `Manager`, `Helper`, `Utils`, `Data`, `Info`, `Processar2`.
- Nunca dois sublinhados seguidos, nunca nomes que diferem só por maiúsculas.
- Constantes em PascalCase (padrão Microsoft), não `TODO_MAIUSCULO` — a não ser que o projeto já use outro padrão.
- Use `nameof(...)` em vez de strings com nomes de membros.

## 2. Linguagem

- Palavras-chave de tipo: `string`, `int`, `bool`, `decimal`, inclusive em chamadas (`int.Parse`, `string.Empty`).
- `var` só quando o tipo é óbvio pelo lado direito (`new`, cast, literal) ou é um tipo anônimo/LINQ. Caso contrário,
  tipo explícito. Não deduza o tipo pelo nome do método.
- `new()` com tipo alvo quando o tipo já aparece à esquerda: `List<Cliente> clientes = new();`.
- Expressões de coleção (`[1, 2, 3]`) e `required` quando a versão do C# do projeto permitir.
- Interpolação (`$"..."`) em vez de concatenação; `StringBuilder` em laços; raw string `"""` para SQL/JSON.
- `using var` em vez de `try/finally` com `Dispose`.
- `&&` e `||` (curto-circuito), nunca `&` e `|` em condições.
- Membros estáticos chamados pelo nome do tipo que os declara.
- `readonly` em campos atribuídos só no construtor; `sealed` em classes que não foram feitas para herança;
  `static` em classes sem estado.
- Visibilidade sempre explícita, como primeiro modificador
  (`public`, `private`, `protected`, `internal`, `static`, `readonly`, `async`...).
- Evite `this.` quando não for necessário.
- Sem números mágicos: constantes ou enums com nome.

## 3. Exceções

- Capture só o que você sabe tratar, com tipo específico. `catch (Exception)` apenas na borda (middleware, job) para
  logar e responder.
- Relance com `throw;` (preserva a stack trace), nunca `throw ex;`.
- Não use exceção para controle de fluxo esperado; prefira retorno (`Result`, `bool TryXxx(out ...)`).
- Mensagens claras e com contexto (`$"Contrato {id} não encontrado."`).
- Validação de argumento: `ArgumentNullException.ThrowIfNull(x)`, `ArgumentException.ThrowIfNullOrWhiteSpace(x)`.

## 4. Async

- `async`/`await` de ponta a ponta para E/S; nunca `.Result`, `.Wait()` ou `GetAwaiter().GetResult()` em código
  assíncrono.
- Nunca `async void` (exceto handlers de evento de UI).
- Propague `CancellationToken` até a última chamada de E/S.
- `ConfigureAwait(false)` em bibliotecas, se o projeto já adota.

## 5. Métodos e classes limpos

- Uma responsabilidade por método e por classe; método que não cabe na tela é candidato a extração.
- Poucos parâmetros (até ~4); mais que isso → objeto de parâmetro/request.
- Evite parâmetro `bool` que muda o comportamento do método — prefira dois métodos com nomes claros ou um enum.
- Retorno antecipado (guard clauses) em vez de `if` aninhado em vários níveis.
- DRY sem exagero, KISS, YAGNI: não crie abstração "para o futuro".
- Sem código morto nem código comentado em código novo.
- Prefira composição a herança profunda.
- Dependências por injeção via construtor; não instancie serviços com `new` dentro de serviços.

## 6. Clean Architecture e EF Core

- **Domain** não depende de framework (nada de EF Core, ASP.NET ou atributos de infraestrutura nas entidades).
- `DbContext`, mapeamentos (`IEntityTypeConfiguration<T>`), migrations e interceptors ficam na **Infrastructure**.
- Consultas de leitura: `AsNoTracking()` + projeção com `Select` direto para DTO; não carregue a entidade inteira
  para devolver três campos.
- Não crie repositório que só repassa para o `DbSet` nem `IUnitOfWork` sobre o `DbContext` se o projeto não usa esse
  padrão — `SaveChangesAsync` já é a unidade de trabalho.
- Reaproveite filtros com métodos de extensão de `IQueryable<T>` ou Specification.
- SQL manual sempre parametrizado; nunca concatene entrada do usuário.
- Em base multi-tenant, todo filtro respeita a empresa/filial do contexto.

## 7. Comentários e documentação

- Comentário explica **por que**, não **o que**. Código claro dispensa comentário óbvio.
- `///` em APIs públicas de bibliotecas compartilhadas.
- `// TODO:` só com contexto (o que falta e por quê).
- Evite `#region` para esconder classe grande — divida a classe.
