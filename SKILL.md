---
name: schematize-shell
metadata:
  version: 0.2.2
description: >-
  Piso de shell: script é código de produção. Use ao criar ou revisar *.sh, instaladores e hooks: strict mode e seus
  limites, aspas, trap, temporários seguros, idempotência, shellcheck/shfmt como gate, bats, portabilidade. Não use
  para serviço. Traz template de CI e .shellcheckrc.
---
<!-- cross-skill: efeitos-externos.md, ops.md -> schematize-engineering -->

# O piso de shell da casa (schematize-shell)

Disciplina normativa para **shell script**. A tese é curta: **script de shell é código de
produção**. Ele roda como root no servidor, apaga diretório, decide deploy e é a primeira coisa que
o usuário executa — e é o único lugar onde a casa aceitava, até 2026-08-21, código sem piso nenhum.

**Versão:** skill `schematize-shell` v0.2.2. Changelog em `CHANGELOG.md`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:foraRol intro="Esta skill é o recorte **shell** das linguagens **sancionadas fora do rol de backend** (`schematize-engineering` → `references/linguagens.md` §2.2): **ferramenta** — script de ops, instalador, hook; script é código de produção." cmd="shell" -->Esta skill é o recorte **shell** das linguagens **sancionadas fora do rol de backend** (`schematize-engineering` → `references/linguagens.md` §2.2): **ferramenta** — script de ops, instalador, hook; script é código de produção.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização — a lib, o gate, a
   sintaxe da linguagem. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve; subagents `sonnet` por padrão, `opus` só após falha.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/shell-*` cobrem só o piso da linguagem.<!-- /herdado -->

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

Assets prontos para copiar: `assets/ci/github-actions-ci.yml` (shellcheck, shfmt -d, bats/`.test.sh`) · `assets/lint/.shellcheckrc`.

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
11. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para subagents em `sonnet` (falhou → o mesmo subagent corrige, até 2 rodadas → re-decompõe → só então `opus`, com motivo). No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

## Relação com as outras skills

- **`schematize-engineering`** — a base: o piso comum (segredo, testes, DoD, archive) vale igual
  aqui; `references/ops.md` é quem manda no fluxo de ambientes que os scripts de ops executam.
- **`schematize-infra`** — o que o script provisiona (systemd, container, isolamento). Esta skill
  cuida do **como o script é escrito**; a infra, do **que ele monta**.
- **`schematize-qa`** — a disciplina de teste. Script com lógica de verdade (parsing, decisão) tem
  teste, e `bats-core` é o runner.
- **`schematize-pentest`** — injeção de comando é achado dela; aqui é o lado construtivo (`eval`
  vetado, array em vez de string).
