#!/usr/bin/env python3
"""Create and extract mod release archives (real zip; also accepts legacy tar-as-.zip)."""

from __future__ import annotations

import argparse
import sys
import tarfile
import zipfile
from pathlib import Path


def extract_tar(archive: tarfile.TarFile, dest_dir: Path) -> None:
    if sys.version_info >= (3, 12):
        archive.extractall(dest_dir, filter="data")
    else:
        archive.extractall(dest_dir)


def is_zip(path: Path) -> bool:
    with path.open("rb") as handle:
        return handle.read(2) == b"PK"


def is_tar(path: Path) -> bool:
    return tarfile.is_tarfile(path)


def validate_archive(path: Path, label: str = "archive") -> None:
    if not path.is_file():
        raise SystemExit(f"{label}: file not found: {path}")
    if path.stat().st_size < 1:
        raise SystemExit(f"{label}: empty file: {path}")
    if not (is_zip(path) or is_tar(path)):
        preview = path.read_bytes()[:200].decode("utf-8", errors="replace")
        raise SystemExit(
            f"{label}: not a zip or tar archive ({path.stat().st_size} bytes): {preview!r}"
        )


def create_mod_zip(parent_dir: Path, zip_path: Path) -> None:
    root = parent_dir / "Subnautica2"
    if not root.is_dir():
        raise SystemExit(f"Missing Subnautica2/ under {parent_dir}")

    zip_path.parent.mkdir(parents=True, exist_ok=True)
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file_path in sorted(root.rglob("*")):
            if file_path.is_file():
                archive.write(file_path, file_path.relative_to(parent_dir).as_posix())


def extract_archive(archive_path: Path, dest_dir: Path) -> None:
    validate_archive(archive_path, archive_path.name)
    dest_dir.mkdir(parents=True, exist_ok=True)

    if is_zip(archive_path):
        with zipfile.ZipFile(archive_path) as archive:
            archive.extractall(dest_dir)
        return

    with tarfile.open(archive_path) as archive:
        extract_tar(archive, dest_dir)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_parser = subparsers.add_parser("create", help="Create a zip from parent/Subnautica2/")
    create_parser.add_argument("parent_dir", type=Path)
    create_parser.add_argument("zip_path", type=Path)

    extract_parser = subparsers.add_parser("extract", help="Extract a zip or legacy tar archive")
    extract_parser.add_argument("archive_path", type=Path)
    extract_parser.add_argument("dest_dir", type=Path)

    validate_parser = subparsers.add_parser("validate", help="Validate a zip or tar archive")
    validate_parser.add_argument("archive_path", type=Path)
    validate_parser.add_argument("label", nargs="?", default="archive")

    args = parser.parse_args()

    if args.command == "create":
        create_mod_zip(args.parent_dir.resolve(), args.zip_path.resolve())
    elif args.command == "extract":
        extract_archive(args.archive_path.resolve(), args.dest_dir.resolve())
    else:
        validate_archive(args.archive_path.resolve(), args.label)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
