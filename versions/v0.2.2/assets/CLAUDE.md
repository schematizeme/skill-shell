# Piso de shell (schematize-shell) — sempre-on

Script de shell **é código de produção**: roda como root, apaga diretório e decide deploy.

1. **Strict mode, ou a exceção escrita.** `#!/usr/bin/env bash` + `set -euo pipefail` em todo script
   executável. Biblioteca sourceada, coletor e harness de teste podem não ter — **declarando o
   motivo em comentário**. Nenhum script tem o modo de falha por acidente.
2. **Saiba o que o `-e` NÃO pega:** dentro de `if`/`&&`/`||`/`!`, na última linha de função usada
   como condição, em `echo "$(cmd)"`, e em `local x=$(cmd)` (o `local` sai 0). Job em background
   falha calado sem `wait` + checagem.
3. **`shellcheck --severity=warning` trava o merge.** Silenciar exige `# shellcheck disable=SCxxxx`
   com motivo, na linha.
4. **VETADO `eval`** e `bash -c "$string"` com dado externo. Monte comando com **array**
   (`"${args[@]}"`) e despache com `case`.
5. **Exit code é contrato:** `0` passa · `1` reprova · **`2` = não deu para verificar**. Nunca
   `exit 0` incondicional no fim.
6. **`trap 'limpa' EXIT INT TERM`** sempre que criar temporário, montar ou travar lock. **`mktemp`**,
   nunca nome fixo em `/tmp` (symlink attack; `$$` não protege).
7. **Aspas em toda expansão**; `"$@"` e `"${array[@]}"`; `while IFS= read -r`; **nunca** parseie `ls`.
8. **Idempotente:** rodar duas vezes dá o mesmo resultado; anexar a arquivo exige marcador.
9. **Instalador se adapta e nunca culpa o usuário:** descobre o usuário real sob `sudo`, o
   gerenciador de pacotes e o shell; falha dizendo **o que fazer agora**.
10. **Segredo nunca em argumento** (aparece em `ps`) nem em log.
11. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para subagents em `sonnet` (falhou → o mesmo subagent corrige, até 2 rodadas → re-decompõe → só então `opus`, com motivo). No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Gate: `bash .claude/skills/schematize-shell/scripts/check-shell.sh .` — waiver rastreável
`# shell-ok: <motivo>`.
