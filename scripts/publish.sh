#!/usr/bin/env bash
# Publishes the charts under charts/ to the gh-pages branch (the Helm repository).
#
#   scripts/publish.sh check   <pages-dir> <base-commit>   fail when a changed chart keeps a published version
#   scripts/publish.sh publish <pages-dir> <base-commit>   package charts whose version is not published yet
#
# <pages-dir>   a checkout of the gh-pages branch (holds index.yaml and the .tgz files)
# <base-commit> the commit the change is compared with (the push's "before" or the pull request's base);
#               empty or all zeros (first push) means "no comparison", only unpublished versions are packaged
#
# Rules: a published version is never overwritten; a chart that changed must have a new version.
set -euo pipefail

MODE="${1:?mode: check|publish}"
PAGES="${2:?gh-pages checkout directory}"
BASE="${3:-}"
REPO_URL="${REPO_URL:-https://squareops.github.io/atmosly-helm-charts}"

[ -f "$PAGES/index.yaml" ] || { echo "ERROR: $PAGES/index.yaml not found (is the gh-pages branch checked out?)"; exit 1; }

have_base=false
if [ -n "$BASE" ] && [ "${BASE//0/}" != "" ] && git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  have_base=true
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failed=0
new=0

for dir in charts/*/; do
  dir="${dir%/}"
  name="$(basename "$dir")"
  version="$(awk -F': *' '/^version:/ {gsub(/["\047 ]/, "", $2); print $2; exit}' "$dir/Chart.yaml")"
  [ -n "$version" ] || { echo "ERROR: no version in $dir/Chart.yaml"; exit 1; }

  published=false
  if grep -qF "/${name}-${version}.tgz" "$PAGES/index.yaml" || [ -e "$PAGES/${name}-${version}.tgz" ]; then
    published=true
  fi

  changed=false
  if $have_base && ! git diff --quiet "$BASE" HEAD -- "$dir"; then
    changed=true
  fi

  if $published; then
    if $changed; then
      echo "ERROR: $name changed but its version $version is already published. Bump version in $dir/Chart.yaml."
      failed=1
    else
      echo "skip   $name $version (already published)"
    fi
    continue
  fi

  echo "new    $name $version"
  new=$((new + 1))
  if [ "$MODE" = "publish" ]; then
    helm package "$dir" --destination "$tmp" >/dev/null
  fi
done

[ "$failed" -eq 0 ] || exit 1
[ "$MODE" = "publish" ] || { echo "check passed ($new unpublished version(s) would be added)"; exit 0; }

if [ "$new" -eq 0 ]; then
  echo "nothing to publish"
  exit 0
fi

# Never overwrite a published package.
for f in "$tmp"/*.tgz; do
  if [ -e "$PAGES/$(basename "$f")" ]; then
    echo "ERROR: $(basename "$f") already exists on gh-pages; refusing to overwrite it."
    exit 1
  fi
done

# Index only the new packages and merge them into the existing index: entries already
# published keep their digest, URL and creation date untouched.
helm repo index "$tmp" --url "$REPO_URL" --merge "$PAGES/index.yaml"
cp "$tmp"/*.tgz "$PAGES/"
cp "$tmp/index.yaml" "$PAGES/index.yaml"
echo "published $new chart version(s)"
