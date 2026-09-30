---
name: schematize-shell
metadata:
  version: 0.2.1
description: O piso de SHELL da casa — script de shell é código de produção, não cola. Rege strict mode (`set -euo pipefail`) e, principalmente, o que ele NÃO cobre (`-e` não dispara em condição, `local x=$(cmd)` mascara status, job em background falha calado); quoting e word splitting; `shellcheck` como gate que trava o merge; VETADO `eval`; exit code como contrato (0 passa · 1 reprova · 2 nada verificável); `trap` de limpeza em EXIT/INT/TERM; `mktemp` (nome fixo em /tmp é symlink attack); idempotência; portabilidade bash vs POSIX sh (dash, busybox, bash 3.2 do macOS); e o contrato do instalador que SE ADAPTA e nunca culpa quem rodou. Traz o gate executável (`scripts/check-shell.sh`) com waiver rastreável. Use SEMPRE que for escrever, revisar ou auditar `.sh` — instalador, gate de CI, script de ops, hook, harness de teste.
---
<!-- cross-skill: efeitos-externos.md, ops.md -> schematize-engineering -->

# O piso de shell da casa (schematize-shell)

Disciplina normativa para **shell script**. A tese é curta: **script de shell é código de
produção**. Ele roda como root no servidor, apaga diretório, decide deploy e é a primeira coisa que
o usuário executa — e é o único lugar onde a casa aceitava, até 2026-08-21, código sem piso nenhum.

**Versão:** skill `schematize-shell` v0.2.1. Changelog em `CHANGELOG.md`.

## Por que ela nasceu

A vistoria de 2026-08-21 mediu o catálogo: **shell é a linguagem mais usada da casa** — instalador,
gate de CI, hook, ops, harness de teste — e era **a única sem skill, sem piso e sem gate**. Pior:
`shellcheck` **não estava instalado** na máquina, e a casa distribuía, como andaime normativo,
scripts sem strict mode dentro de outras skills. Uma linguagem sem piso não fica neutra: ela vira o
lugar onde o piso das outras vaza.

## Comandos (Claude Code)

| Comando | O que faz |
|---|---|
| `/shell-help` | lista os comandos |
| `/shell-load` | carrega à força o corpo normativo (piso, qualidade, instalador) |
| `/shell-review` | revisa `.sh` (novo ou existente) contra o piso: roda o gate e lê o que a máquina não lê |
| `/shell-claude` | cria/mescla o `CLAUDE.md` sempre-on de shell na raiz do repo |
| `/shell-cc` · `/shell-handoff` | context compact / handoff arquivado |

## Como usar

1. **Rode o gate antes de discutir estilo:** `bash scripts/check-shell.sh .` — `0` passa · `1`
   reprova · `2` **nada para verificar** (que não é aprovação).
2. **Leia o piso** (`references/piso.md`): strict mode e suas fugas, exit code, `trap`, `mktemp`,
   `eval`, idempotência.
3. **Passe pelo quoting e pelo `shellcheck`** (`references/qualidade.md`), e decida **bash ou POSIX**
   de propósito — não por acidente de shebang.
4. **Se for instalador**, o contrato é o de `references/instalador.md`: ele **se adapta** e **nunca
   culpa quem rodou**.

Mapa de references:

| Tarefa | Reference |
|---|---|
| O piso executável: strict mode **e o que ele não cobre**, exit code, sinais e `trap`, `mktemp`, `eval` vetado, idempotência | `references/piso.md` |
| Aspas e word splitting, `shellcheck` como gate (e como silenciar de forma rastreável), bash vs POSIX/dash/busybox/macOS, estrutura do script | `references/qualidade.md` |
| O contrato do instalador: detectar em vez de exigir, falhar bem, `curl \| bash`, checklist | `references/instalador.md` |
| Versões e ferramental (bash, dash, busybox, `shellcheck`, `shfmt`, `bats`) | `references/stack-versoes.md` |

## Pisos inegociáveis (vetam o atalho)

1. **Strict mode, ou a exceção ESCRITA.** `set -euo pipefail` em todo script executável. As três
   exceções legítimas — biblioteca sourceada, coletor que soma achados, harness de teste — valem
   **declaradas em comentário**. A regra real não é "todo script tem `set -e`": é **nenhum script
   tem o modo de falha por acidente**.
2. **`shellcheck` é gate, não sugestão.** `--severity=warning` travando o merge; silenciar exige
   `# shellcheck disable=SCxxxx` **com motivo, na linha**.
3. **`eval` é VETADO.** Junto com `bash -c "$string"` montado com dado externo. Use **array** para
   montar comando e `case` para despachar.
4. **Exit code é contrato:** `0` passa · `1` reprova · **`2` = não deu para verificar**. Devolver `0`
   quando nada foi checado é a condição vacuamente verdadeira que este catálogo persegue.
5. **`trap` limpa em `EXIT INT TERM`** sempre que o script cria temporário, monta, ou trava lock.
6. **`mktemp`, nunca nome previsível em `/tmp`** — `/tmp` é mundialmente gravável e `$$` não
   protege: PID é previsível e reciclável.
7. **Idempotência:** rodar duas vezes dá o mesmo resultado. Anexar linha a arquivo de perfil sem
   marcador é o erro clássico.
8. **Toda expansão entre aspas**, `"$@"` e `"${array[@]}"` — e **nunca** parsear a saída de `ls`.
9. **O instalador se adapta e nunca culpa o usuário.** Descobre usuário real sob `sudo`, gerenciador
   de pacotes, shell e o que já existe; falha dizendo **o que fazer agora**.
10. **Segredo nunca em argumento de comando** (aparece em `ps` para qualquer usuário da máquina) nem
    ecoado em log.
11. **Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para subagents em `sonnet` (falhou → o mesmo subagent corrige → re-decompõe → só então `opus`, com motivo). **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata. Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.

## Relação com as outras skills

- **`schematize-engineering`** — a base: o piso comum (segredo, testes, DoD, archive) vale igual
  aqui; `references/ops.md` é quem manda no fluxo de ambientes que os scripts de ops executam.
- **`schematize-infra`** — o que o script provisiona (systemd, container, isolamento). Esta skill
  cuida do **como o script é escrito**; a infra, do **que ele monta**.
- **`schematize-qa`** — a disciplina de teste. Script com lógica de verdade (parsing, decisão) tem
  teste, e `bats-core` é o runner.
- **`schematize-pentest`** — injeção de comando é achado dela; aqui é o lado construtivo (`eval`
  vetado, array em vez de string).
