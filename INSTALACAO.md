# Instalação — CSharp Pro Formatter

Este arquivo é só para você (humano). Os agentes usam o `SKILL.md`.

## 1. Copiar a skill

O nome da pasta tem que ser exatamente `csharp-pro-formatter` (igual ao `name` do `SKILL.md`).

| Agente | Pasta de skills pessoais |
|---|---|
| Claude Code | `%USERPROFILE%\.claude\skills\csharp-pro-formatter\` |
| Codex | `%USERPROFILE%\.agents\skills\csharp-pro-formatter\` |

Para manter uma cópia só, deixe a pasta real no local do Codex e crie um junction para o Claude (não precisa de admin):

```bat
mklink /J "%USERPROFILE%\.claude\skills\csharp-pro-formatter" "%USERPROFILE%\.agents\skills\csharp-pro-formatter"
```

## 2. Regra global (faz o agente carregar a skill sempre)

A descrição da skill já pede uso obrigatório, mas a regra global reforça. Cole o bloco abaixo em
`%USERPROFILE%\.claude\CLAUDE.md` (Claude) e em `%USERPROFILE%\.codex\AGENTS.md` (Codex):

```markdown
## C# — formatação obrigatória
- Antes de escrever, gerar ou editar qualquer código C# (.cs), carregue e siga a skill `csharp-pro-formatter`.
- Código C# amontoado (instruções na mesma linha de `{`/`}`, blocos numa linha só, linhas acima de 120 colunas) é defeito.
- Feedback `[csharp-pro-formatter]` vindo de hook é obrigatório: corrija as linhas apontadas antes de continuar.
```

## 3. Hook (garantia determinística)

O hook roda depois de cada edição de `.cs`, analisa **só as linhas que o agente acabou de escrever** e, se houver
violação, devolve a lista ao agente para corrigir na hora. Ele nunca altera arquivos.

Troque `<SKILL>` pelo caminho real da pasta, com barras `/` (ex.: `C:/Users/SEU_USUARIO/.agents/skills/csharp-pro-formatter`).

### Claude Code — `%USERPROFILE%\.claude\settings.json`

Acrescente a chave `hooks` (mantendo o resto do arquivo):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<SKILL>/scripts/hook-cs.ps1\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Codex — `%USERPROFILE%\.codex\hooks.json`

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "apply_patch|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<SKILL>/scripts/hook-cs.ps1\"",
            "commandWindows": "powershell -NoProfile -ExecutionPolicy Bypass -File \"<SKILL>/scripts/hook-cs.ps1\"",
            "timeout": 30,
            "statusMessage": "Conferindo formatação C#"
          }
        ]
      }
    ]
  }
}
```

No Codex, hooks novos só rodam depois de aprovados: abra o Codex e aprove em `/hooks`.

## 4. Como usar

| Modo | Claude Code | Codex |
|---|---|---|
| Automático (ao escrever C#) | nada a fazer | nada a fazer |
| Varredura do repo inteiro | `/csharp-pro-formatter` | `$csharp-pro-formatter` |
| Varredura de uma pasta/arquivo | `/csharp-pro-formatter src\Modulo` | `$csharp-pro-formatter varra src\Modulo` |

## 5. Testar

```powershell
# Scanner direto em uma pasta
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL>\scripts\scan-cs.ps1" -Path "C:\caminho\do\projeto" -Summary

# Depois de uma varredura: prova de que só mudou formatação
powershell -NoProfile -ExecutionPolicy Bypass -File "<SKILL>\scripts\check-whitespace-only.ps1" -Repo "C:\caminho\do\projeto"
```

Depois de instalar, reinicie o agente. No Claude, `/csharp-pro-formatter` deve aparecer na lista. No Codex,
`/skills` deve listar `csharp-pro-formatter`.
