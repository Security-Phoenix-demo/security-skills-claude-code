#!/usr/bin/env python3
"""Structural validation for this plugin marketplace.

`claude plugin validate` checks manifest schema and skill frontmatter shape. It does
not check that the pieces fit together, and every bug that has actually broken this
repository lived in that gap. Verified against the real CLI:

    marketplace source -> a directory that does not exist   PASSES
    two skills sharing one name                             PASSES
    SKILL.md name: not matching its directory               PASSES
    SKILL.md citing a references/ file that is not there    PASSES

So run both. This script covers the fit; the CLI covers the schema.

Stdlib only, so it runs anywhere with python3 and no install step.

    python3 scripts/validate-marketplace.py            # from the repo root
    python3 scripts/validate-marketplace.py --quiet    # errors only

Exit 0 clean, 1 on any error. Warnings never fail the run.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Agent Skills spec: only these keys travel to claude.ai and the Skills API. Anything
# else (argument-hint, context, disable-model-invocation) is Claude Code-only and makes
# the upload fail with a hard error rather than being ignored.
SKILL_FRONTMATTER_KEYS = {"name", "description", "allowed-tools"}

# Commands may use the Claude Code-only keys — they never leave Claude Code.
COMMAND_FRONTMATTER_KEYS = {
    "description", "argument-hint", "allowed-tools", "model",
    "disable-model-invocation", "context", "name",
}

NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")

errors: list[str] = []
warnings: list[str] = []


def err(where: str, msg: str) -> None:
    errors.append(f"{where}: {msg}")


def warn(where: str, msg: str) -> None:
    warnings.append(f"{where}: {msg}")


def read_json(path: Path, where: str):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        err(where, "file is missing")
    except json.JSONDecodeError as e:
        err(where, f"invalid JSON — {e}")
    return None


def frontmatter(path: Path) -> tuple[dict[str, str], str] | None:
    """Top-level keys from a --- fenced YAML block, plus the body.

    Deliberately minimal: no PyYAML, so CI needs no install step. It understands the
    two shapes these files use — `key: value` and a `key: >` / `key: |` folded block —
    which is all the spec allows at the top level.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        err(str(path), f"unreadable — {e}")
        return None

    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None

    block = text[text.find("\n", 3) + 1 : end + 1]
    body = text[end + 4 :]

    keys: dict[str, str] = {}
    current: str | None = None
    for line in block.split("\n"):
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$", line)
        if m:
            current = m.group(1)
            keys[current] = m.group(2).strip()
        elif current and line.startswith((" ", "\t")):
            keys[current] = (keys[current] + " " + line.strip()).strip()
    # Folded-block markers are not content.
    for k, v in keys.items():
        if v in (">", "|", ">-", "|-", ""):
            keys[k] = ""
    return keys, body


def check_name(where: str, name: str, dirname: str, kind: str) -> None:
    if not name:
        err(where, f"{kind} has no `name:`")
        return
    if name != dirname:
        err(
            where,
            f"`name: {name}` does not match its directory `{dirname}` — the directory "
            f"name is the slash command, so these must be identical",
        )
    if not NAME_RE.match(name):
        err(where, f"`{name}` must be lowercase, digits and single hyphens only")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".", help="repository root (default: cwd)")
    ap.add_argument("--quiet", action="store_true", help="print errors only")
    args = ap.parse_args()
    root = Path(args.root).resolve()

    # ---------------------------------------------------------------- marketplace
    mkt_path = root / ".claude-plugin" / "marketplace.json"
    mkt = read_json(mkt_path, ".claude-plugin/marketplace.json")
    listed: dict[str, dict] = {}

    if mkt is not None:
        for field in ("name", "description", "owner", "plugins"):
            if field not in mkt:
                err("marketplace.json", f"missing required field `{field}`")

        for entry in mkt.get("plugins", []):
            name = entry.get("name", "")
            where = f"marketplace.json[{name or '?'}]"
            if not name:
                err(where, "plugin entry has no `name`")
                continue
            if name in listed:
                err(where, "listed twice in marketplace.json")
            listed[name] = entry

            if not entry.get("description"):
                err(where, "no `description` — this is what a user decides from")

            src = entry.get("source", "")
            if not src:
                err(where, "no `source`")
                continue
            src_dir = (root / src).resolve()
            if not src_dir.is_dir():
                # claude plugin validate does NOT catch this.
                err(where, f"`source` points at `{src}`, which is not a directory")
            elif not (src_dir / ".claude-plugin" / "plugin.json").is_file():
                err(where, f"`{src}` has no .claude-plugin/plugin.json, so it is not a plugin")
            elif src_dir != (root / "plugins" / name).resolve():
                # Swapping two entries' `source` values passes every other check in this
                # file: both directories exist, both hold a manifest, and the listed set
                # still matches the on-disk set. Installing one plugin loads the other.
                err(
                    where,
                    f"`source` is `{src}` but the entry is named `{name}` — it must point "
                    f"at `plugins/{name}`, or installing this entry loads a different plugin",
                )

    # ---------------------------------------------------------------- plugins
    plugins_dir = root / "plugins"
    if not plugins_dir.is_dir():
        err("plugins/", "directory is missing")
        return report(args.quiet)

    on_disk = sorted(d for d in plugins_dir.iterdir() if d.is_dir())

    for name in sorted(set(listed) - {d.name for d in on_disk}):
        err(f"marketplace.json[{name}]", "listed but there is no such directory in plugins/")
    for d in on_disk:
        if d.name not in listed:
            err(f"plugins/{d.name}", "not listed in marketplace.json, so nobody can install it")

    # slash names must be unique across every plugin, not just within one
    slash: dict[str, list[str]] = {}

    # Agents are dispatched by subagent_type, not by a slash name, so an agent may
    # legitimately share a name with the skill it backs — security-reviewer is both,
    # deliberately. Two *agents* sharing one name is the real collision, and it needs
    # its own namespace to be visible at all.
    agent_names: dict[str, list[str]] = {}

    for pdir in on_disk:
        pname = pdir.name
        man_path = pdir / ".claude-plugin" / "plugin.json"
        man = read_json(man_path, f"plugins/{pname}/.claude-plugin/plugin.json")

        if man is not None:
            where = f"plugins/{pname}/.claude-plugin/plugin.json"
            if man.get("name") != pname:
                err(where, f"`name: {man.get('name')}` does not match the directory `{pname}`")
            if not man.get("description"):
                err(where, "no `description`")
            if not man.get("version"):
                warn(where, "no `version` — /plugin update has nothing to compare")
            entry = listed.get(pname)
            if entry and entry.get("description") and man.get("description"):
                if entry["description"].strip() != man["description"].strip():
                    warn(
                        where,
                        "description differs from the marketplace entry — users read the "
                        "marketplace text before installing and the manifest text in "
                        "`claude plugin details` afterwards, so drift between them misleads",
                    )

        # ------------------------------------------------------------ skills
        skills_dir = pdir / "skills"
        if not skills_dir.is_dir():
            warn(f"plugins/{pname}", "no skills/ directory")
        else:
            for sdir in sorted(d for d in skills_dir.iterdir() if d.is_dir()):
                rel = f"plugins/{pname}/skills/{sdir.name}"
                skill_md = sdir / "SKILL.md"
                if not skill_md.is_file():
                    err(rel, "no SKILL.md")
                    continue

                fm = frontmatter(skill_md)
                if fm is None:
                    err(f"{rel}/SKILL.md", "no --- fenced YAML frontmatter, so it will never load")
                    continue
                keys, body = fm

                check_name(f"{rel}/SKILL.md", keys.get("name", ""), sdir.name, "skill")

                if not keys.get("description"):
                    err(f"{rel}/SKILL.md", "`description` is empty — nothing will ever trigger it")
                elif len(keys["description"]) > 3000:
                    warn(
                        f"{rel}/SKILL.md",
                        f"description is {len(keys['description'])} chars; it is added to "
                        f"every session, so keep it tight",
                    )

                extra = set(keys) - SKILL_FRONTMATTER_KEYS
                if extra:
                    err(
                        f"{rel}/SKILL.md",
                        f"frontmatter key(s) {sorted(extra)} are outside the Agent Skills spec; "
                        f"they break the claude.ai upload with a hard error",
                    )

                slash.setdefault(keys.get("name") or sdir.name, []).append(f"{rel} (skill)")

                # Files the skill tells the model to read must exist. The CLI does not
                # check this, and it is how the readiness bundle shipped broken.
                #
                # The lookbehind matters: a skill may legitimately talk about paths it
                # *writes* into the user's repo (project-documenter emits
                # .github/scripts/*.py). Only a bare references/ or scripts/ prefix is
                # a claim about this skill's own directory.
                for ref in set(
                    re.findall(r"(?<![\w./-])(?:references|scripts|assets)/[A-Za-z0-9_./-]+", body)
                ):
                    ref = ref.rstrip(".,;:)`\"'")
                    if "*" in ref or "{" in ref:
                        continue
                    if not (sdir / ref).exists():
                        err(f"{rel}/SKILL.md", f"references `{ref}`, which does not exist")

        # ------------------------------------------------------------ commands
        cmd_dir = pdir / "commands"
        if cmd_dir.is_dir():
            for cmd in sorted(cmd_dir.glob("*.md")):
                rel = f"plugins/{pname}/commands/{cmd.name}"
                fm = frontmatter(cmd)
                if fm is None:
                    err(rel, "no --- fenced YAML frontmatter")
                    continue
                keys, _ = fm
                if not keys.get("description"):
                    err(rel, "`description` is empty")
                extra = set(keys) - COMMAND_FRONTMATTER_KEYS
                if extra:
                    warn(rel, f"unrecognised frontmatter key(s) {sorted(extra)}")
                slash.setdefault(cmd.stem, []).append(f"{rel} (command)")

        # ------------------------------------------------------------ agents
        for agent in sorted((pdir / "agents").glob("*.md")) if (pdir / "agents").is_dir() else []:
            rel = f"plugins/{pname}/agents/{agent.name}"
            fm = frontmatter(agent)
            if fm is None:
                err(rel, "no --- fenced YAML frontmatter")
                aname = agent.stem
            else:
                if not fm[0].get("description"):
                    err(rel, "`description` is empty")
                aname = fm[0].get("name") or agent.stem
            agent_names.setdefault(aname, []).append(rel)

    # ---------------------------------------------------------------- clashes
    for name, owners in sorted(slash.items()):
        if len(owners) > 1:
            err(
                f"slash name /{name}",
                "claimed by " + ", ".join(owners)
                + " — two components cannot share a slash name",
            )

    for name, owners in sorted(agent_names.items()):
        if len(owners) > 1:
            err(
                f"agent `{name}`",
                "defined by " + ", ".join(owners)
                + " — subagent_type would be ambiguous and the last plugin loaded wins",
            )

    # ---------------------------------------------------------------- scripts
    for sh in sorted(root.glob("plugins/**/*.sh")):
        rel = sh.relative_to(root)
        r = subprocess.run(["bash", "-n", str(sh)], capture_output=True, text=True)
        if r.returncode != 0:
            err(str(rel), f"bash syntax error — {r.stderr.strip().splitlines()[:1]}")
        if not os.access(sh, os.X_OK):
            err(str(rel), "not executable — commit the bit with `git update-index --chmod=+x`")

    # ---------------------------------------------------------------- hygiene
    for junk in sorted(root.rglob(".DS_Store")):
        if ".git/" not in str(junk):
            err(str(junk.relative_to(root)), "committed .DS_Store")
    # A force-added .env at the repo root, under scripts/, or in any other tracked
    # directory is the same leak. Globbing plugins/ only made this a false clean.
    found_env = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in (".git", "node_modules", ".venv")]
        if ".env" in filenames:
            found_env.append((Path(dirpath) / ".env").relative_to(root).as_posix())
    for rel_env in sorted(found_env):
        err(rel_env, "a real .env must never be committed — ship .env.example")

    # ---------------------------------------------------------------- doc links
    for md in sorted(list(root.glob("*.md")) + list(root.glob("plugins/*/README.md"))):
        rel = md.relative_to(root)
        text = md.read_text(encoding="utf-8", errors="ignore")
        for link in re.findall(r"!\[[^\]]*\]\(([^)]+)\)", text):
            if link.startswith(("http://", "https://", "data:")):
                continue
            target = (md.parent / link.split("#")[0].replace("%20", " ")).resolve()
            if not target.exists():
                err(str(rel), f"image link `{link}` does not resolve")

    return report(args.quiet)


def report(quiet: bool) -> int:
    if warnings and not quiet:
        print(f"\n{len(warnings)} warning(s):")
        for w in warnings:
            print(f"  ! {w}")
    if errors:
        print(f"\n{len(errors)} error(s):")
        for e in errors:
            print(f"  x {e}")
        print("\nFAILED")
        return 1
    if not quiet:
        print("\nOK — marketplace, plugins, skills, commands, agents and scripts all consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
