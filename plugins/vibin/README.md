# Vibin

Session workflow skills for committing, pushing, saving session documentation,
addressing GitHub PR comments, debugging CI, and scaffolding SWAG reverse-proxy
configs.

`create-swag-config` uses Vibin-managed `SWAG_*` settings plus direct SSH/file
writes. Configure `SWAG_EDGE_HOST`, `SWAG_PUBLIC_BASE_DOMAIN`, and
`SWAG_PROXY_CONFS_PATH` through plugin settings or environment variables before
using it.
