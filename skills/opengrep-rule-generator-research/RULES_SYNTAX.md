# Opengrep Rule Syntax & Programmatic Generation Guide

## Rule File Structure

Every rule file is a YAML document with a top-level `rules:` key containing a list of rule objects.

```yaml
rules:
  - id: <unique-rule-id>
    message: <human-readable description>
    severity: <ERROR|WARNING|INFO>
    languages: [<language-identifiers>]
    # Then ONE of: pattern, patterns, pattern-either, pattern-regex, or mode: taint
    pattern: <code-pattern>
```

**Two syntax versions exist:**
- **v1.0 (legacy, most common)**: Uses `pattern`, `patterns`, `pattern-either`, `pattern-not`, etc.
- **v2.0 (new)**: Uses `match:`, `all:`, `any:`, `not:`, `inside:`, `where:`

Both are fully supported. All existing rules use v1.0. This guide covers both.

---

## 1. Core Rule Fields (Mandatory)

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier, kebab-case. Must be unique within a file. |
| `message` | string | Finding description. Supports `>-` for folded multiline. |
| `severity` | enum | `CRITICAL`, `HIGH`, `ERROR`, `MEDIUM`, `WARNING`, `LOW`, `INFO`, `INVENTORY`, `EXPERIMENT` |
| `languages` | list[string] | Target languages. See Language Identifiers below. |

---

## 2. Rule Modes

### 2a. Search Mode (default)

Uses pattern operators to match code structurally. No `mode:` field needed.

### 2b. Taint Mode

```yaml
mode: taint
pattern-sources: [...]
pattern-sinks: [...]
pattern-sanitizers: [...]    # optional
pattern-propagators: [...]   # optional
```

### 2c. Extract Mode (Pro-only)

```yaml
mode: extract
```

### 2d. Steps Mode (Pro-only)

```yaml
mode: steps
```

---

## 3. Pattern Operators

### 3a. Single Pattern (`pattern`)

Matches a single code pattern. Supports metavariables (`$VAR`, `$...VAR` for spread).

```yaml
pattern: os.system($CMD)
```

**Ellipsis operator** (`...`) matches zero or more arguments, statements, or expressions:
```yaml
pattern: func($X, ..., $Y)
```

**Deep expression operator** (`<... expr ...>`) matches expr anywhere in a nested expression:
```yaml
pattern: |
  if <... $X ...>:
    ...
```

### 3b. Multiple Patterns (`patterns` — AND logic)

All sub-patterns must match the same code range. This is a conjunction.

```yaml
patterns:
  - pattern: $FUNC($X)
  - metavariable-regex:
      metavariable: $FUNC
      regex: (eval|exec)
```

### 3c. Pattern Either (`pattern-either` — OR logic)

Any sub-pattern can match. This is a disjunction.

```yaml
pattern-either:
  - pattern: eval($X)
  - pattern: exec($X)
```

### 3d. Pattern Negation (`pattern-not`)

Exclude matches. Must be inside `patterns` (AND context).

```yaml
patterns:
  - pattern: $FUNC($X)
  - pattern-not: safe_func($X)
```

### 3e. Pattern Inside/Not-Inside (Scope Restriction)

Restrict matches to appear within (or outside) a containing code structure.

```yaml
patterns:
  - pattern: $X.query($SQL)
  - pattern-inside: |
      def $FUNC(...):
        ...
  - pattern-not-inside: |
      with transaction.atomic():
        ...
```

### 3f. Pattern Regex (`pattern-regex`)

Match using regular expressions on raw text (not AST). Used for `generic`/`regex` language mode.

```yaml
pattern-regex: (?i)password\s*=\s*['"][^'"]+['"]
```

Can be used inside `pattern-either`:
```yaml
pattern-either:
  - pattern-regex: postgresql://.+[?&]sslmode=(disable|allow|prefer)
  - pattern-regex: postgres://.+[?&]ssl=false
```

### 3g. V2.0 Syntax Equivalents

| v1.0 | v2.0 |
|------|------|
| `patterns:` | `all:` |
| `pattern-either:` | `any:` |
| `pattern-not:` | `not:` |
| `pattern-inside:` | `inside:` |
| `pattern-not-inside:` | `not: { inside: ... }` |
| `pattern:` | `pattern:` (unchanged) |
| `pattern-regex:` | `regex:` |

V2.0 also introduces `where:` for conditions and `as:` for binding:
```yaml
match:
  all:
    - pattern: $FUNC($X)
    - inside:
        pattern: |
          def handler(...):
            ...
  where:
    - metavariable: $FUNC
      regex: (eval|exec)
    - focus: $X
  as: $MATCH
```

---

## 4. Metavariable Conditions

Used inside `patterns` to filter matches based on metavariable properties.

### 4a. `metavariable-regex`

Match metavariable text against a regex.

```yaml
- metavariable-regex:
    metavariable: $FUNC
    regex: (eval|exec|compile)
```

### 4b. `metavariable-comparison`

Numeric comparison on metavariable values.

```yaml
- metavariable-comparison:
    metavariable: $DAYS
    comparison: $DAYS < 90
```

### 4c. `metavariable-pattern`

Run a nested pattern match on the code bound to a metavariable.

```yaml
- metavariable-pattern:
    metavariable: $EXPR
    patterns:
      - pattern-not: "..."  # not a string literal
```

### 4d. `metavariable-type` (requires typed analysis)

Match based on the type of a metavariable.

```yaml
- metavariable-type:
    metavariable: $STRB
    type: StringBuilder
```

### 4e. `metavariable-analysis`

Run static analysis on metavariable (entropy, ReDoS).

```yaml
- metavariable-analysis:
    analyzer: entropy
    metavariable: $SECRET
```

---

## 5. Focus Metavariable

Narrow the reported match to a specific metavariable's range.

```yaml
patterns:
  - pattern-inside: |
      def $FUNC(..., $INPUT, ...):
        ...
  - pattern: $INPUT
  - focus-metavariable: $INPUT
```

---

## 6. Taint Mode Specification

**Two syntaxes:**
- **Old (v1.0)**: Top-level `pattern-sources:`, `pattern-sinks:`, `pattern-sanitizers:`, `pattern-propagators:`
- **New (v2.0)**: Single `taint:` block containing `sources:`, `sinks:`, `sanitizers:`, `propagators:`

Both require `mode: taint`.

### 6a. Pattern Sources

Define where tainted data enters. Each source is a formula (pattern/patterns/pattern-either).

```yaml
pattern-sources:
  - patterns:
      - pattern-either:
          - pattern: flask.request.$ANYTHING
          - pattern: |
              @$APP.route(...)
              def $FUNC(..., $ROUTEVAR, ...):
                ...
```

**Labels** (advanced): Tag taint sources for multi-step tracking.
```yaml
pattern-sources:
  - patterns:
      - pattern: (HttpServletRequest $REQ)
    label: INPUT
  - patterns:
      - pattern: $X + $INPUT
    label: CONCAT
    requires: INPUT    # Only applies when INPUT label is present
```

**by-side-effect**: Controls whether taint is added to the matched value or its binding.
```yaml
pattern-sources:
  - by-side-effect: true    # true (default: false) | only | yes | no
    patterns:
      - pattern: $M(..., String $P, ...)
      - focus-metavariable: $P
```

**exact**: Controls sub-expression matching in sources/sinks.
```yaml
pattern-sources:
  - exact: true   # Only the full match is tainted, not sub-expressions
    pattern: source(...)
```

**control**: Marks a source as a control-flow taint (not data-flow).
```yaml
pattern-sources:
  - control: true
    pattern: is_admin()
```

### 6b. Pattern Sinks

Define where tainted data is dangerous.

```yaml
pattern-sinks:
  - patterns:
      - pattern: cursor.execute($SQL)
    requires: CONCAT   # Optional: only trigger on specific labels
```

### 6c. Pattern Sanitizers

Define what removes taint.

```yaml
pattern-sanitizers:
  - pattern-either:
      - pattern: strconv.Atoi(...)
      - pattern: int(...)
      - pattern: sanitize($X)
```

**Options:**
- `not_conflicting: true` — sanitizer doesn't conflict with sources/sinks at same range
- `exact: true` — only the exact match range is sanitized (not sub-expressions)

### 6d. Pattern Propagators

Define how taint flows through data structures.

```yaml
pattern-propagators:
  - pattern: (StringBuilder $S).append($X)
    from: $X
    to: $S
  - pattern: (HashMap $H).put($K, $V)
    from: $V
    to: $H
```

### 6e. Sink-Specific Options

```yaml
pattern-sinks:
  - patterns:
      - pattern: dangerous($X)
    requires: CONCAT          # Only trigger if taint has CONCAT label
    at-exit: true             # Only match at function exit positions
```

### 6f. Taint Options

```yaml
options:
  taint_assume_safe_numbers: true      # Numbers are never tainted
  taint_assume_safe_booleans: true     # Booleans are never tainted
  taint_assume_safe_functions: false   # If true, function calls don't propagate
  taint_assume_safe_indexes: false     # If true, array indexing doesn't propagate
  taint_assume_safe_comparisons: false # If true, comparisons don't propagate
  taint_only_propagate_through_assignments: false
  taint_unify_mvars: false             # Unify metavars across sources and sinks
  interfile: true                      # Cross-file analysis (Pro)
  taint_intrafile: false               # Inter-procedural within file
```

---

## 7. Metadata Fields

Standard metadata fields used across both rule collections:

```yaml
metadata:
  category: security              # security | correctness | best-practice | performance
  cwe:
    - "CWE-89: Improper Neutralization..."
  owasp:
    - A01:2017 - Injection
    - A03:2021 - Injection
  references:
    - https://example.com/docs
  technology:
    - flask
    - python
  subcategory:
    - vuln          # confirmed vulnerability pattern
    - audit         # needs manual review
  confidence: HIGH    # HIGH | MEDIUM | LOW
  likelihood: HIGH    # HIGH | MEDIUM | LOW
  impact: MEDIUM      # HIGH | MEDIUM | LOW
  cwe2022-top25: true
  cwe2021-top25: true
  interfile: true     # Hint that rule benefits from cross-file analysis
  description: "Short one-line description"
```

---

## 8. Optional Rule Fields

```yaml
fix: "replacement_code($X)"          # Autofix pattern
fix-regex:                             # Regex-based autofix
  regex: "old_pattern"
  replacement: "new_pattern"
  count: 1
paths:                                 # File path filtering
  include:
    - "*.py"
    - "src/**"
  exclude:
    - "tests/**"
    - "vendor/**"
options:                               # Engine options
  symbolic_propagation: true           # default: false
  constant_propagation: true           # default: true
  ac_matching: true                    # default: true — associative-commutative
  commutative_boolop: false            # default: false
  symmetric_eq: false                  # default: false
  vardef_assign: true                  # default: true — treat var decl as assign
  flddef_assign: false                 # default: false — treat field def as assign
  implicit_ellipsis: true              # default: true
  arrow_is_function: true              # default: true
  let_is_var: true                     # default: true — JS let/const as var
  generic_engine: spacegrep            # spacegrep or aliengrep
  generic_multiline: true              # default: true (aliengrep only)
  generic_caseless: false              # default: false (aliengrep only)
  taint_assume_safe_numbers: true
  taint_assume_safe_booleans: true
  interfile: true
min-version: "1.50.0"                 # Minimum opengrep version
max-version: "2.0.0"                  # Maximum opengrep version
```

---

## 9. Language Identifiers

### Programming Languages
| ID | Language | File Extensions |
|----|----------|----------------|
| `python` | Python | .py |
| `javascript` | JavaScript | .js, .jsx |
| `typescript` | TypeScript | .ts, .tsx |
| `java` | Java | .java |
| `go` | Go | .go |
| `ruby` | Ruby | .rb |
| `php` | PHP | .php |
| `csharp` / `c#` | C# | .cs |
| `c` | C | .c, .h |
| `rust` | Rust | .rs |
| `scala` | Scala | .scala |
| `kotlin` | Kotlin | .kt |
| `swift` | Swift | .swift |
| `ocaml` | OCaml | .ml, .mli |
| `bash` / `sh` | Bash/Shell | .sh, .bash |
| `clojure` | Clojure | .clj |
| `elixir` | Elixir | .ex, .exs |
| `solidity` | Solidity | .sol |
| `apex` | Apex | .cls |

### Configuration/Markup Languages
| ID | Language | File Extensions |
|----|----------|----------------|
| `hcl` / `terraform` | HCL/Terraform | .tf, .hcl |
| `yaml` | YAML | .yaml, .yml |
| `json` | JSON | .json |
| `html` | HTML | .html, .htm |
| `dockerfile` | Dockerfile | Dockerfile |

### Special Analyzers
| ID | Description |
|----|-------------|
| `generic` | Spacegrep — line-oriented matching for any text |
| `regex` | Pure regex matching, no AST |

---

## 10. Metavariable Syntax

| Syntax | Meaning | Example |
|--------|---------|---------|
| `$VAR` | Single expression/identifier | `$FUNC(...)` |
| `$...VAR` | Zero or more items (spread) | `func($...ARGS)` |
| `...` | Ellipsis — matches anything | `if ...: ...` |
| `"$SQLSTR"` | Metavar inside string literal | `"$SQLSTR" + ...` |

**Typed metavariables** (language-specific):
```yaml
# Go — typed metavariable
pattern: ($REQUEST : *http.Request).$METHOD
# Java — annotated parameter
pattern: |
  $METHOD(..., @RequestBody $TYPE $SOURCE, ...) { ... }
```

---

## 11. Pattern Composition Rules

### AND (patterns) — Intersection
```
patterns:
  - pattern: A           ← required match
  - pattern: B           ← must also match same range
  - pattern-not: C       ← must NOT match
  - pattern-inside: D    ← must be inside D
  - pattern-not-inside: E ← must NOT be inside E
  - metavariable-regex:  ← filter on metavar
  - focus-metavariable:  ← narrow reported range
```

### OR (pattern-either) — Union
```
pattern-either:
  - pattern: A
  - pattern: B
  - patterns:            ← nested AND inside OR
      - pattern: C
      - pattern-not: D
```

### Nesting
AND and OR can be nested arbitrarily:
```yaml
patterns:
  - pattern-either:
      - pattern: eval($X)
      - patterns:
          - pattern: exec($X)
          - pattern-not: exec("...")
  - pattern-inside: |
      def $FUNC(...):
        ...
```

---

## 12. Complete Rule Templates

### Template: Simple Pattern Match
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description of the vulnerability or issue>
    severity: WARNING
    languages: [python]
    metadata:
      category: security
      cwe: "CWE-XXX: Description"
      confidence: MEDIUM
      likelihood: MEDIUM
      impact: MEDIUM
      technology: [<framework>]
      subcategory: [vuln]
      references:
        - https://example.com
    pattern: <dangerous_function>($USER_INPUT)
```

### Template: Pattern with Negation
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description>
    severity: ERROR
    languages: [python]
    metadata:
      category: security
      cwe: "CWE-XXX: Description"
      confidence: HIGH
      likelihood: HIGH
      impact: HIGH
      technology: [<framework>]
      subcategory: [vuln]
    patterns:
      - pattern: $DF.$FN(...)
      - pattern-not: $DF.$FN("...", ...)  # Literal string is safe
      - metavariable-regex:
          metavariable: $FN
          regex: (eval|query)
```

### Template: Taint Analysis
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description of data flow vulnerability>
    severity: ERROR
    languages: [python]
    mode: taint
    metadata:
      category: security
      cwe: "CWE-89: SQL Injection"
      owasp:
        - A03:2021 - Injection
      confidence: HIGH
      likelihood: HIGH
      impact: HIGH
      subcategory: [vuln]
    options:
      taint_assume_safe_numbers: true
      taint_assume_safe_booleans: true
    pattern-sources:
      - patterns:
          - pattern-either:
              - pattern: flask.request.$ANYTHING
              - pattern: request.args.get(...)
    pattern-sinks:
      - patterns:
          - pattern-either:
              - pattern: cursor.execute($SQL)
              - pattern: db.engine.execute($SQL)
    pattern-sanitizers:
      - pattern-either:
          - pattern: int(...)
          - pattern: escape(...)
```

### Template: Taint with Labels
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description>
    severity: ERROR
    languages: [java]
    mode: taint
    metadata:
      category: security
      cwe: "CWE-78: OS Command Injection"
    pattern-sources:
      - patterns:
          - pattern: (HttpServletRequest $REQ)
        label: INPUT
      - patterns:
          - pattern: $X + $SOURCE
        label: CONCAT
        requires: INPUT
    pattern-propagators:
      - pattern: (StringBuilder $S).append($X)
        from: $X
        to: $S
    pattern-sinks:
      - patterns:
          - pattern: Runtime.getRuntime().exec(...)
        requires: CONCAT
    pattern-sanitizers:
      - pattern: sanitize(...)
```

### Template: Concurrency Bug (Go)
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description of race condition>
    severity: ERROR
    languages: [go]
    metadata:
      category: security
      cwe: "CWE-362: Race Condition"
      subcategory: [vuln]
      confidence: MEDIUM
      likelihood: HIGH
      impact: MEDIUM
    patterns:
      - pattern: |
          $SLICE = append($SLICE, $ITEM)
      - pattern-inside: |
          for ... {
            ...
            go func(...) {
              ...
            }(...)
          }
      - pattern-not-inside: |
          $MUTEX.Lock()
          ...
          $MUTEX.Unlock()
```

### Template: Terraform/HCL Configuration
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description of misconfiguration>
    severity: WARNING
    languages: [hcl]
    metadata:
      category: best-practice
      technology: [terraform, aws]
    patterns:
      - pattern: resource
      - pattern-inside: |
          resource "aws_s3_bucket" "..." {
            ...
          }
      - pattern-not-inside: |
          resource "aws_s3_bucket" "..." {
            ...
            versioning {
              enabled = true
            }
            ...
          }
```

### Template: Generic/Regex (Any file type)
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description>
    severity: WARNING
    languages: [regex]
    metadata:
      category: security
      cwe: "CWE-295: Improper Certificate Validation"
      confidence: HIGH
    pattern-either:
      - pattern-regex: (?i)sslmode=(disable|allow|prefer)
      - pattern-regex: (?i)ssl=false
```

### Template: GitHub Actions Security
```yaml
rules:
  - id: <rule-id>
    message: >-
      <Description of CI/CD risk>
    severity: ERROR
    languages: [yaml]
    metadata:
      category: security
      cwe: "CWE-94: Code Injection"
      technology: [github-actions]
    patterns:
      - pattern: |
          run: ...
      - pattern-regex: \$\{\{\s*github\.event\..*\}\}
      - pattern-inside: |
          on:
            ...
            pull_request_target:
              ...
```

---

## 13. Common Vulnerability Patterns by Language

### Python
- SQL injection: `cursor.execute(f"SELECT ...")`, `"SELECT" + user_input`
- Command injection: `os.system($CMD)`, `subprocess.call($CMD, shell=True)`
- Deserialization: `pickle.loads(...)`, `yaml.load(...)`
- SSRF: `requests.get($URL)` where `$URL` is user-controlled

### Java
- SQL injection: `Statement.execute($SQL)` with string concatenation
- Command injection: `Runtime.getRuntime().exec(...)` with user input
- XXE: `DocumentBuilderFactory` without disabling external entities
- Deserialization: `ObjectInputStream.readObject()`

### Go
- SQL injection: `db.Query("SELECT" + userInput)`
- Race conditions: goroutine access to shared maps/slices
- Path traversal: `filepath.Join(base, userInput)` without validation

### JavaScript
- XSS: `innerHTML = userInput`, `dangerouslySetInnerHTML`
- Prototype pollution: `merge(target, userInput)`
- Command injection: `child_process.exec(userInput)`

### Terraform/HCL
- Missing encryption: `encrypted = false` or missing `encryption` block
- Overly permissive: `cidr_blocks = ["0.0.0.0/0"]`
- Missing logging: absent `logging` configuration blocks
- Retention periods: `days < 90` with `metavariable-comparison`
