#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


CODEX_DIR = Path.home() / ".codex"
STATE_DB = CODEX_DIR / "state_5.sqlite"
LOGS_DB = CODEX_DIR / "logs_2.sqlite"
GOALS_DB = CODEX_DIR / "goals_1.sqlite"
HISTORY_FILE = CODEX_DIR / "history.jsonl"
SESSION_INDEX_FILE = CODEX_DIR / "session_index.jsonl"

PROTECTED_PATHS = {
    CODEX_DIR / "auth.json",
    CODEX_DIR / "config.toml",
    CODEX_DIR / "memories",
    CODEX_DIR / "skills",
    CODEX_DIR / "rules",
    CODEX_DIR / "hooks",
    CODEX_DIR / "automations",
    CODEX_DIR / "AGENTS.md",
}

MUTABLE_ROOTS = {
    CODEX_DIR / "sessions",
    CODEX_DIR / "archived_sessions",
    CODEX_DIR / "shell_snapshots",
    CODEX_DIR / ".tmp",
    CODEX_DIR / "log",
    CODEX_DIR / "browser",
    CODEX_DIR / "computer-use",
    CODEX_DIR / "backups",
    CODEX_DIR / "ambient-suggestions",
    CODEX_DIR / "generated_images",
    CODEX_DIR / "plugins" / "cache",
}

CATEGORY_PATHS = {
    2: [
        CODEX_DIR / "shell_snapshots",
        CODEX_DIR / ".tmp",
        CODEX_DIR / "log",
        CODEX_DIR / "browser",
        CODEX_DIR / "computer-use",
        CODEX_DIR / "backups",
        CODEX_DIR / "ambient-suggestions",
    ],
    3: [
        CODEX_DIR / "generated_images",
    ],
    4: [
        CODEX_DIR / "plugins" / "cache",
    ],
}


@dataclass
class ThreadRecord:
    thread_id: str
    updated_at: int
    archived: int
    rollout_path: str
    title: str


def fmt_bytes(num: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    size = float(num)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            return f"{size:.1f}{unit}"
        size /= 1024
    return f"{num}B"


def path_size(path: Path) -> int:
    if not path.exists():
        return 0
    if path.is_file():
        return path.stat().st_size
    total = 0
    for root, _, files in os.walk(path):
        for name in files:
            try:
                total += (Path(root) / name).stat().st_size
            except FileNotFoundError:
                continue
    return total


def count_old_files(base: Path, cutoff_ts: int) -> tuple[int, int]:
    if not base.exists():
        return (0, 0)
    count = 0
    bytes_total = 0
    for root, _, files in os.walk(base):
        for name in files:
            item = Path(root) / name
            try:
                st = item.stat()
            except FileNotFoundError:
                continue
            if int(st.st_mtime) < cutoff_ts:
                count += 1
                bytes_total += st.st_size
    return (count, bytes_total)


def iso_utc(ts: int | None) -> str:
    if ts is None:
        return "-"
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def parse_age(value: str) -> int | None:
    if value == "all":
        return None
    raw = value.strip().lower()
    if raw.endswith("h"):
        hours = int(raw[:-1])
        if hours < 0:
            raise ValueError("age must be non-negative")
        return hours * 3600
    if raw.endswith("d"):
        days = int(raw[:-1])
        if days < 0:
            raise ValueError("age must be non-negative")
        return days * 86400
    days = int(raw)
    if days < 0:
        raise ValueError("age must be non-negative or 'all'")
    return days * 86400


def cutoff_from_age(age_seconds: int | None) -> int:
    if age_seconds is None:
        return 2**63 - 1
    return int(time.time()) - age_seconds


def describe_age(age_seconds: int | None) -> str:
    if age_seconds is None:
        return "all history"
    if age_seconds % 86400 == 0:
        days = age_seconds // 86400
        return f"older than {days} day(s)"
    if age_seconds % 3600 == 0:
        hours = age_seconds // 3600
        return f"older than {hours} hour(s)"
    return f"older than {age_seconds} second(s)"


def connect(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def load_old_threads(cutoff_ts: int) -> list[ThreadRecord]:
    query = """
        SELECT id, updated_at, archived, rollout_path, title
        FROM threads
        WHERE updated_at < ?
        ORDER BY updated_at
    """
    with connect(STATE_DB) as conn:
        rows = conn.execute(query, (cutoff_ts,)).fetchall()
    return [
        ThreadRecord(
            thread_id=row["id"],
            updated_at=row["updated_at"],
            archived=row["archived"],
            rollout_path=row["rollout_path"],
            title=row["title"],
        )
        for row in rows
    ]


def load_all_thread_counts() -> dict[str, int]:
    with connect(STATE_DB) as conn:
        total = conn.execute("SELECT COUNT(*) FROM threads").fetchone()[0]
        archived = conn.execute("SELECT COUNT(*) FROM threads WHERE archived = 1").fetchone()[0]
    return {"total": total, "archived": archived, "active": total - archived}


def age_breakdown() -> list[tuple[str, int]]:
    now = int(time.time())
    buckets = [7, 10, 14, 30, 60, 90]
    with connect(STATE_DB) as conn:
        rows = []
        for days in buckets:
            cutoff = now - days * 86400
            count = conn.execute(
                "SELECT COUNT(*) FROM threads WHERE updated_at < ?",
                (cutoff,),
            ).fetchone()[0]
            rows.append((str(days), count))
    return rows


def count_jsonl_entries(path: Path, ids: set[str], id_key: str) -> int:
    if not path.exists() or not ids:
        return 0
    count = 0
    with path.open() as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get(id_key) in ids:
                count += 1
    return count


def collect_old_artifacts(categories: int, cutoff_ts: int) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for level in range(2, categories + 1):
        for base in CATEGORY_PATHS.get(level, []):
            count, bytes_total = count_old_files(base, cutoff_ts)
            entries.append({
                "path": str(base),
                "count": count,
                "bytes": bytes_total,
                "category": level,
            })
    return entries


def audit(age_seconds: int | None) -> int:
    cutoff_ts = cutoff_from_age(age_seconds)
    old_threads = load_old_threads(cutoff_ts)
    old_ids = {t.thread_id for t in old_threads}
    existing_rollouts = sum(1 for t in old_threads if Path(t.rollout_path).exists())
    missing_rollouts = len(old_threads) - existing_rollouts
    rollout_bytes = sum(path_size(Path(t.rollout_path)) for t in old_threads if Path(t.rollout_path).exists())

    with connect(LOGS_DB) as conn:
        if old_ids:
            placeholders = ",".join("?" for _ in old_ids)
            log_rows = conn.execute(
                f"SELECT COUNT(*) FROM logs WHERE thread_id IN ({placeholders})",
                tuple(old_ids),
            ).fetchone()[0]
        else:
            log_rows = 0
        old_threadless = conn.execute(
            "SELECT COUNT(*) FROM logs WHERE thread_id IS NULL AND ts < ?",
            (cutoff_ts,),
        ).fetchone()[0]

    with connect(STATE_DB) as conn:
        if old_ids:
            placeholders = ",".join("?" for _ in old_ids)
            edge_rows = conn.execute(
                f"SELECT COUNT(*) FROM thread_spawn_edges WHERE parent_thread_id IN ({placeholders}) OR child_thread_id IN ({placeholders})",
                tuple(old_ids) + tuple(old_ids),
            ).fetchone()[0]
            tool_rows = conn.execute(
                f"SELECT COUNT(*) FROM thread_dynamic_tools WHERE thread_id IN ({placeholders})",
                tuple(old_ids),
            ).fetchone()[0]
        else:
            edge_rows = 0
            tool_rows = 0

    with connect(GOALS_DB) as conn:
        if old_ids:
            placeholders = ",".join("?" for _ in old_ids)
            goal_rows = conn.execute(
                f"SELECT COUNT(*) FROM thread_goals WHERE thread_id IN ({placeholders})",
                tuple(old_ids),
            ).fetchone()[0]
        else:
            goal_rows = 0

    history_rows = count_jsonl_entries(HISTORY_FILE, old_ids, "session_id")
    index_rows = count_jsonl_entries(SESSION_INDEX_FILE, old_ids, "id")
    counts = load_all_thread_counts()

    print(f"Codex dir: {CODEX_DIR}")
    print(f"Retention cutoff: {describe_age(age_seconds)}")
    print("")
    print("Footprint")
    for label, path in [
        ("sessions", CODEX_DIR / "sessions"),
        ("archived_sessions", CODEX_DIR / "archived_sessions"),
        ("history.jsonl", HISTORY_FILE),
        ("session_index.jsonl", SESSION_INDEX_FILE),
        ("logs_2.sqlite", LOGS_DB),
        ("state_5.sqlite", STATE_DB),
        ("goals_1.sqlite", GOALS_DB),
    ]:
        print(f"  {label:20} {fmt_bytes(path_size(path))}")

    print("")
    print("Thread counts")
    print(f"  total threads:    {counts['total']}")
    print(f"  active threads:   {counts['active']}")
    print(f"  archived threads: {counts['archived']}")

    print("")
    print("Age breakdown")
    for days, count in age_breakdown():
        print(f"  older than {days:>2} days: {count}")

    print("")
    print("Purge scope")
    print(f"  old thread rows:          {len(old_threads)}")
    print(f"  rollout files present:    {existing_rollouts}")
    print(f"  rollout files missing:    {missing_rollouts}")
    print(f"  rollout bytes reclaimable:{fmt_bytes(rollout_bytes)}")
    print(f"  history.jsonl rows:       {history_rows}")
    print(f"  session_index rows:       {index_rows}")
    print(f"  thread_spawn_edges rows:  {edge_rows}")
    print(f"  thread_dynamic_tools rows:{tool_rows}")
    print(f"  thread_goals rows:        {goal_rows}")
    print(f"  logs rows for old threads:{log_rows}")
    print(f"  old threadless log rows:  {old_threadless}")

    if old_threads:
        print("")
        print("Oldest matching threads")
        for thread in old_threads[:10]:
            print(
                f"  {thread.thread_id}  archived={thread.archived}  "
                f"updated={iso_utc(thread.updated_at)}  title={thread.title[:100]}"
            )
    return 0


def ensure_safe_path(path: Path) -> None:
    if path in {HISTORY_FILE, SESSION_INDEX_FILE, STATE_DB, LOGS_DB, GOALS_DB}:
        return
    for mutable_root in MUTABLE_ROOTS:
        try:
            path.relative_to(mutable_root)
            return
        except ValueError:
            continue
    for protected in PROTECTED_PATHS:
        try:
            path.relative_to(protected)
            raise RuntimeError(f"refusing to touch protected path: {path}")
        except ValueError:
            continue
    raise RuntimeError(f"refusing to touch path outside approved Codex purge roots: {path}")


def write_jsonl_filtered(path: Path, ids: set[str], id_key: str, dry_run: bool) -> tuple[int, int]:
    if not path.exists():
        return (0, 0)
    removed = 0
    kept_lines: list[str] = []
    with path.open() as fh:
        for line in fh:
            raw = line.rstrip("\n")
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                kept_lines.append(raw)
                continue
            if obj.get(id_key) in ids:
                removed += 1
                continue
            kept_lines.append(raw)
    if not dry_run:
        tmp = path.with_suffix(path.suffix + ".tmp")
        with tmp.open("w") as fh:
            for line in kept_lines:
                fh.write(line + "\n")
        tmp.replace(path)
    return removed, len(kept_lines)


def backup_configs() -> Path:
    stamp = datetime.now(tz=timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_dir = CODEX_DIR / "backups" / f"codex-purge-{stamp}"
    backup_dir.mkdir(parents=True, exist_ok=True)
    for item in ["auth.json", "config.toml", "AGENTS.md"]:
        src = CODEX_DIR / item
        if src.exists():
            shutil.copy2(src, backup_dir / item)
    return backup_dir


def delete_old_files(base: Path, cutoff_ts: int, dry_run: bool) -> tuple[int, int]:
    if not base.exists():
        return (0, 0)
    deleted = 0
    bytes_total = 0
    for root, _, files in os.walk(base):
        for name in files:
            item = Path(root) / name
            try:
                st = item.stat()
            except FileNotFoundError:
                continue
            if int(st.st_mtime) >= cutoff_ts:
                continue
            ensure_safe_path(item)
            deleted += 1
            bytes_total += st.st_size
            if not dry_run:
                item.unlink(missing_ok=True)
    return deleted, bytes_total


def checkpoint_db(path: Path) -> None:
    with connect(path) as conn:
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")


def purge(age_seconds: int | None, categories: int, dry_run: bool, yes: bool, backup: bool) -> int:
    cutoff_ts = cutoff_from_age(age_seconds)
    old_threads = load_old_threads(cutoff_ts)
    old_ids = [t.thread_id for t in old_threads]
    id_set = set(old_ids)

    if not dry_run and not yes:
        print("Refusing to execute without --yes. Use --dry-run first.", file=sys.stderr)
        return 2

    if backup and not dry_run:
        backup_dir = backup_configs()
        print(f"Backed up config files to {backup_dir}")

    rollout_deleted = 0
    rollout_bytes = 0
    for thread in old_threads:
        path = Path(thread.rollout_path)
        if path.exists():
            ensure_safe_path(path)
            rollout_deleted += 1
            rollout_bytes += path.stat().st_size
            if not dry_run:
                path.unlink()

    history_removed, _ = write_jsonl_filtered(HISTORY_FILE, id_set, "session_id", dry_run)
    index_removed, _ = write_jsonl_filtered(SESSION_INDEX_FILE, id_set, "id", dry_run)

    log_thread_rows = 0
    log_old_threadless_rows = 0
    edge_rows = 0
    tool_rows = 0
    goal_rows = 0
    thread_rows = len(old_threads)

    if old_ids:
        placeholders = ",".join("?" for _ in old_ids)
        with connect(STATE_DB) as conn:
            edge_rows = conn.execute(
                f"SELECT COUNT(*) FROM thread_spawn_edges WHERE parent_thread_id IN ({placeholders}) OR child_thread_id IN ({placeholders})",
                tuple(old_ids) + tuple(old_ids),
            ).fetchone()[0]
            tool_rows = conn.execute(
                f"SELECT COUNT(*) FROM thread_dynamic_tools WHERE thread_id IN ({placeholders})",
                tuple(old_ids),
            ).fetchone()[0]
            if not dry_run:
                conn.execute(
                    f"DELETE FROM thread_spawn_edges WHERE parent_thread_id IN ({placeholders}) OR child_thread_id IN ({placeholders})",
                    tuple(old_ids) + tuple(old_ids),
                )
                conn.execute(
                    f"DELETE FROM thread_dynamic_tools WHERE thread_id IN ({placeholders})",
                    tuple(old_ids),
                )
                conn.execute(
                    f"DELETE FROM threads WHERE id IN ({placeholders})",
                    tuple(old_ids),
                )
                conn.commit()

        with connect(GOALS_DB) as conn:
            goal_rows = conn.execute(
                f"SELECT COUNT(*) FROM thread_goals WHERE thread_id IN ({placeholders})",
                tuple(old_ids),
            ).fetchone()[0]
            if not dry_run:
                conn.execute(
                    f"DELETE FROM thread_goals WHERE thread_id IN ({placeholders})",
                    tuple(old_ids),
                )
                conn.commit()

        with connect(LOGS_DB) as conn:
            log_thread_rows = conn.execute(
                f"SELECT COUNT(*) FROM logs WHERE thread_id IN ({placeholders})",
                tuple(old_ids),
            ).fetchone()[0]
            log_old_threadless_rows = conn.execute(
                "SELECT COUNT(*) FROM logs WHERE thread_id IS NULL AND ts < ?",
                (cutoff_ts,),
            ).fetchone()[0]
            if not dry_run:
                conn.execute(
                    f"DELETE FROM logs WHERE thread_id IN ({placeholders})",
                    tuple(old_ids),
                )
                conn.execute(
                    "DELETE FROM logs WHERE thread_id IS NULL AND ts < ?",
                    (cutoff_ts,),
                )
                conn.commit()
    else:
        with connect(LOGS_DB) as conn:
            log_old_threadless_rows = conn.execute(
                "SELECT COUNT(*) FROM logs WHERE thread_id IS NULL AND ts < ?",
                (cutoff_ts,),
            ).fetchone()[0]
            if not dry_run:
                conn.execute(
                    "DELETE FROM logs WHERE thread_id IS NULL AND ts < ?",
                    (cutoff_ts,),
                )
                conn.commit()

    aux_deleted = 0
    aux_bytes = 0
    if categories >= 2:
        for level in range(2, categories + 1):
            for base in CATEGORY_PATHS.get(level, []):
                deleted, bytes_total = delete_old_files(base, cutoff_ts, dry_run)
                aux_deleted += deleted
                aux_bytes += bytes_total

    if not dry_run:
        checkpoint_db(STATE_DB)
        checkpoint_db(LOGS_DB)
        checkpoint_db(GOALS_DB)

    print(f"{'Dry run' if dry_run else 'Executed'} purge for {describe_age(age_seconds)}")
    print(f"  thread rows:            {thread_rows}")
    print(f"  rollout files:          {rollout_deleted} ({fmt_bytes(rollout_bytes)})")
    print(f"  history.jsonl rows:     {history_removed}")
    print(f"  session_index rows:     {index_removed}")
    print(f"  thread_spawn_edges:     {edge_rows}")
    print(f"  thread_dynamic_tools:   {tool_rows}")
    print(f"  thread_goals:           {goal_rows}")
    print(f"  logs for deleted threads:{log_thread_rows}")
    print(f"  old threadless logs:    {log_old_threadless_rows}")
    print(f"  aux files:              {aux_deleted} ({fmt_bytes(aux_bytes)})")
    return 0


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    audit_parser = sub.add_parser("audit")
    audit_parser.add_argument("--age", default="10")

    purge_parser = sub.add_parser("purge")
    purge_parser.add_argument("--age", required=True)
    purge_parser.add_argument("--categories", type=int, choices=[1, 2, 3, 4], default=1)
    purge_parser.add_argument("--dry-run", action="store_true")
    purge_parser.add_argument("--yes", action="store_true")
    purge_parser.add_argument("--backup", action="store_true")

    args = parser.parse_args(list(argv))
    age_seconds = parse_age(args.age)

    if args.command == "audit":
        return audit(age_seconds)
    if args.command == "purge":
        return purge(age_seconds, args.categories, args.dry_run, args.yes, args.backup)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
