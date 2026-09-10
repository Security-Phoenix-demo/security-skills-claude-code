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
# Wire-up in .claude/settings.json:
#   "PostToolUse": [
#     { "matcher": "Edit|Write|MultiEdit",
#       "hooks": [ { "type": "command", "command": ".claude/hooks/post-edit-quickscan.sh" } ] }
#   ]

. "$(dirname "$0")/lib/common.sh"

INPUT="$(cat)"
[[ -z "$INPUT" ]] && { emit_json PostToolUse additionalContext '""'; exit 0; }

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

# add_finding <SEVERITY> <description> <file> <ripgrep-pattern>
# Uses a while-read loop so multi-line rg output stays one finding per match.
add_finding() {
  local sev="$1" desc="$2" file="$3" pattern="$4"
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    FINDINGS+=("[$sev] $desc — $file:$line")
  done < <(rg -n --no-heading -e "$pattern" "$file" 2>/dev/null | head -3)
}

scan_file() {
  local f="$1"
  [[ ! -f "$f" ]] && return
  local ext="${f##*.}"

  case "$ext" in
    py)
      add_finding HIGH     "TLS verification disabled"           "$f" 'verify\s*=\s*False'
      add_finding HIGH     "subprocess shell=True"               "$f" 'shell\s*=\s*True'
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'pickle\.loads?\(|yaml\.load\('
      add_finding CRITICAL "f-string SQL"                        "$f" '\.execute\(\s*[fF]["'"'"']'
      add_finding HIGH     "hardcoded secret candidate"          "$f" '(?i)(api[_-]?key|secret|token|password)\s*=\s*"[^"]{16,}"'
      add_finding HIGH     "dynamic code exec"                   "$f" '\b(exec|eval)\('
      add_finding MEDIUM   "XML parse without defusedxml"        "$f" 'xml\.etree\.ElementTree|xml\.dom\.minidom|lxml\.etree'
      ;;
    js|jsx|ts|tsx|mjs|cjs)
      add_finding HIGH     "DOM XSS sink"                        "$f" 'innerHTML\s*=|insertAdjacentHTML\(|document\.write\('
      add_finding MEDIUM   "dangerouslySetInnerHTML"             "$f" 'dangerouslySetInnerHTML'
      add_finding HIGH     "TLS verification disabled"           "$f" 'rejectUnauthorized\s*:\s*false'
      add_finding HIGH     "secret in browser storage"           "$f" '(localStorage|sessionStorage)\.setItem\([^)]*(token|secret|key|jwt|password)'
      add_finding CRITICAL "JWT alg=none"                        "$f" 'algorithms\s*:\s*\[\s*['"'"'"]none'
      add_finding HIGH     "dynamic code exec"                   "$f" '\beval\(|new\s+Function\('
      add_finding HIGH     "hardcoded secret candidate"          "$f" '(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*['"'"'"][A-Za-z0-9_\-]{20,}'
      add_finding HIGH     "shell exec"                          "$f" 'child_process\.(exec|execSync)\(|\{\s*shell\s*:\s*true'
      ;;
    go)
      add_finding HIGH     "TLS verification disabled"           "$f" 'InsecureSkipVerify\s*:\s*true'
      add_finding CRITICAL "shell exec"                          "$f" 'exec\.Command\(\s*"sh"\s*,\s*"-c"|exec\.Command\(\s*"bash"\s*,\s*"-c"'
      add_finding CRITICAL "formatted SQL"                       "$f" '\.(Query|Exec|QueryRow)(Context)?\(\s*[^,]*fmt\.Sprintf'
      add_finding MEDIUM   "weak hash"                           "$f" 'crypto/md5|crypto/sha1'
      add_finding MEDIUM   "non-crypto RNG for security"         "$f" 'math/rand'
      ;;
    java|kt)
      add_finding MEDIUM   "permitAll — verify intent"           "$f" '\.permitAll\(\)'
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'enableDefaultTyping|ObjectInputStream|new\s+Yaml\(\s*\)\.load\('
      add_finding CRITICAL "JWT alg=none / null key"             "$f" 'Algorithm\.none|setSigningKey\(\s*null'
      add_finding HIGH     "runtime.exec"                        "$f" 'Runtime\.getRuntime\(\)\.exec'
      add_finding HIGH     "XXE risk"                            "$f" 'DocumentBuilderFactory\.newInstance|SAXParserFactory\.newInstance'
      ;;
    rs)
      add_finding HIGH     "TLS verification disabled"           "$f" 'danger_accept_invalid_certs|accept_invalid_hostnames'
      add_finding CRITICAL "shell exec"                          "$f" 'Command::new\(\s*"sh"|Command::new\(\s*"bash"'
      add_finding MEDIUM   "unsafe block"                        "$f" 'unsafe\s*\{'
      add_finding MEDIUM   "panic-on-unwrap in handler"          "$f" '\.unwrap\(\)|\.expect\('
      ;;
    rb|erb)
      add_finding CRITICAL "dynamic code exec"                   "$f" '\b(eval|instance_eval|class_eval|send)\('
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'YAML\.load\(|Marshal\.load\('
      add_finding CRITICAL "interpolated SQL"                    "$f" '\.where\(\s*"[^"]*#\{'
      add_finding MEDIUM   "CSRF disabled with null_session"     "$f" 'protect_from_forgery\s+with:\s*:null_session'
      add_finding HIGH     "raw HTML output"                      "$f" 'raw\s+|\.html_safe'
      ;;
    cs|cshtml|razor)
      add_finding CRITICAL "unsafe deserialisation"              "$f" 'BinaryFormatter|TypeNameHandling\.(All|Auto|Objects)'
      add_finding HIGH     "TLS verification disabled"           "$f" 'ServerCertificateCustomValidationCallback.*=>\s*true|RemoteCertificateValidationCallback.*=>\s*true'
      add_finding HIGH     "shell-execute process"               "$f" 'UseShellExecute\s*=\s*true'
      add_finding HIGH     "raw SQL"                             "$f" 'FromSqlRaw\(|ExecuteSqlRaw\('
      add_finding HIGH     "Razor raw output"                    "$f" '@Html\.Raw\('
      ;;
    php)
      add_finding CRITICAL "dynamic code exec"                   "$f" '\b(eval|assert)\('
      add_finding CRITICAL "unsafe deserialisation"              "$f" '\bunserialize\('
      add_finding HIGH     "shell exec"                          "$f" '\b(system|exec|passthru|shell_exec|popen|proc_open)\('
      add_finding HIGH     "SQL concatenation"                   "$f" 'mysqli_query\([^,]*\$_(GET|POST|REQUEST)|->query\([^)]*\$_(GET|POST|REQUEST)'
      ;;
  esac
}

# Tool input may carry one path or, for MultiEdit, a single path with multiple edits.
# Older MultiEdit shapes pass a newline-separated list — handle both.
while IFS= read -r f; do
  [[ -n "$f" ]] && scan_file "$f"
done <<< "$FILES"

if [[ ${#FINDINGS[@]} -eq 0 ]]; then
  emit_json PostToolUse additionalContext '""'
  exit 0
fi

# Build context block
body="$(
  printf '## SECURITY QUICK-SCAN — findings on files just edited\n\n'
  printf 'Pattern-based, not authoritative. Confirm each before acting.\n\n'
  for line in "${FINDINGS[@]}"; do
    printf -- '- %s\n' "$line"
  done
  printf '\nIf any look real, run the `security-reviewer` subagent over the file for a full review.\n'
)"

emit_json PostToolUse additionalContext "$(printf '%s' "$body" | jsonenc)"
log "quickscan emitted ${#FINDINGS[@]} finding(s)"
exit 0
