#!/usr/bin/env python3
"""
Download artifacts from the latest GitHub Actions run of a repo, using `gh`.

Requires: GitHub CLI (`gh`) installed and authenticated (`gh auth login`).

Examples:
    # Latest run on the default branch, any workflow
    ./gh_latest_artifacts.py -R telatin/seqfu2

    # Latest run of a specific workflow file, on a branch
    ./gh_latest_artifacts.py -R telatin/seqfu2 -w ci.yml -b main

    # Only the successful ones, download one named artifact into ./out
    ./gh_latest_artifacts.py -R telatin/seqfu2 --status success -n coverage-report -D out
"""

import argparse
import json
import shutil
import subprocess
import sys


def run(cmd: list[str]) -> str:
    """Run a command, return stdout, raise with stderr shown on failure."""
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"Command failed: {' '.join(cmd)}\n{result.stderr.strip()}")
    return result.stdout


def latest_run_id(repo: str, workflow: str | None, branch: str | None,
                   status: str | None) -> tuple[int, str]:
    """Return (run_id, human-readable description) of the most recent matching run."""
    cmd = [
        "gh", "run", "list", "-R", repo, "--limit", "1",
        "--json", "databaseId,displayTitle,workflowName,headBranch,status,conclusion,createdAt",
    ]
    if workflow:
        cmd += ["--workflow", workflow]
    if branch:
        cmd += ["--branch", branch]
    if status:
        cmd += ["--status", status]

    out = run(cmd)
    runs = json.loads(out)
    if not runs:
        sys.exit("No matching workflow runs found.")

    r = runs[0]
    desc = (f"#{r['databaseId']} \"{r['displayTitle']}\" "
             f"[{r['workflowName']}] on {r['headBranch']} "
             f"({r['status']}/{r['conclusion']}, {r['createdAt']})")
    return r["databaseId"], desc


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                      formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-R", "--repo", required=True, help="owner/repo")
    parser.add_argument("-w", "--workflow", help="Workflow file name or ID (e.g. ci.yml)")
    parser.add_argument("-b", "--branch", help="Restrict to a branch")
    parser.add_argument("--status", help="Filter by run status/conclusion "
                                          "(e.g. success, completed, failure)")
    parser.add_argument("-n", "--artifact-name", help="Download only this artifact "
                                                        "(passed through to `gh run download -n`)")
    parser.add_argument("-D", "--dir", default=".", help="Output directory (default: cwd)")
    parser.add_argument("--dry-run", action="store_true",
                         help="Only show which run would be used, don't download")
    args = parser.parse_args()

    if shutil.which("gh") is None:
        sys.exit("`gh` CLI not found. Install it: https://cli.github.com/")

    run_id, desc = latest_run_id(args.repo, args.workflow, args.branch, args.status)
    print(f"Latest matching run: {desc}")

    if args.dry_run:
        return

    cmd = ["gh", "run", "download", str(run_id), "-R", args.repo, "-D", args.dir]
    if args.artifact_name:
        cmd += ["-n", args.artifact_name]

    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
