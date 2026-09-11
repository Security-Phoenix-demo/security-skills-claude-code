#!/usr/bin/env bash
# .claude/hooks/post-edit-quickscan.sh
#
# Runs after Edit / Write / MultiEdit. Pulls the file path from the tool
# input, runs a fast pattern scan keyed to the file's extension, and feeds
# findings back to the agent via the additionalContext channel.
#
# Heuristic only — designed to be near-instant. Real review is done by the
# `security-reviewer` subagent. The point of this hook is to make sure no
# write goes by unseen.
#
# Input contract: stdin is the PostToolUse payload, e.g.
#   {"hook_event_name":"PostToolUse","tool_name":"Write",
#    "tool_input":{"file_path":"/abs/path/to/edited.py"}}
#
# Wire-up in .claude/settings.json:
#   "PostToolUse": [
#     { "matcher": "Edit|Write|MultiEdit",
#       "hooks": [ { "type": "command", "command": ".claude/hooks/post-edit-quickscan.sh" } ] }
#   ]

. "$(dirname "$0")/lib/common.sh"

INPUT="$(cat)"
[[ -z "$INPUT" ]] && { emit_json PostToolUse additionalContext '""'; exit 0; }

# Without a JSON parser this hook cannot read which file was edited, and an
# unreadable payload is not an unedited file. Emitting an empty additionalContext --
# which is what happened on any host without a working python3 -- is indistinguishable
# from having scanned the file and found nothing, and session-start.sh tells every
# session this hook is watching. Say so instead.
if ! json_parser_available; then
  log "quickscan DID NOT RUN - no working python3 or jq to read the hook payload"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}
'     "$(printf '%s' "NOTE: the post-edit quick scan did not run. It needs python3 or jq on PATH to read the hook payload and found neither, so the file just written was NOT scanned. Do not read the absence of findings as a clean result." | jsonenc)"
  exit 0
fi

TOOL="$(get_json_field "$INPUT" "tool_name")"
case "$TOOL" in
  Write|Edit|MultiEdit)
    FILES="$(get_json_field "$INPUT" "tool_input.file_path")"
    ;;
  *)
    emit_json PostToolUse additionalContext '""'
    exit 0
    ;;
esac

[[ -z "$FILES" ]] && { emit_json PostToolUse additionalContext '""'; exit 0; }

FINDINGS=()
SCAN_ERRORS=()

# ---------------------------------------------------------------------------
# The scanner, and proving there is one.
#
# This used to be a single `rg -n ... 2>/dev/null` with nothing behind it.
# ripgrep is not a base tool on macOS or on most Linux CI images, so on a host
# without it the redirect swallowed "command not found", the read loop saw no
# lines, FINDINGS stayed empty, and the hook emitted additionalContext "" and
# exit 0 — byte for byte what a genuinely clean file produces. Meanwhile
# session-start.sh was telling every session this hook was active and watching.
# A scanner that is not there must not be able to look like a scanner that
# found nothing.

# Scanner stderr is captured, not discarded. Losing the temp file costs us the
# engine's own error text but not the detection — the exit status is checked
# either way — and we say that here rather than going quiet about it.
SCAN_ERR="$(mktemp "${TMPDIR:-/tmp}/quickscan-stderr.XXXXXX" 2>/dev/null)" || SCAN_ERR=""
if [[ -n "$SCAN_ERR" ]]; then
  trap 'rm -f "$SCAN_ERR"' EXIT
else
  SCAN_ERR=/dev/null
  SCAN_ERRORS+=("no writable temp file for scanner stderr — an engine's error text cannot be shown below, though its exit status is still checked")
fi

# run_scanner <engine> <case-insensitive:0|1> <pattern> <file>
# Prints "LINE:text" per match, at most 3. stderr is deliberately left alone
# here; the caller redirects it to $SCAN_ERR so "command not found" and
# "invalid regular expression" stay readable instead of being counted as zero
# hits.
#
# -m 3 replaces the old `| head -3`. A pipe into head puts the engine's exit
# status out of reach, and under the pipefail this library sets it reports the
# resulting SIGPIPE as a failure. That exit status is the only thing separating
# "no matches" from "never ran", so it cannot be spent on pagination.
run_scanner() {
  local eng="$1" ci="$2" pat="$3" file="$4"
  local ciflag=()
  [[ "$ci" == 1 ]] && ciflag=(-i)
  case "$eng" in
    rg)   rg   -n --no-heading -m 3 ${ciflag[@]+"${ciflag[@]}"} -e "$pat" -- "$file" ;;
    grep) grep -n -E           -m 3 ${ciflag[@]+"${ciflag[@]}"} -e "$pat" -- "$file" ;;
    *)    return 127 ;;
  esac
}

# have() is the necessary condition and never the sufficient one: an engine that
# exists but rejects our regex dialect is no more use than a missing one, and it
# fails the same silent way. So the candidate has to compile a fixture built from
# the same constructs the real patterns use — alternation, a start anchor, a
# negated class, a POSIX class, an interval, an escaped paren — and return the
# match we know is there.
SCANNER_PROBE_RE='(^|[^A-Za-z0-9_])q[[:space:]]*z{1,2}\('
SCANNER_PROBE_IN='x qz('

probe_scanner() {
  local eng="$1" out
  out="$(printf '%s\n' "$SCANNER_PROBE_IN" | run_scanner "$eng" 0 "$SCANNER_PROBE_RE" - 2>>"$SCAN_ERR")"
  [[ "$out" == "1:$SCANNER_PROBE_IN" ]]
}

# rg first for speed, then grep -E, which is POSIX and present on every host this
# hook can plausibly run on.
SCANNER=""
for _eng in rg grep; do
  if have "$_eng" && probe_scanner "$_eng"; then SCANNER="$_eng"; break; fi
done
# A rejected candidate's complaints are not the reader's problem once a later one
# works, so the probe's noise is dropped before the real scan starts.
: > "$SCAN_ERR" 2>/dev/null || true

if [[ -z "$SCANNER" ]]; then
  # The uncomfortable thing, said out loud. An empty additionalContext here is
  # indistinguishable from a clean file, and session-start.sh has already
  # announced that this hook is watching.
  body="$(
    printf '## SECURITY QUICK-SCAN — DID NOT RUN\n\n'
    printf 'No working pattern scanner was found. `rg` and then `grep -E` were each tried,\n'
    printf 'and each was either absent or failed a compile-and-match probe.\n\n'
    printf '**The file just written was not scanned. This is not a clean result.**\n\n'
    printf 'Install ripgrep, or put a POSIX `grep` on PATH, and this hook resumes on its\n'
    printf 'own. Until then treat files written in this session as unreviewed, and run the\n'
    printf '`security-reviewer` subagent over anything security-relevant.\n'
  )"
  emit_json PostToolUse additionalContext "$(printf '%s' "$body" | jsonenc)"
  log "quickscan DID NOT RUN — no working scanner (tried rg, then grep -E)"
  exit 0
fi

# add_finding <SEVERITY> <description> <file> <pattern>
# Uses a while-read loop so multi-line scanner output stays one finding per match.
add_finding() {
  local sev="$1" desc="$2" file="$3" pattern="$4"
  local ci=0 out rc line

  # Case-insensitivity is the one thing the two engines cannot share inside the
  # pattern. rg honours the inline PCRE flag (?i); grep -E does not — and it does
  # not reject it either, it parses (?i) as a group and then matches nothing,
  # which is exactly the silent zero this file is being repaired for. So (?i) is
  # a marker, stripped here and handed to the engine as -i, which both of them
  # spell the same way.
  if [[ "$pattern" == '(?i)'* ]]; then
    ci=1
    pattern="${pattern#'(?i)'}"
  fi

  out="$(run_scanner "$SCANNER" "$ci" "$pattern" "$file" 2>>"$SCAN_ERR")"
  rc=$?

  # 0 matched, 1 matched nothing. Anything else is the engine failing — usually a
  # pattern it cannot compile, sometimes a file it cannot read. A pattern that
  # never ran is not a pattern that found nothing, so it is recorded as its own
  # finding rather than folded into the silence.
  if (( rc > 1 )); then
    SCAN_ERRORS+=("$SCANNER exited $rc on the \"$desc\" pattern for $file — that pattern did not run")
    return
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    FINDINGS+=("[$sev] $desc — $file:$line")
  done <<< "$out"
}

# Patterns are POSIX ERE, the intersection of what both engines accept. They were
# written in rg's dialect, which is a second silent zero waiting to happen, so
# three constructs were translated:
#
#   \s   ->  [[:space:]]
#        GNU grep accepts \s as an extension. BSD grep — the grep on macOS — does
#        not, and does not complain: it reads \s as a literal "s" and quietly
#        stops matching.
#
#   \b   ->  (^|[^A-Za-z0-9_])
#        Also GNU-only; BSD spells it [[:<:]]. Neither is portable, so the word
#        boundary is written out. [A-Za-z0-9_] is exactly what \b treats as a word
#        character, so this matches what \b matched — including `obj.send(`, which
#        is the dangerous form of Ruby's send and has to keep matching. It consumes
#        one character where \b consumed none, which is harmless because only the
#        line number is reported.
#
#   (?i) ->  handled by add_finding as the -i flag (see there).
#
# One smaller fix in the same family: [A-Za-z0-9_\-] became [A-Za-z0-9_-]. Inside
# a POSIX bracket expression a backslash is an ordinary character, so the first
# form also matched a literal backslash under grep while meaning an escaped hyphen
# under rg. Hyphen-last is the same set in both.
scan_file() {
  local f="$1"

  # A file that cannot be read is NOT a file with nothing in it. Returning here in
  # silence let the hook prove a scanner works, announce nothing, and have looked at
  # nothing -- the same shape as the defect the scanner probe above exists to close,
  # one layer over. The header of this file promises no write goes by unseen.
  if [[ ! -f "$f" ]]; then
    # A Windows-style path is worth one translation attempt before giving up. Git
    # Bash resolves C:\... natively, but not every msys build does, and the cost of
    # being wrong is a hook that reports clean on a file it never opened.
    if [[ "$f" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
      local _drive _rest
      _drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z')"
      _rest="${BASH_REMATCH[2]//\\//}"
      [[ -f "/$_drive/$_rest" ]] && f="/$_drive/$_rest"
    fi
  fi

  if [[ ! -f "$f" ]]; then
    SCAN_ERRORS+=("$f could not be read, so it was NOT scanned - this is not a clean result")
    return
  fi
  local ext="${f##*.}"

  case "$ext" in
    py)
      add_finding HIGH     "TLS verification disabled"           "$f" 'verify[[:space:]]*=[[:space:]]*False'
      add_finding HIGH     "subprocess shell=True"               "$f" 'shell[[:space:]]*=[[:space:]]*True'
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'pickle\.loads?\(|yaml\.load\('
      add_finding CRITICAL "f-string SQL"                        "$f" '\.execute\([[:space:]]*[fF]["'"'"']'
      add_finding HIGH     "hardcoded secret candidate"          "$f" '(?i)(api[_-]?key|secret|token|password)[[:space:]]*=[[:space:]]*"[^"]{16,}"'
      add_finding HIGH     "dynamic code exec"                   "$f" '(^|[^A-Za-z0-9_])(exec|eval)\('
      add_finding MEDIUM   "XML parse without defusedxml"        "$f" 'xml\.etree\.ElementTree|xml\.dom\.minidom|lxml\.etree'
      ;;
    js|jsx|ts|tsx|mjs|cjs)
      add_finding HIGH     "DOM XSS sink"                        "$f" 'innerHTML[[:space:]]*=|insertAdjacentHTML\(|document\.write\('
      add_finding MEDIUM   "dangerouslySetInnerHTML"             "$f" 'dangerouslySetInnerHTML'
      add_finding HIGH     "TLS verification disabled"           "$f" 'rejectUnauthorized[[:space:]]*:[[:space:]]*false'
      add_finding HIGH     "secret in browser storage"           "$f" '(localStorage|sessionStorage)\.setItem\([^)]*(token|secret|key|jwt|password)'
      add_finding CRITICAL "JWT alg=none"                        "$f" 'algorithms[[:space:]]*:[[:space:]]*\[[[:space:]]*['"'"'"]none'
      add_finding HIGH     "dynamic code exec"                   "$f" '(^|[^A-Za-z0-9_])eval\(|new[[:space:]]+Function\('
      add_finding HIGH     "hardcoded secret candidate"          "$f" '(?i)(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*['"'"'"][A-Za-z0-9_-]{20,}'
      add_finding HIGH     "shell exec"                          "$f" 'child_process\.(exec|execSync)\(|[{][[:space:]]*shell[[:space:]]*:[[:space:]]*true'
      ;;
    go)
      add_finding HIGH     "TLS verification disabled"           "$f" 'InsecureSkipVerify[[:space:]]*:[[:space:]]*true'
      add_finding CRITICAL "shell exec"                          "$f" 'exec\.Command\([[:space:]]*"sh"[[:space:]]*,[[:space:]]*"-c"|exec\.Command\([[:space:]]*"bash"[[:space:]]*,[[:space:]]*"-c"'
      add_finding CRITICAL "formatted SQL"                       "$f" '\.(Query|Exec|QueryRow)(Context)?\([[:space:]]*[^,]*fmt\.Sprintf'
      add_finding MEDIUM   "weak hash"                           "$f" 'crypto/md5|crypto/sha1'
      add_finding MEDIUM   "non-crypto RNG for security"         "$f" 'math/rand'
      ;;
    java|kt)
      add_finding MEDIUM   "permitAll — verify intent"           "$f" '\.permitAll\(\)'
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'enableDefaultTyping|ObjectInputStream|new[[:space:]]+Yaml\([[:space:]]*\)\.load\('
      add_finding CRITICAL "JWT alg=none / null key"             "$f" 'Algorithm\.none|setSigningKey\([[:space:]]*null'
      add_finding HIGH     "runtime.exec"                        "$f" 'Runtime\.getRuntime\(\)\.exec'
      add_finding HIGH     "XXE risk"                            "$f" 'DocumentBuilderFactory\.newInstance|SAXParserFactory\.newInstance'
      ;;
    rs)
      add_finding HIGH     "TLS verification disabled"           "$f" 'danger_accept_invalid_certs|accept_invalid_hostnames'
      add_finding CRITICAL "shell exec"                          "$f" 'Command::new\([[:space:]]*"sh"|Command::new\([[:space:]]*"bash"'
      add_finding MEDIUM   "unsafe block"                        "$f" 'unsafe[[:space:]]*[{]'
      add_finding MEDIUM   "panic-on-unwrap in handler"          "$f" '\.unwrap\(\)|\.expect\('
      ;;
    rb|erb)
      add_finding CRITICAL "dynamic code exec"                   "$f" '(^|[^A-Za-z0-9_])(eval|instance_eval|class_eval|send)\('
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'YAML\.load\(|Marshal\.load\('
      add_finding CRITICAL "interpolated SQL"                    "$f" '\.where\([[:space:]]*"[^"]*#[{]'
      add_finding MEDIUM   "CSRF disabled with null_session"     "$f" 'protect_from_forgery[[:space:]]+with:[[:space:]]*:null_session'
      add_finding HIGH     "raw HTML output"                      "$f" 'raw[[:space:]]+|\.html_safe'
      ;;
    cs|cshtml|razor)
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'BinaryFormatter|TypeNameHandling\.(All|Auto|Objects)'
      add_finding HIGH     "TLS verification disabled"           "$f" 'ServerCertificateCustomValidationCallback.*=>[[:space:]]*true|RemoteCertificateValidationCallback.*=>[[:space:]]*true'
      add_finding HIGH     "shell-execute process"               "$f" 'UseShellExecute[[:space:]]*=[[:space:]]*true'
      add_finding HIGH     "raw SQL"                             "$f" 'FromSqlRaw\(|ExecuteSqlRaw\('
      add_finding HIGH     "Razor raw output"                    "$f" '@Html\.Raw\('
      ;;
    php)
      add_finding CRITICAL "dynamic code exec"                   "$f" '(^|[^A-Za-z0-9_])(eval|assert)\('
      add_finding CRITICAL "unsafe deserialisation"              "$f" '(^|[^A-Za-z0-9_])unserialize\('
      add_finding HIGH     "shell exec"                          "$f" '(^|[^A-Za-z0-9_])(system|exec|passthru|shell_exec|popen|proc_open)\('
      # [^)]* not [^,]*: mysqli_query's FIRST argument is always the connection
      # handle, so a class that cannot cross the comma could never reach the
      # tainted second argument. Measured on mysqli_query($conn, $_GET["q"]): 0 hits.
      add_finding HIGH     "SQL concatenation"                   "$f" 'mysqli_query\([^)]*\$_(GET|POST|REQUEST)|->query\([^)]*\$_(GET|POST|REQUEST)'
      ;;
    *)
      # No rules for this extension is not the same as nothing to report. Shell,
      # YAML, Terraform, HTML, SQL, C, Swift, Vue and Svelte all landed here and came
      # back byte-identical to a scanned-and-clean file -- while this file's own header
      # says "no write goes by unseen" and session-start.sh tells every session so.
      SCAN_ERRORS+=("no patterns exist for .$ext - $f was NOT scanned")
      ;;
  esac
}

# Tool input may carry one path or, for MultiEdit, a single path with multiple edits.
# Older MultiEdit shapes pass a newline-separated list — handle both.
while IFS= read -r f; do
  [[ -n "$f" ]] && scan_file "$f"
done <<< "$FILES"

# Whatever the engine wrote to stderr is part of the report, not litter to throw
# away. A regex it rejected has to be visible; that is the whole repair.
if [[ -s "$SCAN_ERR" ]]; then
  while IFS= read -r _errline; do
    [[ -z "$_errline" ]] && continue
    SCAN_ERRORS+=("$SCANNER said: $_errline")
  done < "$SCAN_ERR"
fi

if [[ ${#FINDINGS[@]} -eq 0 && ${#SCAN_ERRORS[@]} -eq 0 ]]; then
  # Now this means something: a scanner was proved to work, and it found nothing.
  emit_json PostToolUse additionalContext '""'
  exit 0
fi

# Build context block. bash 3.2 (macOS default) errors on "${arr[@]}" when the
# array is empty and set -u is on, and either array can be empty here.
body="$(
  if [[ ${#FINDINGS[@]} -gt 0 ]]; then
    printf '## SECURITY QUICK-SCAN — findings on files just edited\n\n'
    printf 'Pattern-based, not authoritative. Confirm each before acting.\n\n'
    for line in ${FINDINGS[@]+"${FINDINGS[@]}"}; do
      printf -- '- %s\n' "$line"
    done
    printf '\nIf any look real, run the `security-reviewer` subagent over the file for a full review.\n'
  fi
  if [[ ${#SCAN_ERRORS[@]} -gt 0 ]]; then
    [[ ${#FINDINGS[@]} -gt 0 ]] && printf '\n'
    printf '## SECURITY QUICK-SCAN — the scanner reported errors\n\n'
    printf 'These patterns did not run. Their absence from the list above means nothing was\n'
    printf 'looked at, not that nothing was found.\n\n'
    for line in ${SCAN_ERRORS[@]+"${SCAN_ERRORS[@]}"}; do
      printf -- '- %s\n' "$line"
    done
  fi
)"

emit_json PostToolUse additionalContext "$(printf '%s' "$body" | jsonenc)"
log "quickscan [$SCANNER] emitted ${#FINDINGS[@]} finding(s) and ${#SCAN_ERRORS[@]} scanner error(s)"
exit 0
