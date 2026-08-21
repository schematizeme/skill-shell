#!/usr/bin/env bash
# schematize-shell — o gate. Roda o `shellcheck` e cobra o piso de `references/piso.md` sobre todo
# `.sh` do repo.
#
# NOTA DE EXCEÇÃO DECLARADA (piso.md §1): este script usa `set -uo pipefail` SEM `-e` de propósito —
# ele é um COLETOR: precisa varrer todos os arquivos e somar os achados. Com `-e` ele abortaria no
# primeiro problema e reportaria um, escondendo os outros onze.
#
# uso: check-shell.sh [dir]   ·  0 = passa · 1 = REPROVA · 2 = nada para verificar / uso errado
set -uo pipefail

raiz="${1:-.}"
erros=(); avisos=()

# `find` com -print0 + read -d '': nome com espaço ou quebra de linha não quebra a lista.
arquivos=()
while IFS= read -r -d '' f; do arquivos+=("$f"); done < <(
  find "$raiz" -type f -name '*.sh' \
    -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/versions/*' \
    -not -path '*/target/*' -print0 2>/dev/null
)

# Fail-closed: repo sem script nenhum NÃO passa — sai 2. "Não achei" nunca é "está tudo certo".
if [ "${#arquivos[@]}" -eq 0 ]; then
  echo "✖ nenhum .sh em $raiz — nada para verificar (e ausência de material não é aprovação)." >&2
  exit 2
fi

# ---------------------------------------------------------------- 1. shellcheck (o gate)
if command -v shellcheck >/dev/null 2>&1; then
  saida="$(shellcheck --severity=warning --format=gcc "${arquivos[@]}" 2>/dev/null)"
  if [ -n "$saida" ]; then
    while IFS= read -r linha; do [ -n "$linha" ] && erros+=("shellcheck: $linha"); done <<< "$saida"
  fi
else
  # Aviso RUIDOSO, não silêncio: o gate sem shellcheck cobre menos, e quem lê precisa saber.
  avisos+=("shellcheck NÃO está instalado — o gate rodou só as regras próprias (bem menos). Instale: apt install shellcheck, ou o binário do release oficial (references/stack-versoes.md)")
fi

# dispensado <regex> <arquivo> — TODA linha que casa o regex traz um waiver `# shell-ok: <motivo>`?
#
# O waiver existe para a exceção real (o comando que É a configuração, o padrão que só parece
# perigoso) e é **rastreável**: fica no diff, aparece no `grep`, e exige o MOTIVO — `# shell-ok:`
# sozinho não vale. É o oposto de desligar o gate no CI, que some do código e ninguém revisa.
# Aceita o marcador na própria linha ou na linha imediatamente acima (onde a explicação cabe).
dispensado() {
  local regex="$1" arq="$2" n total=0 cobertas=0
  while IFS=: read -r n _; do
    total=$((total+1))
    if sed -n "${n}p;$((n>1?n-1:1))p" "$arq" | grep -qE '#[[:space:]]*shell-ok:[[:space:]]*[^[:space:]]+'; then
      cobertas=$((cobertas+1))
    fi
  done < <(grep -nE "$regex" "$arq")
  [ "$total" -gt 0 ] && [ "$cobertas" = "$total" ]
}

# tirar_heredoc — imprime o arquivo SEM o corpo dos heredocs.
#
# Heredoc é DADO, não código: o conteúdo entre `<<EOF` e `EOF` pode ser um exemplo, um template, ou
# (no caso dos testes desta própria skill) um script de fixture com defeito DE PROPÓSITO. Analisar
# aquilo como se fosse o script produz achado inventado — e um gate que grita no arquivo errado é um
# gate que alguém desliga.
tirar_heredoc() {
  local arq="$1" linha dentro=0 fim=""
  while IFS= read -r linha; do
    if [ "$dentro" = 1 ]; then
      # o delimitador pode vir indentado (<<-)
      [ "$(printf '%s' "$linha" | tr -d '[:space:]')" = "$fim" ] && dentro=0
      continue
    fi
    if [[ "$linha" =~ \<\<-?[[:space:]]*[\'\"]?([A-Za-z_][A-Za-z0-9_]*)[\'\"]? ]]; then
      fim="${BASH_REMATCH[1]}"; dentro=1
    fi
    printf '%s\n' "$linha"
  done < "$arq"
}

# ---------------------------------------------------------------- 2. piso próprio
for f in "${arquivos[@]}"; do
  nome="${f#"$raiz"/}"
  cabeca="$(head -n 30 "$f")"
  sem_heredoc="$(tirar_heredoc "$f")"
  # ORDEM IMPORTA: tira as STRINGS primeiro, o comentário depois. O caminho inverso quebra numa
  # linha como `grep -qE '(eval|exec).*#\s*ok'` — o `#` dentro da string vira "comentário", a linha
  # é truncada no meio e sobra uma aspa órfã; o resultado é a regra casando com o próprio padrão
  # que ela procura. (Foi exatamente assim que o gate acusou o gate de Python.)
  corpo="$(printf '%s\n' "$sem_heredoc" | sed -e "s/'[^']*'/''/g" -e 's/"[^"]*"/""/g' -e 's/#.*$//')"
  # `codigo` = sem comentário, mas COM as strings: as regras que olham expansão dentro de aspas
  # (`rm -rf "$var"`, `bash -c "$x"`) precisam ver o `$`. Usar `corpo` nelas as tornaria cegas —
  # o defeito real mora justamente dentro das aspas.
  codigo="$(printf '%s\n' "$sem_heredoc" | sed 's/#.*$//')"

  # 2.1 strict mode — com as exceções DECLARADAS de piso.md §1
  if ! grep -qE '^\s*set -[a-z]*e[a-z]*\b|^\s*set -o errexit' "$f"; then
    # O marcador é EXPLÍCITO de propósito. A primeira versão desta regra aceitava palavras soltas
    # ("biblioteca", "coletor", "source") no cabeçalho — e `source "$dir/lib.sh"` na linha 12 dava
    # passe livre a qualquer script que carregasse uma lib. Gate que aceita por acidente é pior que
    # gate ausente: ele produz um verde que ninguém confere.
    declarada=$(grep -ciE 'strict-ok:[[:space:]]*[^[:space:]]+|EXCE(Ç|C)(Ã|A)O DECLARADA' <<< "$cabeca")
    if [ "$declarada" -gt 0 ]; then
      avisos+=("$nome: sem \`set -e\` — exceção declarada no cabeçalho (ok)")
    else
      erros+=("$nome: sem strict mode e SEM exceção declarada — use \`set -euo pipefail\`, ou declare no cabeçalho com \`# strict-ok: <motivo>\` (biblioteca sourceada, coletor que soma achados, harness de teste)")
    fi
  else
    grep -qE '^\s*set -[a-z]*u|^\s*set -o nounset' "$f" || erros+=("$nome: \`set -e\` sem \`-u\` — variável com typo vira string vazia em silêncio")
    grep -qE 'pipefail' "$f" || erros+=("$nome: sem \`pipefail\` — \`curl -f url | tar xz\` sai 0 quando o curl falha")
  fi

  # 2.2 eval e amigos
  # `# shell-ok: <motivo>` na MESMA linha dispensa a regra — com o motivo escrito, que é o ponto:
  # o waiver é rastreável no diff e no `grep`, ao contrário do gate desligado no CI. Sem motivo (só
  # `# shell-ok:`) ele NÃO vale: o gate cobra a explicação, não a palavra mágica.
  # dispensado <padrao> <arquivo> — true quando a linha que casa o padrão traz `# shell-ok: motivo`
  # na PRÓPRIA linha ou na linha IMEDIATAMENTE acima (é onde a explicação cabe, quando ela é longa —
  # mesma convenção do `# shellcheck disable`).
  if grep -qE '(^|[;&|(]\s*)eval\b' <<< "$corpo" && ! dispensado '(^|[;&|(][[:space:]]*)eval\b' "$f"; then
    erros+=("$nome: usa \`eval\` — VETADO (injeção de comando). Use array para montar comando e \`case\` para despachar")
  fi
  if grep -qE 'bash -c ["'"'"']?\$' <<< "$codigo" && ! dispensado 'bash -c' "$f"; then
    erros+=("$nome: \`bash -c\` com string variável — é \`eval\` com outro nome")
  fi

  # 2.3 temporário previsível
  grep -qE '/tmp/[A-Za-z0-9_.-]*\$\$|/tmp/[A-Za-z0-9_.-]+"?\s*$' <<< "$codigo" \
    && ! grep -q 'mktemp' "$f" \
    && erros+=("$nome: caminho fixo em /tmp sem \`mktemp\` — /tmp é mundialmente gravável: nome previsível é symlink attack (\`\$\$\` não protege: PID é previsível)")

  # 2.4 rm -rf sobre variável sem validação nem :?
  if grep -qE 'rm -rf +"?\$' <<< "$codigo"; then
    grep -qE 'rm -rf +"?\$\{[A-Za-z_][A-Za-z0-9_]*:\?' <<< "$codigo" \
      || avisos+=("$nome: \`rm -rf \$var\` — use \"\${var:?motivo}\" para que a variável vazia ABORTE em vez de virar /")
  fi

  # 2.5 trap de limpeza quando cria temporário
  if grep -q 'mktemp' "$f" && ! grep -q 'trap ' "$f"; then
    erros+=("$nome: cria temporário com \`mktemp\` e não tem \`trap ... EXIT\` — Ctrl-C deixa lixo (piso.md §3)")
  fi
  if grep -qE '^\s*trap ' "$f" && ! grep -qE '^\s*trap .*(EXIT|INT|TERM)' "$f"; then
    avisos+=("$nome: \`trap\` sem EXIT/INT/TERM — cobre menos caminhos do que parece")
  fi

  # 2.6 cd sem guarda
  grep -qE '^\s*cd +[^|&]*$' <<< "$corpo" \
    && ! grep -qE '^\s*cd .*(\|\||&&|; then)' <<< "$corpo" \
    && avisos+=("$nome: \`cd\` sem \`|| exit\` — se o diretório não existe, o resto do script roda no lugar errado (SC2164)")

  # 2.7 parse de ls
  grep -qE 'for .* in .*\$\(ls |`ls ' <<< "$corpo" && erros+=("$nome: parseia a saída de \`ls\` — nome com espaço quebra. Use glob ou \`find -print0\`")

  # 2.8 exit 0 incondicional no fim
  ultima="$(grep -vE '^\s*(#|$)' "$f" | tail -1)"
  [ "$ultima" = "exit 0" ] && erros+=("$nome: termina em \`exit 0\` incondicional — apaga o status de tudo o que veio antes")

  # 2.9 shebang
  primeira="$(head -1 "$f")"
  case "$primeira" in
    '#!/usr/bin/env bash'|'#!/bin/bash'|'#!/usr/bin/env sh'|'#!/bin/sh') ;;
    '#!'*) avisos+=("$nome: shebang incomum ($primeira)") ;;
    *)
      grep -q 'shellcheck shell=' "$f" \
        || avisos+=("$nome: sem shebang e sem \`# shellcheck shell=bash\` — se é biblioteca, declare")
      ;;
  esac
  if [ "$primeira" = '#!/bin/sh' ] || [ "$primeira" = '#!/usr/bin/env sh' ]; then
    if grep -qE '\[\[|declare -[aA]|local |\$\{[A-Za-z_]+\^\^|mapfile|<<<' <<< "$corpo"; then
      erros+=("$nome: shebang \`sh\` (POSIX = dash no Debian) com bashismo — funciona na sua máquina, quebra no container mínimo")
    fi
  fi

  # 2.10 segredo em argumento (aparece em `ps`)
  grep -qE '(curl|wget|psql|mysql|ssh)[^|]*(--password|-p ?\$|--token)[= ]' <<< "$corpo" \
    && avisos+=("$nome: possível segredo em argumento de comando — aparece em \`ps\` para qualquer usuário da máquina; use variável de ambiente ou stdin")
done

# ---------------------------------------------------------------- saída
for a in "${avisos[@]:-}"; do [ -n "$a" ] && echo "  ! $a" >&2; done
if [ "${#erros[@]}" -gt 0 ]; then
  echo "" >&2
  echo "✖ SHELL REPROVADO — ${#erros[@]} problema(s) em ${#arquivos[@]} arquivo(s):" >&2
  for e in "${erros[@]}"; do echo "  · $e" >&2; done
  echo "" >&2
  echo "  Script de shell é código de produção: roda como root, apaga diretório e decide deploy." >&2
  exit 1
fi
echo "✔ shell: ${#arquivos[@]} arquivo(s) no piso$(command -v shellcheck >/dev/null 2>&1 && echo ' (shellcheck limpo)' || echo ' — SEM shellcheck, cobertura reduzida')."
