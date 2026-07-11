from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys
from types import ModuleType


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "skills" / "perfetto-performance-analysis" / "scripts"


def load_skill_script(name: str) -> ModuleType:
    path = SCRIPTS / f"{name}.py"
    if not path.is_file():
        raise FileNotFoundError(path)
    module_name = f"perfetto_skill_{name}"
    spec = spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise ImportError(path)
    module = module_from_spec(spec)
    sys.modules[module_name] = module
    sys.path.insert(0, str(SCRIPTS))
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path.remove(str(SCRIPTS))
    return module

