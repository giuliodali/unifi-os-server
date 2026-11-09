#!/bin/bash
# Commit a results dir to the perf-results branch (retrying on races).
SRC=$1 DEST=$2
set -e
git config --global user.name "perf-lab"; git config --global user.email "perf-lab@users.noreply.github.com"
rm -rf /tmp/pr; git clone -q --depth 1 --branch perf-results "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}" /tmp/pr 2>/dev/null || {
  git clone -q --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}" /tmp/pr
  cd /tmp/pr; git checkout -q --orphan perf-results; git rm -rqf .; echo "# perf results" > README.md; git add README.md; git commit -qm init; git push -q origin perf-results || true; cd -; }
cd /tmp/pr
for i in 1 2 3 4 5 6; do
  git fetch -q origin perf-results && git reset -q --hard origin/perf-results || true
  mkdir -p "$DEST"; cp -r "$SRC"/. "$DEST"/
  git add -A; git commit -qm "results $DEST" || exit 0
  git push -q origin HEAD:perf-results && exit 0
  sleep $((RANDOM % 10 + 3))
done
exit 1
