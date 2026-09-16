# -*- coding: utf-8 -*-
"""将正式收藏表同步到个人 GitHub 私有仓库。"""
import argparse
import os
import shutil
import subprocess
from pathlib import Path


DEFAULT_XLSX = Path(r"C:\Users\zhen\.codex\skills\douban-movie-collector\examples\2026-09-04_电影资源收藏表.xlsx")
DEFAULT_REPO = Path(r"D:\yangzhen\workskill\movie_collection_repo")
DEFAULT_REMOTE = "https://github.com/spsz831/movie-collection.git"


def default_skill_dir():
    codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    return codex_home / "skills" / "douban-movie-collector"


def find_existing_repo():
    candidates = [
        Path(os.environ.get("MOVIE_COLLECTION_REPO", "")) if os.environ.get("MOVIE_COLLECTION_REPO") else None,
        Path.cwd() / "movie-collection",
        Path.cwd() / "movie_collection_repo",
        Path.home() / "movie-collection",
        Path.home() / "movie_collection_repo",
        Path(r"D:\yangzhen\workskill\movie_collection_repo"),
    ]
    for candidate in candidates:
        if candidate and (candidate / ".git").exists():
            return candidate
    return None


def resolve_xlsx(path, repo):
    if path:
        return Path(path)
    candidates = [
        default_skill_dir() / "examples" / "2026-09-04_电影资源收藏表.xlsx",
        repo / "2026-09-04_电影资源收藏表.xlsx" if repo else None,
    ]
    for candidate in candidates:
        if candidate and candidate.is_file():
            return candidate
    return candidates[0]


def run(repo, *args):
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
    )
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip())
    return (result.stdout or "").strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--xlsx", type=Path, default=None, help="正式收藏表路径；省略时自动定位")
    parser.add_argument("--repo", type=Path, default=None, help="movie-collection 仓库；省略时自动定位")
    parser.add_argument("--remote", default=DEFAULT_REMOTE)
    parser.add_argument("--message", default="同步影视收藏表")
    args = parser.parse_args()

    repo = args.repo or find_existing_repo() or DEFAULT_REPO
    xlsx = resolve_xlsx(args.xlsx, repo)
    if not xlsx.is_file():
        raise SystemExit(f"找不到正式收藏表：{xlsx}。请先运行 setup_movie_collection.py，或使用 --xlsx 指定路径。")
    if not (repo / ".git").exists():
        raise SystemExit(f"本地 GitHub 仓库不存在：{repo}。请先运行 setup_movie_collection.py，或使用 --repo 指定路径。")
    if run(repo, "status", "--porcelain"):
        raise SystemExit("本地 movie-collection 仓库有未提交修改，已停止，避免覆盖用户内容。")

    run(repo, "pull", "--ff-only", "origin", "main")
    destination = repo / xlsx.name
    shutil.copy2(xlsx, destination)
    run(repo, "add", "--", xlsx.name)
    staged_check = subprocess.run(["git", "-C", str(repo), "diff", "--cached", "--quiet"])
    if staged_check.returncode == 0:
        ahead = int(run(repo, "rev-list", "--count", "origin/main..main") or 0)
        if ahead:
            run(repo, "push", "origin", "main")
            print(f"已推送本地待同步提交：{args.remote}")
        else:
            print(f"未检测到变化，仓库已是最新：{repo}")
        return
    if staged_check.returncode != 1:
        raise SystemExit("无法检查 Git 暂存区状态。")
    run(repo, "commit", "-m", args.message)
    run(repo, "push", "origin", "main")
    print(f"已推送：{args.remote}，文件：{args.xlsx.name}")


if __name__ == "__main__":
    main()
