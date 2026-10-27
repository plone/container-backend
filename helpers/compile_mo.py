"""Helper script to pre-compile PO files in a Plone backend builder image."""
from pathlib import Path
from pythongettext.msgfmt import Msgfmt
from pythongettext.msgfmt import PoSyntaxError
from typing import Generator

import logging
import os


# Allow you to change the base folder of the application
APP_FOLDER: str = os.environ.get("APP_FOLDER", "/app")
LOG_FOLDER: str = "/var/log"


logging.basicConfig(filename=Path(f"{LOG_FOLDER}/compile_mo.log"))
logger = logging.getLogger("compile-mo")
logger.setLevel(logging.DEBUG)


def compile_po_file(po_file: Path) -> Path | None:
    """Compile a single PO file."""
    # Search for a .mo file in the same directory
    parent: Path = po_file.parent
    domain: str = po_file.name[: -len(po_file.suffix)]
    mo_file: Path = parent / f"{domain}.mo"
    do_compile: bool = True

    if mo_file.exists():
        # Check if an existing file needs to be recompiled
        do_compile = os.stat(mo_file).st_mtime < os.stat(po_file).st_mtime

    if do_compile:
        try:
            mo = Msgfmt(f"{po_file}", name=domain).getAsFile()
        except PoSyntaxError:
            logger.error(f" -- Error while compiling language file {mo_file}")
            return
        else:
            with open(mo_file, "wb") as f_out:
                try:
                    f_out.write(mo.read())
                except (IOError, OSError):
                    logger.error(f" -- Error writing language file {mo_file}")
                    return
            logger.info(f" -- Compiled language file {mo_file}")
    else:
        logger.info(f" -- Already coimpiled language file {mo_file}")
    return mo_file


def main():
    mo_files: list = []
    lib_paths: list = []
    lib_paths = [
        Path(f"{APP_FOLDER}/lib").resolve(),
        Path(f"{APP_FOLDER}/src/sources").resolve(),
    ]
    for lib_path in lib_paths:
        po_files: Generator = lib_path.glob("**/*.po")
        logger.info("Starting compilation of po files")
        for po_file in po_files:
            mo_file = compile_po_file(po_file)
            if mo_file:
                mo_files.append(mo_file)
    logger.info(f"Compiled {len(mo_files)} files")


if __name__ == "__main__":
    main()
