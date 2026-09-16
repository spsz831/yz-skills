# -*- coding: utf-8 -*-
"""将正式收藏表同步到个人 GitHub 私有仓库。"""
import argparse
import shutil
import subprocess
from pathlib import Path


DEFAULT_XLSX = Path(r"C:\Users\zhen\.codex\skills\douban-movie-collector\examples\2026-09-04_电影资源收藏表.xlsx")
DEFAULT_REPO = Path(r"D:\yangzhen\workskill\movie_collection_repo")
DEFAULT_REMOTE = "https://github.com/spsz831/movie-collection.git"


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
    parser.add_argument("--xlsx", type=Path, default=DEFAULT_XLSX)
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument("--remote", default=DEFAULT_REMOTE)
    parser.add_argument("--message", default="同步影视收藏表")
    args = parser.parse_args()

    if not args.xlsx.is_file():
        raise SystemExit(f"找不到正式收藏表：{args.xlsx}")
    if not (args.repo / ".git").exists():
        raise SystemExit(f"本地 GitHub 仓库不存在：{args.repo}，请先克隆 {args.remote}")
    if run(args.repo, "status", "--porcelain"):
        raise SystemExit("本地 movie-collection 仓库有未提交修改，已停止，避免覆盖用户内容。")

    run(args.repo, "pull", "--ff-only", "origin", "main")
    destination = args.repo / args.xlsx.name
    shutil.copy2(args.xlsx, destination)
    run(args.repo, "add", "--", args.xlsx.name)
    staged_check = subprocess.run(["git", "-C", str(args.repo), "diff", "--cached", "--quiet"])
    if staged_check.returncode == 0:
        ahead = int(run(args.repo, "rev-list", "--count", "origin/main..main") or 0)
        if ahead:
            run(args.repo, "push", "origin", "main")
            print(f"已推送本地待同步提交：{args.remote}")
        else:
            print(f"未检测到变化，仓库已是最新：{args.repo}")
        return
    if staged_check.returncode != 1:
        raise SystemExit("无法检查 Git 暂存区状态。")
    run(args.repo, "commit", "-m", args.message)
    run(args.repo, "push", "origin", "main")
    print(f"已推送：{args.remote}，文件：{args.xlsx.name}")


if __name__ == "__main__":
    main()
