#!/bin/sh

# Turns this template into a Dirthara package.
#
# Usage: bin/init-package.sh <package> "<description>" [options]
#
#   <package>       Lowercase, dash-separated repository name, such as
#                   "migration" or "query-builder". It becomes the Composer
#                   name "dirthara/<package>" and the GitHub repository
#                   "git@github.com:dirthara/<package>.git".
#   <description>   One line, no trailing period. It becomes the Composer
#                   description and the opening line of the README and docs.
#
# Options:
#   --namespace <Name>  PHP namespace after "Dirthara\". Defaults to the
#                       package name in StudlyCase.
#   --year <YYYY>       Copyright year. Defaults to the current year.
#   --no-git            Only rewrite the placeholders; leave git alone.
#
# Git, unless --no-git is given: initialises the repository on branch 0.1 if it
# is not one already, sets the bricknpc identity and GPG signing locally, and
# adds the dirthara origin when no origin exists. It never commits; review the
# scaffold first, then commit it as "Repository setup".

set -eu

GIT_NAME="${DIRTHARA_GIT_NAME:-bricknpc}"
GIT_EMAIL="${DIRTHARA_GIT_EMAIL:-bricknpc@proton.me}"
BRANCH="${DIRTHARA_BRANCH:-0.1}"

usage() {
    sed -n '3,23p' "$0" | cut -c 3-
    exit "${1:-1}"
}

package=""
description=""
namespace=""
year=""
git_setup=1

while [ $# -gt 0 ]; do
    case "$1" in
        --namespace) namespace="${2:-}"; shift 2 ;;
        --year) year="${2:-}"; shift 2 ;;
        --no-git) git_setup=0; shift ;;
        -h|--help) usage 0 ;;
        -*) echo "Unknown option: $1" >&2; usage ;;
        *)
            if [ -z "$package" ]; then
                package="$1"
            elif [ -z "$description" ]; then
                description="$1"
            else
                echo "Unexpected argument: $1" >&2; usage
            fi
            shift
            ;;
    esac
done

[ -n "$package" ] && [ -n "$description" ] || usage

if ! echo "$package" | grep -Eq '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
    echo "Package name must be lowercase and dash-separated: $package" >&2
    exit 1
fi

# StudlyCase: "query-builder" becomes "QueryBuilder".
[ -n "$namespace" ] || namespace=$(echo "$package" | sed -E 's/(^|-)([a-z0-9])/\U\2/g')
[ -n "$year" ] || year=$(date +%Y)

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

if ! grep -rq '__PACKAGE__' . --exclude-dir=.git --exclude-dir=bin 2>/dev/null; then
    echo "No placeholders left: this repository has already been initialised." >&2
    exit 1
fi

escape() {
    printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

package_sed=$(escape "$package")
namespace_sed=$(escape "$namespace")
description_sed=$(escape "$description")
year_sed=$(escape "$year")

# Every text file in the repository, minus this script and git's own files.
files=$(find . -type f \
    -not -path './.git/*' \
    -not -path './bin/*' \
    -not -path './vendor/*' \
    -exec grep -Iq . {} \; -print)

echo "$files" | while IFS= read -r file; do
    [ -n "$file" ] || continue
    sed -i \
        -e "s|__PACKAGE__|${package_sed}|g" \
        -e "s|__NAMESPACE__|${namespace_sed}|g" \
        -e "s|__DESCRIPTION__|${description_sed}|g" \
        -e "s|__YEAR__|${year_sed}|g" \
        "$file"
done

rm -f TEMPLATE.md bin/init-package.sh
rmdir bin 2>/dev/null || true

echo "Initialised dirthara/${package} (Dirthara\\${namespace})."

if [ "$git_setup" -eq 0 ]; then
    echo "Skipped git setup (--no-git)."
    exit 0
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    git init -b "$BRANCH" >/dev/null
    echo "Initialised a git repository on branch ${BRANCH}."
fi

git config user.name "$GIT_NAME"
git config user.email "$GIT_EMAIL"

# Signing is on by default for every Dirthara commit and tag. The key comes
# from the global configuration so the template carries no personal key.
signingkey="${DIRTHARA_SIGNING_KEY:-$(git config --global user.signingkey || true)}"

if [ -n "$signingkey" ]; then
    git config user.signingkey "$signingkey"
    git config commit.gpgsign true
    git config tag.gpgsign true
    echo "Signing commits and tags with ${signingkey}."
else
    echo "WARNING: no signing key found. Set one with:" >&2
    echo "  git config user.signingkey <key>" >&2
    echo "  git config commit.gpgsign true && git config tag.gpgsign true" >&2
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "git@github.com:dirthara/${package}.git"
    echo "Added origin git@github.com:dirthara/${package}.git."
fi

cat <<TEXT

Next:
  1. Add the package's dependencies to composer.json.
  2. docker compose exec php composer install   (generates composer.lock)
  3. Review the scaffold, then commit it as "Repository setup".
TEXT
