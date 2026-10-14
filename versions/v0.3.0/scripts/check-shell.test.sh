#!/usr/bin/env bash
# Vermelho primeiro do gate de shell. Cada fixture é um script de mentira com UM defeito.
#
# EXCEÇÃO DECLARADA (piso.md §1): harness de teste roda `set -u` sem `-e` — ele precisa continuar
# depois de um caso vermelho para reportar todos, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-shell.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT INT TERM
ok=0; fail=0

# caso <nome> <exit-esperado> <agulha>  — o script de FIXTURE vem pelo stdin (heredoc).
# Por heredoc de propósito: o fixture é DADO. Foi assim que o gate se acusou sozinho no primeiro
# run — e foi por isso que ele ganhou a função `tirar_heredoc`.
caso() {
  local nome="$1" esp="$2" agulha="$3"
  local d="$TMP/$nome"; mkdir -p "$d"
  cat > "$d/alvo.sh"
  local saida; saida="$(bash "$G" "$d" 2>&1)"; local rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $nome: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $nome: exit certo, saída sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $nome"; ok=$((ok+1))
}

echo "== verde de partida =="
caso verde 0 "no piso" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM
main() {
  local destino="$1"
  mkdir -p "$destino"
  printf 'ok\n' > "$tmp/x"
  cp "$tmp/x" "$destino/x"
}
main "$@"
FIX

echo "== strict mode =="
caso sem-strict 1 "SEM exceção declarada" <<'FIX'
#!/usr/bin/env bash
echo "sem set -e nenhum"
FIX
caso sem-u 1 'sem `-u`' <<'FIX'
#!/usr/bin/env bash
set -e
echo "so o -e"
FIX
caso sem-pipefail 1 'sem `pipefail`' <<'FIX'
#!/usr/bin/env bash
set -eu
curl -fsSL http://x | tar xz
FIX
caso excecao-declarada 0 "exceção declarada no cabeçalho" <<'FIX'
#!/usr/bin/env bash
# lib.sh — biblioteca para `source`: NÃO liga strict mode (mudaria as opções do shell do chamador).
# Exceção declarada, piso.md secao 1.
saudar() { printf '%s\n' "$1"; }
FIX

caso excecao-sem-marcador 1 "SEM exceção declarada" <<'FIX'
#!/usr/bin/env bash
# Este script carrega uma biblioteca e explica em prosa que por isso não liga strict mode.
# shellcheck source=./lib.sh
source "$(dirname "$0")/lib.sh"
echo "sem marcador: o gate NÃO pode aceitar por causa da palavra 'source' aqui"
FIX

echo "== eval e amigos =="
caso usa-eval 1 "VETADO" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
cmd="ls -la"
eval "$cmd"
FIX
caso bash-c 1 'com outro nome' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
bash -c "$ENTRADA_DO_USUARIO"
FIX

caso hash-dentro-de-string 0 "" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
# A linha abaixo NÃO usa eval: ela PROCURA por eval, e o `#` está dentro da string.
# Se o gate tirar comentário antes de tirar string, a linha é truncada, sobra aspa órfã,
# e a regra passa a casar com o próprio padrão que procura.
grep -qE '(eval|exec).*#[[:space:]]*ok' "$1" && echo "achou"
FIX

echo "== temporário e limpeza =="
caso tmp-fixo 1 "symlink attack" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
echo dado > /tmp/meuscript.$$
FIX
caso mktemp-sem-trap 1 'não tem `trap' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
d="$(mktemp -d)"
echo x > "$d/a"
FIX

echo "== destrutivo =="
caso rm-rf-var 0 'use "${var:?motivo}"' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
alvo="${1:-}"
rm -rf "$alvo"
FIX

echo "== ls e exit =="
caso parse-ls 1 "parseia a saída" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
for f in $(ls /tmp); do echo "$f"; done
FIX
caso exit-zero 1 "apaga o status" <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
grep -q algo arquivo
exit 0
FIX

echo "== portabilidade =="
caso bashismo-sob-sh 1 "quebra no container mínimo" <<'FIX'
#!/bin/sh
set -eu
if [[ -f /etc/os-release ]]; then echo sim; fi
FIX

echo "== segredo em argumento =="
caso segredo-em-arg 0 'aparece em `ps`' <<'FIX'
#!/usr/bin/env bash
set -euo pipefail
curl --password "$SENHA" https://exemplo.test
FIX

echo "== nada para verificar =="
d="$TMP/vazio"; mkdir -p "$d"; echo "# só prosa" > "$d/LEIA.md"
saida="$(bash "$G" "$d" 2>&1)"; rc=$?
if [ "$rc" = 2 ] && grep -q "não é aprovação" <<<"$saida"; then echo "  ✔ repo sem .sh sai 2 (não 0)"; ok=$((ok+1))
else echo "  ✖ repo sem .sh: exit $rc"; fail=$((fail+1)); fi

echo; echo "check-shell: $ok ok, $fail falha(s)"; [ "$fail" = 0 ]
