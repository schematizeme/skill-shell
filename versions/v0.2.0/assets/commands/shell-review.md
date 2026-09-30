---
description: schematize-shell — revisa script(s) de shell contra o piso: roda o gate e o shellcheck, depois lê o que a máquina não lê (idempotência, lógica, mensagem de erro)
argument-hint: "[arquivo.sh ou diretório]"
---

# /shell-review — script de shell é código de produção

## 1. A máquina primeiro

```bash
bash .claude/skills/schematize-shell/scripts/check-shell.sh .   # o piso da casa
shellcheck --severity=warning --format=gcc <arquivos>           # a análise estática
```

`0` passa · `1` reprova · `2` **nada para verificar** — que não é aprovação.

O gate cobra: strict mode (ou a **exceção declarada** — biblioteca sourceada, coletor, harness);
`eval` e `bash -c "$var"`; `/tmp` com nome previsível; `mktemp` sem `trap`; `rm -rf $var` sem
`${var:?}`; `cd` sem guarda; parse de `ls`; `exit 0` incondicional no fim; bashismo sob shebang `sh`;
segredo em argumento. Waiver: `# shell-ok: <motivo>` na linha ou na de cima — **com o motivo**.

## 2. Depois, o que a máquina não lê

- **Idempotência:** rodar duas vezes dá o mesmo resultado? Onde ele **anexa** a arquivo, há marcador?
- **O `-e` está fazendo o que você acha?** Procure `if cmd`, `cmd && outro`, `local x=$(cmd)` e job em
  background: são os quatro lugares onde a falha **não** aborta (`piso.md` §1).
- **Mensagem de erro:** diz **o que falhou, por quê e o que fazer agora** — e **não culpa quem rodou**?
- **Destrutivo:** todo `rm -rf`/`truncate`/`DROP` tem o caminho **construído e validado**? existe
  `--dry-run` quando o efeito é grande?
- **Estado parcial:** se abortar no meio, o sistema fica utilizável? o `trap` desfaz o que precisa?
- **Segredo:** nada em argumento (aparece em `ps`), nada ecoado em log, nada em arquivo temporário
  legível por todos.
- **Portabilidade:** o shebang bate com o que o script usa, e com onde ele roda (container mínimo?
  macOS?).
- **Instalador?** então passe pelo checklist de `references/instalador.md`.

## 3. Feche

Achado vira correção no mesmo PR ou item de checklist com dono — não "depois". E rode o vermelho do
próprio gate quando mexer nele: `bash scripts/check-shell.test.sh` (15 casos).
