# Formatação detalhada — catálogo de casos

Complementa a seção 2 do `SKILL.md`. Cada caso mostra o **ruim** (proibido) e o **bom** (obrigatório).
Regra geral de continuação: **+4 espaços** a partir da linha que iniciou a instrução.

## Sumário
1. Estrutura do arquivo
2. Assinaturas de método e construtores
3. Chamadas com muitos argumentos e chamadas aninhadas
4. LINQ — sintaxe de método e de consulta
5. Lambdas
6. Inicializadores de objeto, coleção e tipos anônimos
7. Condições, ternários e coalescência
8. `switch` (instrução e expressão) e pattern matching
9. `try/catch/finally` e `using`
10. Records, construtores primários e propriedades
11. Atributos e genéricos
12. Strings longas
13. Expression-bodied members
14. Linhas em branco dentro de métodos

---

## 1. Estrutura do arquivo

Ordem: `using` (System primeiro, depois os demais em ordem alfabética) → linha em branco → namespace → tipo.
Um tipo público por arquivo, com o nome do arquivo igual ao do tipo.

```csharp
using System.Text;
using Microsoft.EntityFrameworkCore;
using MeuApp.Domain.Clientes;

namespace MeuApp.Application.Clientes;

public sealed class ClienteService : IClienteService
{
    private readonly AppDbContext _context;
    private readonly ILogger<ClienteService> _logger;

    public ClienteService(AppDbContext context, ILogger<ClienteService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<ClienteDto?> ObterAsync(int id, CancellationToken cancellationToken)
    {
        ...
    }
}
```

Ordem sugerida de membros em código novo: constantes → campos estáticos → campos → construtores → propriedades →
métodos públicos → métodos privados. Em código existente, **não reordene**.

Se o projeto usa namespace com bloco (`namespace X { ... }`), mantenha o padrão do projeto.

## 2. Assinaturas de método e construtores

Cabe em 120 colunas → uma linha. Não cabe → **todos** os parâmetros um por linha.

Ruim:

```csharp
public async Task<Result<PagamentoDto>> RegistrarPagamentoAsync(int idVenda, decimal valor, EFormaPagamento formaPagamento,
    DateTime dataPagamento, CancellationToken cancellationToken)
```

Bom:

```csharp
public async Task<Result<PagamentoDto>> RegistrarPagamentoAsync(
    int idVenda,
    decimal valor,
    EFormaPagamento formaPagamento,
    DateTime dataPagamento,
    CancellationToken cancellationToken)
{
    ...
}
```

Construtor com chamada a `base`/`this` longa: `: base(...)` na linha de baixo, +4 espaços.

```csharp
public ClienteNaoEncontradoException(int idCliente)
    : base($"Cliente {idCliente} não encontrado.")
{
}
```

## 3. Chamadas com muitos argumentos e chamadas aninhadas

Ruim:

```csharp
var resultado = await _servicoFinanceiro.GerarCobrancaAsync(contrato.Id, contrato.IdCliente, CalcularValor(contrato.Plano, contrato.Desconto), DateTime.Today.AddDays(7), cancellationToken);
```

Bom — extraia o aninhado e quebre os argumentos:

```csharp
var valor = CalcularValor(contrato.Plano, contrato.Desconto);
var vencimento = DateTime.Today.AddDays(7);

var resultado = await _servicoFinanceiro.GerarCobrancaAsync(
    contrato.Id,
    contrato.IdCliente,
    valor,
    vencimento,
    cancellationToken);
```

Argumentos nomeados ajudam quando há booleanos ou literais: `Enviar(email, notificarGestor: true)`.

## 4. LINQ

### Sintaxe de método
Mais de uma chamada encadeada que não cabe na linha → um `.Metodo()` por linha, ponto no início.

Ruim:

```csharp
var nomes = clientes.Where(c => c.Ativo && c.IdFilial == idFilial && c.DataCadastro >= inicio).OrderBy(c => c.Nome).Select(c => c.Nome).ToList();
```

Bom:

```csharp
var nomes = clientes
    .Where(c => c.Ativo && c.IdFilial == idFilial && c.DataCadastro >= inicio)
    .OrderBy(c => c.Nome)
    .Select(c => c.Nome)
    .ToList();
```

Cadeia curta que cabe com folga pode ficar numa linha: `var total = itens.Sum(i => i.Valor);`.

### Sintaxe de consulta
Uma cláusula por linha, alinhadas sob o `from`.

```csharp
var vencidas = from parcela in parcelas
               where parcela.Vencimento < hoje && !parcela.Paga
               orderby parcela.Vencimento
               select parcela;
```

## 5. Lambdas

Lambda de uma expressão → sem chaves: `itens.ForEach(i => Processar(i));`.
Lambda com mais de uma instrução → chaves Allman, corpo indentado, fechamento `});` alinhado com a chamada.

Ruim:

```csharp
itens.ForEach(i => { Validar(i); Processar(i); });
```

Bom:

```csharp
itens.ForEach(i =>
{
    Validar(i);
    Processar(i);
});
```

Lambda com instrução única numa linha, como `() => { Faz(); }`, vira `() => Faz()`.

## 6. Inicializadores

Curto, sem `;` e cabendo em 120 colunas → uma linha. Senão → um membro por linha, chaves Allman, vírgula no fim.

```csharp
var endereco = new Endereco { Cidade = cidade, Uf = uf };

var cliente = new Cliente
{
    Nome = request.Nome,
    Email = request.Email,
    DataNascimento = request.DataNascimento,
    IdFilial = idFilial,
};

var mapa = new Dictionary<string, int>
{
    ["Ativo"] = 1,
    ["Inativo"] = 0,
};

int[] numeros = [1, 2, 3, 4];
```

Tipo anônimo na projeção:

```csharp
.Select(c => new
{
    c.Id,
    c.Nome,
    TotalCompras = c.Compras.Sum(x => x.Valor),
})
```

## 7. Condições, ternários e coalescência

Quebre **antes** do operador; cada critério numa linha; use parênteses para deixar a precedência clara.

```csharp
if ((cliente.Ativo && cliente.PossuiContrato)
    || usuario.EhAdministrador
    || configuracao.PermitirAcessoLivre)
{
    ...
}
```

Condição muito complexa → extraia para variável ou método com nome que explica a regra:

```csharp
var podeAcessar = cliente.Ativo && cliente.PossuiContrato;

if (podeAcessar || usuario.EhAdministrador)
{
    ...
}
```

Ternário longo:

```csharp
var mensagem = pagamento.Aprovado
    ? $"Pagamento {pagamento.Id} aprovado."
    : $"Pagamento {pagamento.Id} recusado: {pagamento.Motivo}.";
```

Ternário aninhado é proibido → use `if/else` ou `switch`.

Coalescência:

```csharp
var nome = request.NomeSocial
    ?? request.Nome
    ?? throw new ArgumentException("Nome obrigatório.", nameof(request));
```

## 8. `switch` e pattern matching

Instrução:

```csharp
switch (status)
{
    case EStatus.Ativo:
        Ativar();
        break;

    case EStatus.Bloqueado:
    case EStatus.Cancelado:
        Bloquear();
        break;

    default:
        throw new ArgumentOutOfRangeException(nameof(status), status, null);
}
```

Expressão — um braço por linha, chaves Allman, vírgula no fim:

```csharp
var taxa = formaPagamento switch
{
    EFormaPagamento.Pix => 0m,
    EFormaPagamento.Debito => 0.015m,
    EFormaPagamento.Credito when parcelas > 1 => 0.045m,
    EFormaPagamento.Credito => 0.03m,
    _ => throw new ArgumentOutOfRangeException(nameof(formaPagamento)),
};
```

Pattern matching longo: quebre antes de `and`/`or` como faria com `&&`/`||`.

```csharp
if (pessoa is { Ativo: true, Idade: >= 18 }
    and not { Documento: null })
{
    ...
}
```

## 9. `try/catch/finally` e `using`

Ruim:

```csharp
try { Executar(); } catch (TimeoutException ex) { _logger.LogWarning(ex, "Timeout"); } finally { Liberar(); }
```

Bom:

```csharp
try
{
    Executar();
}
catch (TimeoutException ex)
{
    _logger.LogWarning(ex, "Timeout ao executar.");
}
finally
{
    Liberar();
}
```

Em código novo prefira a declaração `using` (sem bloco):

```csharp
using var conexao = new SqlConnection(connectionString);
await conexao.OpenAsync(cancellationToken);
```

Filtro de exceção longo: `when (...)` na linha de baixo, +4 espaços.

## 10. Records, construtores primários e propriedades

```csharp
public sealed record ClienteDto(int Id, string Nome, string Email);

public sealed record ContratoResumoDto(
    int IdContrato,
    string NomeCliente,
    DateTime DataInicio,
    DateTime? DataFim,
    decimal ValorMensal);
```

Propriedades:

```csharp
public int Id { get; private set; }

public string Nome { get; set; } = string.Empty;

public bool EstaVencido => DataVencimento < DateTime.Today;

public decimal Saldo
{
    get => _saldo;
    private set
    {
        if (value < 0)
            throw new InvalidOperationException("Saldo não pode ser negativo.");

        _saldo = value;
    }
}
```

## 11. Atributos e genéricos

Um atributo por linha, acima do membro:

```csharp
[HttpPost("{id:int}/renovar")]
[Authorize(Policy = "Financeiro")]
[ProducesResponseType(typeof(ContratoDto), StatusCodes.Status200OK)]
public async Task<IActionResult> RenovarAsync(int id, CancellationToken cancellationToken)
```

Restrições genéricas:

```csharp
public sealed class Repositorio<TEntidade, TChave> : IRepositorio<TEntidade, TChave>
    where TEntidade : Entidade<TChave>
    where TChave : IEquatable<TChave>
{
}
```

## 12. Strings longas

Ruim:

```csharp
var texto = "Olá " + cliente.Nome + ", seu contrato " + contrato.Numero + " vence em " + contrato.Vencimento.ToString("dd/MM/yyyy") + ".";
```

Bom:

```csharp
var vencimento = contrato.Vencimento.ToString("dd/MM/yyyy");
var texto = $"Olá {cliente.Nome}, seu contrato {contrato.Numero} vence em {vencimento}.";
```

SQL ou texto de várias linhas → raw string (C# 11+) ou verbatim, alinhado:

```csharp
const string sql = """
    SELECT ID, NOME
      FROM CLIENTES
     WHERE ID_FILIAL = @IdFilial
    """;
```

Em laço, use `StringBuilder`. Nunca quebre uma string literal no meio só para caber: extraia partes.

## 13. Expression-bodied members

Use `=>` para membro de uma expressão curta. Se não couber, quebre depois do `=>`, +4 espaços:

```csharp
public override string ToString() => $"{Nome} ({Email})";

public decimal CalcularTotal() =>
    Itens.Sum(i => i.Quantidade * i.ValorUnitario) - Desconto;
```

Se precisar de mais de uma instrução, use corpo com chaves.

## 14. Linhas em branco dentro de métodos

Regra dura (seção 2.4 do `SKILL.md`, acusada pelo scanner): linha em branco **antes** de todo bloco
(`if`, `for`, `foreach`, `while`, `do`, `switch`, `try`, `using (...)`, `lock`) que venha depois de outra instrução e
**depois** do fim de todo bloco (`}` ou corpo sem chaves). Instrução colada em bloco nunca é aceita.

Ruim — `}` colado em `await`, corpo sem chaves colado no `if` seguinte, `if` colado no `if` anterior:

```csharp
if (produto is null)
{
    produto = new Produto(request);
    await repositorio.AdicionarAsync(produto, cancellationToken);
}
else
{
    produto.Atualizar(request);
    if (!produto.Categorias.Any(categoria => categoria.Id == request.IdCategoria))
    {
        var categoria = new ProdutoCategoria(produto, request.IdCategoria);
        produto.Categorias.Add(categoria);
    }
}
await repositorio.RegistrarHistoricoAsync(historico, cancellationToken);
if (await repositorio.SalvarAsync(cancellationToken))
    return ProdutoDto.De(produto);
Notificar(MensagensProduto.FalhaAoSalvar);
return null;
```

Bom:

```csharp
if (produto is null)
{
    produto = new Produto(request);
    await repositorio.AdicionarAsync(produto, cancellationToken);
}
else
{
    produto.Atualizar(request);

    if (!produto.Categorias.Any(categoria => categoria.Id == request.IdCategoria))
    {
        var categoria = new ProdutoCategoria(produto, request.IdCategoria);
        produto.Categorias.Add(categoria);
    }
}

await repositorio.RegistrarHistoricoAsync(historico, cancellationToken);

if (await repositorio.SalvarAsync(cancellationToken))
    return ProdutoDto.De(produto);

Notificar(MensagensProduto.FalhaAoSalvar);
return null;
```

Fora dos blocos, separe também os grupos lógicos de instruções simples com **uma** linha em branco:

```csharp
public async Task<Result> CancelarAsync(int idContrato, CancellationToken cancellationToken)
{
    var contrato = await _context.Contratos.FindAsync([idContrato], cancellationToken);

    if (contrato is null)
        return Result.Falha("Contrato não encontrado.");

    contrato.Cancelar(DateTime.UtcNow);
    _context.Contratos.Update(contrato);

    await _context.SaveChangesAsync(cancellationToken);

    return Result.Sucesso();
}
```
