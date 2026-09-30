# Changelog — schematize-shell

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [0.2.2] — 2026-09-30
O piso de orquestração passa a ser **herdado** da base em vez de copiado à mão: uma mudança na engineering não exige mais editar 38 arquivos.

### Alterado
- Piso "Orquestrador não desenvolve; subagent barato executa" em `assets/CLAUDE.md` e `SKILL.md` agora é um bloco `<!-- herdado:engineering/orquestracao:… -->`, sincronizado de `schematize-engineering/assets/herdados/orquestracao.md` por `tools/sync-herdados.mjs` (checado no CI). Redação normalizada; conteúdo inalterado.

### Mantido (piso inalterado)
- Sonnet por default, escada até opus, sem frota ociosa (engineering `references/orquestracao.md` §9/§9.6).

## [0.2.1] — 2026-09-30
Pedido do dono: agents idle poluem a tela e seguram recurso.

### Adicionado
- Piso de orquestração ganha a regra de frota ociosa (idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata); detalhe na `schematize-engineering` §9.6.

## [0.2.0] — 2026-09-30

Pedido do dono, por **custo**: o orquestrador não desenvolve; ação onerosa vira micro-tasks baratas; `sonnet` é o default dos subagents e `opus` só entra após falha.

### Adicionado
- **Piso "Orquestrador não desenvolve; subagent barato executa"** no `assets/CLAUDE.md` e no `SKILL.md`: o agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para subagents em `sonnet` (falhou → o mesmo subagent corrige → re-decompõe → só então `opus`, com motivo). Detalhe na base: `schematize-engineering` → `references/orquestracao.md` §9.

### Mantido (piso inalterado)
- Todos os pisos anteriores e o gate de `scripts/` seguem exatamente como estavam; a mudança é só de orquestração, não de código.

## [0.1.0] — 2026-08-21

Primeira versão. A vistoria de 2026-08-21 mediu o catálogo e achou o buraco: **shell é a linguagem mais usada da casa** — instalador, gate de CI, hook, ops, harness de teste — e era **a única sem piso, sem skill e sem gate**; `shellcheck` sequer estava instalado na máquina, e a casa distribuía scripts sem strict mode dentro de outras skills, como andaime normativo.

### Adicionado
- **`references/piso.md`** — o piso executável. Strict mode **e o que ele NÃO cobre**, que é a parte que morde: `-e` não dispara dentro de condição (`if`, `&&`, `||`, `!`), não vê a última linha de função usada como condição, não pega comando dentro de `echo "$(...)"`, e **`local x=$(cmd)` mascara o status** (o `local` é o comando, e sai 0). Mais exit code como contrato (**`2` = não deu para verificar**, obrigatório), `trap` em `EXIT INT TERM`, `mktemp` (com o porquê: `/tmp` é mundialmente gravável, nome previsível é **symlink attack**, e `$$` não protege), **`eval` vetado** com o substituto (array + `case`), e idempotência.
- **As três exceções legítimas ao strict mode, e a regra que as governa:** biblioteca sourceada (onde `set -e` muda as opções do **shell do chamador**), coletor que precisa somar achados, harness de teste — válidas **quando declaradas em comentário**. *A regra real não é "todo script tem `set -euo pipefail`": é **nenhum script tem o modo de falha por acidente**.*
- **`references/qualidade.md`** — aspas e word splitting (com os dois exemplos que apagam arquivo errado), `"$@"` vs `$*`, `while IFS= read -r`, nunca parsear `ls`; **`shellcheck` como gate** (`--severity=warning`, silenciar só com motivo na linha, o que ele pega e **o que ele não pega**); e **bash vs POSIX** de verdade: `/bin/sh` é dash no Debian, busybox no Alpine, e o **macOS ainda traz bash 3.2**.
- **`references/instalador.md`** — o contrato do instalador que **se adapta e nunca culpa quem rodou**: descobrir o usuário real sob `sudo` (`$SUDO_USER`, senão o arquivo nasce com dono root), o gerenciador de pacotes, o arquivo de perfil certo, e o que já existe; falhar dizendo **o que fazer agora**; e a posição sobre `curl | bash` (aceitável para bootstrap externo, **VETADO dentro** de script da casa, onde há repo, versão e checksum).
- **`scripts/check-shell.sh`** — o gate, com **waiver rastreável**: `# shell-ok: <motivo>` na linha (ou na de cima) dispensa uma regra **exigindo a explicação** — o oposto de desligar o gate no CI, que some do código. Ele também **ignora corpo de heredoc** (heredoc é dado, não código) — regra que nasceu do próprio gate se acusando no primeiro run.
- **`scripts/check-shell.test.sh`** — **17 casos**, 12 vermelhos de propósito, com os fixtures em heredoc.
- **Ordem de limpeza do código antes de analisar:** tira **string primeiro, comentário depois**. O inverso quebra numa linha como `grep -qE '(eval|exec).*#\s*ok'` — o `#` dentro da string vira "comentário", a linha é truncada e sobra aspa órfã, fazendo a regra casar com **o próprio padrão que ela procura**. Descoberto quando este gate acusou o gate da `schematize-python`; tem caso vermelho próprio (`hash-dentro-de-string`).

### Corrigido durante a própria escrita (vale registro)
- A regra de strict mode aceitava a exceção por **palavra solta no cabeçalho** (*biblioteca*, *coletor*, *source*) — e um `source "$dir/lib.sh"` na linha 12 dava **passe livre a qualquer script que carregasse uma lib**. Trocado por **marcador explícito com motivo** (`# strict-ok: <motivo>`), que é `grep`-ável e auditável. *Gate que aceita por acidente é pior que gate ausente: ele produz um verde que ninguém confere.* O caso vermelho está no teste (`excecao-sem-marcador`).

### Medido nesta versão
- `shellcheck` **instalado** (0.11.0) e rodado sobre os **155 `.sh`** do catálogo: **0 erros e 0 avisos**.
- O gate próprio, rodado sobre o catálogo inteiro, achou e fechou **~50 casos reais**: coletores e harnesses sem exceção declarada, `mktemp` sem `trap`, `exit 0` incondicional no fim, e `bash -c` com string variável.
