# -*- coding: utf-8 -*-
"""跨电脑初始化 douban-movie-collector 和个人收藏表。"""
import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


SKILL_REPO = "https://github.com/spsz831/yz-skills.git"
MOVIE_REPO = "https://github.com/spsz831/movie-collection.git"
TABLE_NAME = "2026-09-04_电影资源收藏表.xlsx"


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, text=True, encoding="utf-8", errors="replace", capture_output=True)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip())
    return (result.stdout or "").strip()


def codex_skills_dir():
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    return codex_home / "skills"


def clone_or_update(repo_url, target):
    if (target / ".git").exists():
        if run("git", "-C", str(target), "status", "--porcelain"):
            raise RuntimeError(f"目录有未提交修改，已停止：{target}")
        run("git", "-C", str(target), "pull", "--ff-only", "origin", "main")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", repo_url, str(target))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--skills-dir", type=Path, default=None, help="Codex skills 目录；省略时自动定位")
    parser.add_argument("--collection-dir", type=Path, default=None, help="个人收藏仓库目录；省略时使用用户主目录")
    parser.add_argument("--skip-skill", action="store_true", help="只初始化私有收藏仓库")
    parser.add_argument("--skip-collection", action="store_true", help="只初始化公开 skill")
    args = parser.parse_args()

    skills_dir = args.skills_dir or codex_skills_dir()
    collection_dir = args.collection_dir or (Path.home() / "movie-collection")
    with tempfile.TemporaryDirectory(prefix="yz-skills-") as temp:
        temp_root = Path(temp)
        if not args.skip_skill:
            yz_repo = temp_root / "yz-skills"
            clone_or_update(SKILL_REPO, yz_repo)
            source = yz_repo / "douban-movie-collector"
            if not source.exists():
                raise RuntimeError("yz-skills 中找不到 douban-movie-collector")
            target = skills_dir / "douban-movie-collector"
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(source, target, dirs_exist_ok=True)
            print(f"已安装 skill：{target}")

    if not args.skip_collection:
        clone_or_update(MOVIE_REPO, collection_dir)
        table = collection_dir / TABLE_NAME
        target_table = skills_dir / "douban-movie-collector" / "examples" / TABLE_NAME
        target_table.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(table, target_table)
        print(f"已同步收藏表：{target_table}")

    print("初始化完成。以后可运行 skill 目录中的 sync_movie_collection.py 同步收藏表。")


if __name__ == "__main__":
    main()
