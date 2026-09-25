"""Read fields from src/_quarto.yml (regex only; the CI docx image has no PyYAML)."""
import re
from pathlib import Path

QUARTO_CONFIG = Path(__file__).resolve().parents[3] / "src" / "_quarto.yml"


def _field(pattern: str, config: Path) -> str | None:
    match = re.search(pattern, config.read_text(encoding="utf-8"), re.MULTILINE)
    return match.group(1) if match else None


def read_version(config: Path = QUARTO_CONFIG) -> str | None:
    return _field(r'^\s*subtitle:\s*(?:&\w+\s*)?["\']?Version\s+([^\s"\']+)', config)


def read_output_file(config: Path = QUARTO_CONFIG) -> str | None:
    return _field(r'^\s*output-file:\s*["\']?([^\s"\']+?)["\']?\s*$', config)


if __name__ == "__main__":
    print(read_output_file() or "", read_version() or "")
