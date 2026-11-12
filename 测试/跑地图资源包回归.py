"""在临时最小工程中运行 PCK 回归，不加载游戏主题、自动加载节点或本地账号。"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("NARUTO_GODOT", "godot"))
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error("找不到 Godot；请使用 --godot 或 NARUTO_GODOT 指定 4.7.x 可执行文件")
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="naruto-map-pck-") as directory:
        project = Path(directory)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Map PCK regression"\n',
            encoding="utf-8",
        )
        for relative in ("脚本/地图/地图资源.gd", "测试/地图资源包回归测试.gd"):
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(root / relative, target)
        try:
            result = subprocess.run(
                [godot, "--headless", "--path", str(project),
                 "--script", "res://测试/地图资源包回归测试.gd"],
                timeout=60,
                check=False,
            )
        except subprocess.TimeoutExpired:
            print("地图资源包回归：超时", flush=True)
            return 1
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
