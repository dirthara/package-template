# Dirthara package template

The scaffold every Dirthara package starts from: the Docker development
environment, the Mago and PHPUnit configuration, the CI workflow with its
single required `CI` check and its actions pinned to commit SHAs, the 100%
coverage gate, the Dependabot configuration, the `.gitattributes` that keeps
development files out of a release, the branch-per-version contributing rules,
and the agent instructions.

This file and `bin/` are the only parts that are not part of a package. The
init script deletes both once it has run.

The template itself is not a versioned package, so it has a single `main`
branch. The branch-per-version strategy in `CONTRIBUTING.md` describes the
packages created from the scaffold, which still start on `0.1`.

## Creating a package

Either use this repository as a GitHub template, or copy the directory. A
local copy must not keep the template's own git history:

```sh
cp -r package-template ../<package>
rm -rf ../<package>/.git
cd ../<package>
```

Then fill in the placeholders:

```sh
bin/init-package.sh migration "Migrations for the Dirthara framework"
```

The first argument is the repository name, the second is a one-line
description with no trailing period. `--namespace` overrides the derived PHP
namespace, `--year` the copyright year, and `--no-git` skips the git setup.

That rewrites four placeholders across the scaffold:

| Placeholder | Becomes | Example |
| --- | --- | --- |
| `__PACKAGE__` | The repository and Composer name | `migration` |
| `__NAMESPACE__` | The namespace after `Dirthara\` | `Migration` |
| `__DESCRIPTION__` | The one-line description | `Migrations for the Dirthara framework` |
| `__YEAR__` | The copyright year | `2026` |

and, unless `--no-git` is given, initialises the repository on branch `0.1`,
sets `bricknpc <bricknpc@proton.me>` as the local identity, turns on GPG
signing for commits and tags using the key from your global git configuration,
and adds `git@github.com:dirthara/<package>` as `origin`. It never commits.

## After the script

1. **Add the dependencies** to `composer.json`. The template requires only
   `php: ^8.5` and `phpunit/phpunit: ^12.0`. A package that talks to a database
   also adds `ext-pdo`, `dirthara/database`, and a `suggest` block naming the
   PDO driver extensions, the way `dirthara/schema` does.
2. **Generate `composer.lock`**, which the first commit includes:
   ```sh
   LOCAL_UID=$(id -u) LOCAL_GID=$(id -g) docker compose up -d --build php
   docker compose exec php composer install
   ```
3. **Commit the scaffold** as `Repository setup`, then push branch `0.1`.
4. **Create the GitHub repository** under the `dirthara` organisation, make
   `0.1` its default branch, and protect it:
   ```sh
   scripts/protect-branch.sh 0.1
   ```
5. **Register the package** in the global documentation site at
   <https://dirthara.github.io/docs/> by adding it to `sources.json` in
   `dirthara/docs`. Every package documents itself there rather than publishing
   a site of its own, and `README.md` and `composer.json` already link to it.

## Packages that do not touch a database

The template assumes a package that runs against all four supported databases,
because most of them do. For a package that does not, such as
`dirthara/collection`, remove:

- the `postgres`, `mysql`, and `sqlserver` services and the `depends_on` block
  in `compose.yaml`;
- `docker-php-ext-install pdo` and the `pdo_*` extensions in
  `Docker/Dockerfile`, keeping `xdebug`;
- the database paragraphs in `README.md` ("Docker development environment" and
  "Tests") and in `AGENTS.md` ("Tests" and "Development").

## Keeping the template current

The scaffold is copied, not inherited, so an improvement made in a package does
not reach the others. When you change something here that every package should
have, carry it into the existing packages in the same pass. The reverse is
truer still: when a package improves its tooling, bring it back here, or the
next package starts behind.
