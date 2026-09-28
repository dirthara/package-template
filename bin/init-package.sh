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
# Besides the placeholders, it adds the exceptions CS-7 requires: the package
# exception interface "<Namespace>Exception", the HasExceptionContext trait
# that implements it, and their tests, from the stubs in bin/stubs.
#
# Options:
#   --namespace <Name>  PHP namespace after "Dirthara\". Defaults to the
#                       package name in StudlyCase.
#   --year <YYYY>       Copyright year. Defaults to the current year.
#   --no-database       For a package that never touches a database: leave out
#                       the database services, the PDO extensions, and the
#                       database sections of the documentation.
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
    sed -n '3,30p' "$0" | cut -c 3-
    exit "${1:-1}"
}

package=""
description=""
namespace=""
year=""
database=1
git_setup=1

while [ $# -gt 0 ]; do
    case "$1" in
        --namespace) namespace="${2:-}"; shift 2 ;;
        --year) year="${2:-}"; shift 2 ;;
        --no-database) database=0; shift ;;
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

# The CS-7 exception setup. Copied before the placeholders are replaced, so the
# stubs are rewritten with everything else.
(cd bin/stubs && find . -type f) | while IFS= read -r stub; do
    target=$(printf '%s' "$stub" | sed "s|__NAMESPACE__|${namespace}|g")
    mkdir -p "$(dirname -- "$target")"
    cp "bin/stubs/$stub" "$target"
done
rm -f src/.gitkeep tests/.gitkeep

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

# The namespace length decides the import order the stubs need, so sort each
# block of imports the way scripts/sort-imports.php does: by length, then
# case-insensitively, then bytewise. Done in awk because the host may have no
# PHP; the stubs only use single-line imports without comments.
sort_imports() {
    LC_ALL=C awk '
        function kind(line) {
            if (line ~ /^use function /) return "function"
            if (line ~ /^use const /) return "const"
            return "class"
        }
        function before(a, b) {
            if (length(a) != length(b)) return length(a) < length(b)
            if (tolower(a) != tolower(b)) return tolower(a) < tolower(b)
            return a < b
        }
        function flush(    i, j, line) {
            for (i = 2; i <= n; i++) {
                line = block[i]
                for (j = i - 1; j >= 1 && before(line, block[j]); j--) block[j + 1] = block[j]
                block[j + 1] = line
            }
            for (i = 1; i <= n; i++) print block[i]
            n = 0
        }
        /^use [^;]*;$/ {
            if (n > 0 && kind($0) != kind(block[n])) flush()
            block[++n] = $0
            next
        }
        { if (n > 0) flush(); print }
        END { if (n > 0) flush() }
    ' "$1" > "$1.sorted" && mv "$1.sorted" "$1"
}

find src tests -type f -name '*.php' | while IFS= read -r file; do
    sort_imports "$file"
done

# Database-only parts of the scaffold sit between marker lines inside comments:
# "@database" to "@end-database" for what only a database package keeps, and
# "@no-database" to "@end-no-database" for what only a package without one
# keeps. Delete the region that does not apply and every marker line.
if [ "$database" -eq 1 ]; then drop="no-database"; else drop="database"; fi

strip_regions() {
    awk -v drop="$drop" '
        /^[ \t]*(#|<!--)[ \t]*@(end-)?(no-)?database[ \t]*(-->)?[ \t]*$/ {
            tag = $0
            sub(/^[ \t]*(#|<!--)[ \t]*@/, "", tag)
            sub(/[ \t]*(-->)?[ \t]*$/, "", tag)
            if (tag ~ /^end-/) {
                if (region != substr(tag, 5)) { bad = "unexpected @" tag; exit 1 }
                region = ""
            } else {
                if (region != "") { bad = "@" tag " inside @" region; exit 1 }
                region = tag
            }
            next
        }
        region != drop { print }
        END {
            if (bad == "" && region != "") bad = "@" region " is never closed"
            if (bad != "") { print FILENAME ":" NR ": " bad > "/dev/stderr"; exit 1 }
        }
    ' "$1" > "$1.stripped" && mv "$1.stripped" "$1" || { rm -f "$1.stripped"; exit 1; }
}

grep -rlE '@(end-)?(no-)?database' . \
    --exclude-dir=.git --exclude-dir=bin --exclude-dir=vendor \
    --exclude=TEMPLATE.md 2>/dev/null | while IFS= read -r file; do
    strip_regions "$file"
done

rm -rf TEMPLATE.md bin

echo "Initialised dirthara/${package} (Dirthara\\${namespace})."
echo "Added Dirthara\\${namespace}\\Exception\\${namespace}Exception and HasExceptionContext."
[ "$database" -eq 1 ] || echo "Left out the database services, drivers, and documentation (--no-database)."

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
