# zsnoop Tool Selection

## Discovery And Health

- `list_hosts`: start here; returns configured host names and hints.
- `agent_info`: check remote agent version, methods, and limits.
- `list_pools`: discover live ZFS pools and health.
- `pool_status`: parse `zpool status`, scrub state, vdev tree, and errors.
- `list_datasets`: list filesystems and volumes.
- `dataset_properties`: read selected `zfs get` properties or all properties.

## Snapshot Inventory

- `list_snapshots`: list snapshots, preferably scoped by host, dataset, time
  window, and `max_results`.
- `snapshot_cadence`: summarize retention classes, earliest/latest snapshots,
  biggest gaps, and unique bytes.
- `stale_snapshots`: find old snapshots sorted by unique bytes.
- `size_delta`: compare bytes written between two snapshots of one dataset.

## Browse And Read Snapshot Content

- `list_dir`: bounded directory listing inside one snapshot.
- `size_breakdown`: recursive total plus per-child sizes.
- `top_consumers`: largest files/directories under a snapshot path.
- `read_file`: bounded content read; binary may return base64.
- `find_files`: fnmatch name search.
- `content_grep`: regex content search.
- `checksum_file`: SHA-256 a full file up to the server cap.

Use `find_files` or `content_grep` with `max_results` instead of walking a tree
with many `list_dir` calls.

## Compare And Trace Change

- `diff_snapshots`: path-level `+`, `-`, `M`, `R` diff between snapshots.
- `file_diff`: unified diff for one file between two snapshots.
- `file_history`: every snapshot version of one path.
- `versions_of`: distinct file versions collapsed by hash.
- `snapshots_containing`: snapshots where a path exists.
- `first_appearance`: earliest snapshot containing a path.
- `last_appearance`: latest snapshot containing a path.
- `find_deleted`: deleted paths between snapshots or across a time window.
- `bisect_change`: binary-search the snapshot where a predicate flips.

Time fields accept ISO 8601 or phrases such as `yesterday`, `last week`,
`3 days ago`, and `2 hours ago`.

## Recovery To Workstation

- `fetch_file`: copy one snapshot file to an absolute local path.
- `fetch_dir`: copy a snapshot directory tree to an absolute local path.

These are safer than server-side restore because they do not mutate the ZFS
host. They refuse unsafe paths and destination issues.

## Restore To Live Server

- `restore_file`: restore a snapshot file to a live server path.
- `restore_dir`: restore a snapshot directory tree to a live server path.

Use only when the user explicitly requests an in-place restore. Confirm:

1. The host has `allow_restore = true`.
2. `restore_paths` is non-empty and covers the target.
3. The target path is absolute.
4. `overwrite` and `backup` semantics match the user's intent.
5. Root-owned targets have `sudo = true` if needed.

Prefer `backup = true` when overwriting live content.

## Limits And Path Rules

- Leading `/` on snapshot paths is stripped.
- `..`, newline, carriage return, and NUL are rejected in paths.
- Symlinks are not followed.
- Reads, listings, searches, diffs, checksums, fetches, and restores are
  bounded by upstream limits and may return truncation flags.
- `read_file` is for bounded inspection; use `fetch_file` for real recovery.
