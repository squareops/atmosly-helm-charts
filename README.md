# atmosly-helm-charts

[![Chart checks](https://github.com/squareops/atmosly-helm-charts/actions/workflows/pr-checks.yaml/badge.svg)](https://github.com/squareops/atmosly-helm-charts/actions/workflows/pr-checks.yaml)
[![Publish charts](https://github.com/squareops/atmosly-helm-charts/actions/workflows/publish.yaml/badge.svg)](https://github.com/squareops/atmosly-helm-charts/actions/workflows/publish.yaml)

The Helm charts Atmosly uses to run databases on a customer's cluster (blueprint databases): MySQL, MongoDB, PostgreSQL and Redis. This repository is the single place for all four charts and the Helm repository they are published from.

## Chart address

```
https://squareops.github.io/atmosly-helm-charts
```

```bash
helm repo add atmosly-db https://squareops.github.io/atmosly-helm-charts
helm repo update
helm search repo atmosly-db --versions
helm pull atmosly-db/mysql --version 9.16.20
```

The address is served by GitHub Pages from the `gh-pages` branch (`index.yaml` and the packaged `.tgz` files). Customer clusters pull from it without authentication, so the repository and the Pages site must stay public.

## What is in here

| Chart | Path | Source of the first import | Latest version |
|---|---|---|---|
| MySQL | `charts/mysql` | `Atmosly-builder/atmosly-mysql-helm-chart` fork branch `fix/mysql-8.4-default-authentication-plugin` (c88a47b) | 9.16.20 |
| MongoDB | `charts/mongodb` | `Atmosly-builder/atmosly-mongo-helm-chart` fork branch `feature/configurable-backup-restore-images` (6358eee) | 14.10.9 |
| PostgreSQL | `charts/postgresql` | `Atmosly-builder/atmosly-postgresql-helm-chart` main (08d064c) | 13.4.0 |
| Redis | `charts/redis` | `Atmosly-builder/atmosly-redis-helm-chart` main (e9795f9) | 18.12.6 |

The Bitnami `common` library chart each chart depends on is vendored in `charts/<name>/charts/common`; nothing is downloaded when a chart is packaged.

`gh-pages` also holds every version the four old repositories ever published (MySQL 9.16.15 to 9.16.19, MongoDB 14.10.0 to 14.10.8, PostgreSQL 13.3.0 to 13.4.0, Redis 18.12.1 to 18.12.6, and `common` 2.14.1), so any version Atmosly has pinned resolves from this address too.

## Add or change a chart version

1. Branch from `main` and change the chart under `charts/<name>/`.
2. Raise `version` in `charts/<name>/Chart.yaml` (always, for any change to the chart).
3. Open a pull request. The checks run on the charts you changed: `ct lint` (including the version bump check), `helm template`, and an install on a kind cluster.
4. Merge. The workflow `Publish charts (push to main)` packages every chart whose version is not in `index.yaml` yet, adds the `.tgz` to `gh-pages` and merges the new entries into `index.yaml`. A minute later the version is available at the chart address.

To add a new chart, create `charts/<new-name>/` with its own `Chart.yaml` and follow the same steps.

## Versions are never overwritten

A published version is final. Customers' Argo CD applications pin exact versions, so replacing a package would silently change running databases.

* The pull request check fails when a chart changed and its version is unchanged or already published.
* The publish workflow fails when a chart changed on `main` but its version is already in `index.yaml`, and it refuses to write a `.tgz` that already exists on `gh-pages`.
* Entries already in `index.yaml` keep their digest, URL and creation date: new packages are indexed on their own and merged in (`helm repo index --merge`).

If a published version turns out to be wrong, ship a fix as the next version and move Atmosly's pin to it.

## Which Atmosly setting points here

The Atmosly backend reads the repository address and the version of each chart from `tcc/config.py` and puts them into the Argo CD application of every blueprint database (`project_environment/databases.py`):

| Setting | Value to use |
|---|---|
| `SM_MYSQL_CHARTS_REPO` | `https://squareops.github.io/atmosly-helm-charts` |
| `SM_MONGODB_CHART_REPO` | `https://squareops.github.io/atmosly-helm-charts` |
| `SM_POSTGRESQL_CHART_REPO` | `https://squareops.github.io/atmosly-helm-charts` |
| `SM_REDIS_CHART_REPO` | `https://squareops.github.io/atmosly-helm-charts` |
| `SM_MYSQL_CHART_VERSION`, `SM_MONGODB_CHART_VERSION`, `SM_POSTGRESQL_CHART_VERSION`, `SM_REDIS_CHART_VERSION` | the version to deploy (for example 9.16.20, 14.10.9, 13.4.0, 18.12.6) |

Switch the four addresses together; the chart names (`mysql`, `mongodb`, `postgresql`, `redis`) are the same as before.

## The old repositories

`Atmosly-builder/atmosly-mysql-helm-chart`, `atmosly-mongo-helm-chart`, `atmosly-postgresql-helm-chart` and `atmosly-redis-helm-chart` are left as they are. Their GitHub Pages sites keep serving the databases that already exist, whose Argo CD applications point at them. New work goes here.

## Repository layout

```
charts/<name>/              the chart sources
ct.yaml, lintconf.yaml      chart-testing settings
scripts/publish.sh          the check and publish logic used by both workflows
.github/workflows/
  pr-checks.yaml            pull requests: ct lint, helm template, install on kind, version check
  publish.yaml              push to main: package new versions into gh-pages
```
