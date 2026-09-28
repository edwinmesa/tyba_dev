from pathlib import Path

def print_tree(path: Path, prefix=""):
    items = sorted(
        [
            p for p in path.iterdir()
            if p.name not in {".git", "__pycache__", ".venv", "venv"}
        ],
        key=lambda p: (p.is_file(), p.name.lower())
    )

    for i, item in enumerate(items):
        connector = "└── " if i == len(items) - 1 else "├── "
        print(prefix + connector + item.name)

        if item.is_dir():
            extension = "    " if i == len(items) - 1 else "│   "
            print_tree(item, prefix + extension)


print_tree(Path("."))