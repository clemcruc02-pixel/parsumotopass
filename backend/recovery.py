"""Create verified SQLite snapshots and restore to a new database path."""

import argparse
from contextlib import closing
import os
from pathlib import Path
import sqlite3
from tempfile import NamedTemporaryFile


def copy_database(source, destination, *, restore=False):
    source = Path(source).resolve(strict=True)
    destination = Path(destination)
    if destination.exists():
        raise FileExistsError(destination)
    with NamedTemporaryFile(dir=destination.parent, prefix=".motopass-copy-", delete=False) as file:
        temporary = Path(file.name)
    try:
        with (
            closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True, timeout=5)) as src,
            closing(sqlite3.connect(temporary)) as dest,
        ):
            src.backup(dest)
            if dest.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
                raise ValueError("SQLite integrity check failed.")
            if dest.execute("PRAGMA foreign_key_check").fetchone() is not None:
                raise ValueError("SQLite foreign key check failed.")
            for table in ("applications", "documents", "students", "sessions"):
                dest.execute(f"SELECT 1 FROM {table} LIMIT 1").fetchone()
            if restore:
                with dest:
                    dest.execute("DELETE FROM sessions")
        # Publish the verified copy without replacing an existing destination.
        if os.name == "nt":
            temporary.rename(destination)
        else:
            os.link(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("backup", "restore"))
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        copy_database(args.source, args.destination, restore=args.operation == "restore")
    except (OSError, ValueError, sqlite3.Error) as error:
        parser.exit(1, f"Recovery operation failed: {error}\n")
    print("Verified SQLite copy created.")


if __name__ == "__main__":
    main()
