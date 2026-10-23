# Modelo de `.editorconfig` para C#

**Só sugira** este arquivo ao usuário. Nunca crie nem altere `.editorconfig` de um repositório sem pedido explícito —
ele muda o comportamento do IDE, do `dotnet format` e do build para o time inteiro.

Com ele na raiz do repositório:
- `dotnet format whitespace` passa a aplicar exatamente as regras de layout da skill;
- o scanner `scan-cs.ps1` lê o `max_line_length`;
- com `EnforceCodeStyleInBuild=true` no `.csproj`/`Directory.Build.props`, o `dotnet build` acusa `IDE0055`
  (formatação) e os demais estilos como warning/erro.

```ini
root = true

[*]
charset = utf-8
indent_style = space
indent_size = 4
insert_final_newline = true
trim_trailing_whitespace = true

[*.{json,yml,yaml,xml,csproj,props,targets}]
indent_size = 2

[*.cs]
max_line_length = 120

# Chaves e quebras de linha (Allman)
csharp_new_line_before_open_brace = all
csharp_new_line_before_else = true
csharp_new_line_before_catch = true
csharp_new_line_before_finally = true
csharp_new_line_before_members_in_object_initializers = true
csharp_new_line_before_members_in_anonymous_types = true
csharp_new_line_between_query_expression_clauses = true
csharp_preserve_single_line_statements = false
csharp_preserve_single_line_blocks = true

# Indentação
csharp_indent_block_contents = true
csharp_indent_braces = false
csharp_indent_case_contents = true
csharp_indent_case_contents_when_block = true
csharp_indent_switch_labels = true
csharp_indent_labels = one_less_than_current

# Espaçamento
csharp_space_after_cast = false
csharp_space_after_keywords_in_control_flow_statements = true
csharp_space_around_binary_operators = before_and_after
csharp_space_between_parentheses = false
csharp_space_after_comma = true
csharp_space_before_comma = false
csharp_space_after_semicolon_in_for_statement = true
csharp_space_before_colon_in_inheritance_clause = true
csharp_space_after_colon_in_inheritance_clause = true
csharp_space_between_method_call_parameter_list_parentheses = false
csharp_space_between_method_declaration_parameter_list_parentheses = false
csharp_space_around_declaration_statements = false

# Organização
dotnet_sort_system_directives_first = true
dotnet_separate_import_directive_groups = false
csharp_using_directive_placement = outside_namespace:warning
csharp_style_namespace_declarations = file_scoped:suggestion

# Estilo de código
csharp_prefer_braces = when_multiline:suggestion
csharp_prefer_simple_using_statement = true:suggestion
csharp_style_var_for_built_in_types = false:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = false:suggestion
dotnet_style_predefined_type_for_locals_parameters_members = true:warning
dotnet_style_predefined_type_for_member_access = true:warning
dotnet_style_qualification_for_field = false:suggestion
dotnet_style_qualification_for_property = false:suggestion
dotnet_style_qualification_for_method = false:suggestion
dotnet_style_readonly_field = true:warning
dotnet_style_require_accessibility_modifiers = always:warning
csharp_preferred_modifier_order = public,private,protected,internal,file,static,extern,new,virtual,abstract,sealed,override,readonly,unsafe,required,volatile,async:warning

# Nomenclatura
dotnet_naming_symbols.interfaces.applicable_kinds = interface
dotnet_naming_style.prefixo_i.required_prefix = I
dotnet_naming_style.prefixo_i.capitalization = pascal_case
dotnet_naming_rule.interfaces_com_i.symbols = interfaces
dotnet_naming_rule.interfaces_com_i.style = prefixo_i
dotnet_naming_rule.interfaces_com_i.severity = warning

dotnet_naming_symbols.campos_privados.applicable_kinds = field
dotnet_naming_symbols.campos_privados.applicable_accessibilities = private, protected, private_protected
dotnet_naming_style.sublinhado_camel.required_prefix = _
dotnet_naming_style.sublinhado_camel.capitalization = camel_case
dotnet_naming_rule.campos_privados_com_sublinhado.symbols = campos_privados
dotnet_naming_rule.campos_privados_com_sublinhado.style = sublinhado_camel
dotnet_naming_rule.campos_privados_com_sublinhado.severity = suggestion

dotnet_naming_symbols.constantes.applicable_kinds = field
dotnet_naming_symbols.constantes.required_modifiers = const
dotnet_naming_style.pascal.capitalization = pascal_case
dotnet_naming_rule.constantes_pascal.symbols = constantes
dotnet_naming_rule.constantes_pascal.style = pascal
dotnet_naming_rule.constantes_pascal.severity = suggestion

# Severidades que o build enxerga (precisa de EnforceCodeStyleInBuild=true)
dotnet_diagnostic.IDE0055.severity = warning
dotnet_diagnostic.IDE0040.severity = warning
dotnet_diagnostic.IDE1006.severity = suggestion

[**/{Migrations,obj,bin}/**.cs]
generated_code = true
dotnet_diagnostic.IDE0055.severity = none
```

Notas:
- `csharp_style_namespace_declarations = file_scoped` só como sugestão: em projeto legado com namespace em bloco, não
  force a conversão (gera diff gigante).
- A regra de campo privado com `_` está como `suggestion` porque projetos legados costumam ter outros padrões; suba a
  severidade só se o time concordar.
- `csharp_prefer_braces = when_multiline` aceita `if` sem chaves com uma instrução na linha de baixo, como a skill.
