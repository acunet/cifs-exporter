# cifs-exporter

SMB/CIFS Prometheus Exporter for parsing and exporting statistics from `/proc/fs/cifs/Stats`.

> NOTE: This repository is a fork of **shibumi/cifs-exporter** with additional fixes
> and enhancements (see "About this fork" below).

Table of contents
- About
- About this fork
- Features
- Installation
  - Build from source
  - Using Docker
- Usage
  - Command-line flags
  - Examples
- Metrics
  - General
  - Header metrics
  - SMB1/SMB2 metrics
  - SMB3 metrics
  - Labels
- Examples and sample outputs
- Systemd service example
- Troubleshooting & Debugging
- Contribution
- License

About
----

`cifs-exporter` reads the CIFS (SMB) kernel statistics exposed at `/proc/fs/cifs/Stats`,
parses header and per-share blocks, and exports a set of Prometheus metrics that
describe CIFS client activity (reads/writes/opens/negotiates/etc). The exporter is
intended to run on Linux systems which mount CIFS shares and have an exposed
`/proc/fs/cifs/Stats` file.

About this fork
---------------

This repository is a fork of the original project `shibumi/cifs-exporter` with a
focus on correctness and compatibility with newer Linux kernel CIFS stats formats.
Key improvements in this fork:

- Fix `cifs_up` detection so the exporter reports 0 when no CIFS shares are mounted
  or when the Stats file contains no parsed blocks (original always returned 1).
- Support for newer CIFS stats formats that use the keyword `total` instead of
  `sent`, and include additional fields such as "Bytes read/written" and
  "Open files".
- Added a `--debug` flag to enable more verbose logging for troubleshooting.
- Small improvements to parsing logic and metric naming consistency.

If you rely on the original project and want pre-built binaries or releases,
please check the upstream repository: https://github.com/shibumi/cifs-exporter

Features
--------

- Parses CIFS header metrics (resources in use, sessions, shares, buffers, ops)
- Parses per-share SMB1/SMB2/SMB3 blocks and exports many request/response metrics
- Labels metrics with `server` and `share` where applicable
- Supports both old and newer CIFS Stats formats (handles `sent` and `total`)
- Lightweight single-binary Go tool with zero runtime dependencies
- Debug mode for detailed logging

Installation
------------

Build from source (requires Go 1.18+):

```bash
git clone https://github.com/<your-fork>/cifs-exporter.git
cd cifs-exporter
# build binary in current folder
go build -o cifs-exporter
# Or install to $GOPATH/bin
go install ./...
```

Using Docker
------------

A small Docker image can be built using the provided `build/Dockerfile`.

```bash
# from repository root
docker build -t cifs-exporter:latest -f build/Dockerfile .
# run, exposing metrics on port 9965
docker run --rm -p 9965:9965 --privileged \
  -v /proc/fs/cifs/Stats:/proc/fs/cifs/Stats:ro \
  cifs-exporter:latest
```

Note: `/proc/fs/cifs/Stats` must be accessible in the container. Mount it read-only
as shown above. The `--privileged` flag may be required on some systems to access
certain kernel pseudo-files; try without it first.

Usage
-----

Run the exporter on the host where CIFS mounts are present and `/proc/fs/cifs/Stats`
is readable.

Usage example (default listen address):

```bash
./cifs-exporter
# metrics available at http://localhost:9965/metrics
```

Command-line flags

- `-debug` — Enable debug logging (default: false)
- `-version` — Display version information and exit
- `-web.listen-address` string — Address to listen on for web interface and telemetry (default `:9965`)
- `-web.telemetry-path` string — Path to expose metrics on (default `/metrics`)

Examples

- Run on custom port:

```bash
./cifs-exporter -web.listen-address=":8080"
```

- Run with debug logging:

```bash
./cifs-exporter -debug
```

Metrics
-------

General
- `cifs_up` (gauge) — 1 if `/proc/fs/cifs/Stats` is present and exporter found parsed
  blocks; 0 if no Stats file or no parsed CIFS blocks were found.

Header metrics
The exporter parses the header section at the top of the Stats file. Typical
header fields parsed into metrics include (names below are exported as gauges):

- `cifs_total_cifs_sessions`
- `cifs_total_unique_mount_targets`
- `cifs_total_requests`
- `cifs_total_buffer`
- `cifs_total_small_requests`
- `cifs_total_small_buffer`
- `cifs_total_op`
- `cifs_total_session`
- `cifs_total_share_reconnects`
- `cifs_total_max_op`
- `cifs_total_at_once`

Note: Not all kernels include the exact same header keys; the exporter parses
what it can and omits missing fields.

SMB1/SMB2 metrics
Per-share blocks for SMB1/SMB2 contain metrics such as:

- `cifs_total_smbs`
- `cifs_total_oplocks_breaks`
- `cifs_total_reads`
- `cifs_total_reads_bytes`
- `cifs_total_writes`
- `cifs_total_writes_bytes`
- `cifs_total_flushes`
- `cifs_total_locks`
- `cifs_total_hardlinks`
- `cifs_total_symlinks`
- `cifs_total_opens`
- `cifs_total_closes`
- `cifs_total_deletes`
- `cifs_total_posix_opens`
- `cifs_total_posix_mkdirs`
- `cifs_total_mkdirs`
- `cifs_total_rmdirs`
- `cifs_total_renames`
- `cifs_total_findfirst`
- `cifs_total_fnext`
- `cifs_total_fclose`

SMB3 metrics
SMB3 blocks report metrics for request categories with `sent`/`failed` or
`total` semantics. Examples include:

- `cifs_total_negotiates_sent` / `cifs_total_negotiates_failed` (or `total`)
- `cifs_total_sessionsetups_sent` / `cifs_total_sessionsetups_failed`
- `cifs_total_logoffs_sent` / `cifs_total_logoffs_failed`
- `cifs_total_treeconnects_sent` / `cifs_total_treeconnects_failed`
- `cifs_total_creates_sent` / `cifs_total_creates_failed`
- `cifs_total_closes_sent` / `cifs_total_closes_failed`
- `cifs_total_flushes_sent` / `cifs_total_flushes_failed`
- `cifs_total_reads_sent` / `cifs_total_reads_failed` and optionally `cifs_total_reads_bytes`
- `cifs_total_writes_sent` / `cifs_total_writes_failed` and optionally `cifs_total_writes_bytes`
- `cifs_total_locks_sent` / `cifs_total_locks_failed`
- `cifs_total_ioctls_sent` / `cifs_total_ioctls_failed`
- `cifs_total_oplockbreaks_sent`

Labels
- `server` — the server host in the per-share block (e.g. `server2`)
- `share` — the share name in the per-share block (e.g. `share2`)

Example metric with labels:

```
cifs_total_negotiates_sent{server="server2",share="share2"} 0
```

Examples and sample outputs
--------------------------

See the `examples/` directory for sample `cifs-exporter.service` and sample
`example1.txt` and `example1_metrics.txt` files which show a Stats input and the
metric output respectively.

Systemd service example
-----------------------

An example `systemd` unit is provided in `examples/cifs-exporter.service`. Example snippet:

```
[Unit]
Description=CIFS Prometheus Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cifs-exporter -web.listen-address=":9965"
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Troubleshooting & Debugging
---------------------------

- Ensure `/proc/fs/cifs/Stats` exists on the host and contains data. If your
  system does not have any CIFS mounts, this file may be missing or empty.
- Use `-debug` to enable verbose logging which prints parsing decisions to stdout.
- If metrics appear missing, check that the exporter has permission to read
  `/proc/fs/cifs/Stats` (root or appropriate capabilities may be required).
- Differences in kernel versions can change the exact Stats format. This fork
  attempts to support both legacy `sent`/`failed` fields and newer `total` fields.

Contribution
------------

Contributions, bug reports and PRs are welcome. Please file issues or PRs against
this fork's repository and include:

- The kernel version (`uname -a`)
- A copy (or sanitized copy) of your `/proc/fs/cifs/Stats` file
- The exporter command-line and logs (if running with `-debug`)

License
-------

This project inherits the license of the upstream project (see `LICENSE` file in
this repo). Please consult the `LICENSE` file for the exact terms.

Contact
-------

For questions about this fork, open an issue in this repository.

Changelog (high level)
----------------------

- Forked from `shibumi/cifs-exporter` — added improved `cifs_up` detection, support
  for newer CIFS stats formats, and added debug logging.


Releases
--------

This repository provides two ways to produce release artifacts (prebuilt binaries):

1) GitHub Actions (recommended for CI releases)
- A release workflow is provided at `.github/workflows/release.yml` and is triggered in the following cases:
  - push to a tag that matches `v*` (for example `v1.0.1`)
  - a `create` event for tags (useful when creating tags/releases via the GitHub UI)
  - the GitHub `release` event when a release is published
  - manual `workflow_dispatch`

How to create and push an annotated tag that will trigger the workflow:

```bash
# create an annotated tag pointing at HEAD
git tag -a v1.0.1 -m "release v1.0.1"
# push the tag to origin (this must be pushed to GitHub to trigger workflows)
git push origin v1.0.1
```

Notes:
- Make sure the tag points to a commit that contains the `.github/workflows/release.yml` file. Workflows execute from the commit that triggered the event, so pushing a tag that points at a commit without the workflow will not run it.
- If the workflow still doesn't run, verify the tag exists on the remote with `git ls-remote --tags origin`.

2) Local build script (builds cross-platform archives locally)
- A convenience script is available at `build/build.sh` that produces tar.gz / zip packages for common platforms.

Example usage:

```bash
# create local artifacts with a version string embedded
./build/build.sh v1.0.1
# artifacts are produced under build/dist/
ls -R build/dist
```

The script cross-compiles for a set of GOOS/GOARCH targets and adds the `main.version` ldflag so the built binaries report the version when run with `-version`.

Automated releases using GoReleaser (CI)
---------------------------------------

The workflow tries to use GoReleaser via the GitHub Action `goreleaser/goreleaser-action` to produce cross-platform binaries and create a GitHub Release with assets. The action requires the `GITHUB_TOKEN` (automatically provided by GitHub Actions) and appropriate permissions (the workflow sets `contents: write` and `packages: write` for this reason).

If you prefer, you can create a release locally using GoReleaser (`brew install goreleaser` / `curl -sSfL`) and run:

```bash
# run GoReleaser locally (example)
goreleaser release --rm-dist
```

Troubleshooting release workflow
--------------------------------
- The most common reason a release job doesn't run is that the tag wasn't pushed to GitHub. Run `git ls-remote --tags origin` and confirm.
- Ensure the tag references a commit that contains `.github/workflows/release.yml` (workflows are resolved from that commit).
- For quick debugging, trigger the workflow manually via the Actions UI (`workflow_dispatch`).
- If you use branch protection or require PR merges, ensure the tag is created after the workflow file is present in the target branch.

About this fork (short)
-----------------------

This repository is a fork of the upstream project `shibumi/cifs-exporter`. The fork focuses on correctness and compatibility with newer Linux kernel CIFS stats formats and adds small improvements and fixes. If you rely on the upstream project's release artifacts, check the upstream repository: https://github.com/shibumi/cifs-exporter
