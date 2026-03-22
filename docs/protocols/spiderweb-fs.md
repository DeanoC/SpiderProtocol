# Spiderweb FS Protocol (`spiderweb-fs`)

Status: generated from `sdk/spec/protocol.json`

This is the canonical public reference for the node filesystem handshake and Acheron FS message family carried over websocket text frames on `/fs`.

## Constants

- handshake message: `acheron.t_fs_hello`
- required payload: `{"protocol":"spiderweb-fs","proto":2}`
- request correlation field: `tag`
- fs error message type: `acheron.err_fs`
- fs invalidation events: `acheron.e_fs_inval`, `acheron.e_fs_inval_dir`

## Required Node FS Handshake

1. Open websocket to `/fs`.
2. Send `acheron.t_fs_hello` with payload `{"protocol":"spiderweb-fs","proto":2}`.
3. Wait for `acheron.r_fs_hello`.

If FS auth is enforced, the hello payload may also include `auth_token`. Node-to-node flows may also include `node_id` and `node_secret`.

## Public Node FS Catalog

| Message | Category | Direction |
| --- | --- | --- || `acheron.t_fs_hello` | node_fs | request |
| `acheron.r_fs_hello` | node_fs | response |
| `acheron.t_fs_exports` | node_fs | request |
| `acheron.r_fs_exports` | node_fs | response |
| `acheron.t_fs_lookup` | node_fs | request |
| `acheron.r_fs_lookup` | node_fs | response |
| `acheron.t_fs_getattr` | node_fs | request |
| `acheron.r_fs_getattr` | node_fs | response |
| `acheron.t_fs_readdirp` | node_fs | request |
| `acheron.r_fs_readdirp` | node_fs | response |
| `acheron.t_fs_symlink` | node_fs | request |
| `acheron.r_fs_symlink` | node_fs | response |
| `acheron.t_fs_setxattr` | node_fs | request |
| `acheron.r_fs_setxattr` | node_fs | response |
| `acheron.t_fs_getxattr` | node_fs | request |
| `acheron.r_fs_getxattr` | node_fs | response |
| `acheron.t_fs_listxattr` | node_fs | request |
| `acheron.r_fs_listxattr` | node_fs | response |
| `acheron.t_fs_removexattr` | node_fs | request |
| `acheron.r_fs_removexattr` | node_fs | response |
| `acheron.t_fs_open` | node_fs | request |
| `acheron.r_fs_open` | node_fs | response |
| `acheron.t_fs_read` | node_fs | request |
| `acheron.r_fs_read` | node_fs | response |
| `acheron.t_fs_close` | node_fs | request |
| `acheron.r_fs_close` | node_fs | response |
| `acheron.t_fs_lock` | node_fs | request |
| `acheron.r_fs_lock` | node_fs | response |
| `acheron.t_fs_create` | node_fs | request |
| `acheron.r_fs_create` | node_fs | response |
| `acheron.t_fs_write` | node_fs | request |
| `acheron.r_fs_write` | node_fs | response |
| `acheron.t_fs_truncate` | node_fs | request |
| `acheron.r_fs_truncate` | node_fs | response |
| `acheron.t_fs_unlink` | node_fs | request |
| `acheron.r_fs_unlink` | node_fs | response |
| `acheron.t_fs_mkdir` | node_fs | request |
| `acheron.r_fs_mkdir` | node_fs | response |
| `acheron.t_fs_rmdir` | node_fs | request |
| `acheron.r_fs_rmdir` | node_fs | response |
| `acheron.t_fs_rename` | node_fs | request |
| `acheron.r_fs_rename` | node_fs | response |
| `acheron.t_fs_statfs` | node_fs | request |
| `acheron.r_fs_statfs` | node_fs | response |
| `acheron.e_fs_inval` | node_fs | event |
| `acheron.e_fs_inval_dir` | node_fs | event |
| `acheron.err_fs` | node_fs | error |

## FS Error Envelope

```json
{"channel":"acheron","type":"acheron.err_fs","tag":7,"ok":false,"error":{"errno":2,"message":"not found"}}
```

## Representative Fixtures

- `sdk/spec/fixtures/acheron/t_fs_lookup.request.json`
- `sdk/spec/fixtures/acheron/r_fs_lookup.response.json`
- `sdk/spec/fixtures/acheron/t_fs_read.request.json`
- `sdk/spec/fixtures/acheron/r_fs_read.response.json`
- `sdk/spec/fixtures/acheron/e_fs_inval.event.json`

## Notes

- Binary payload bytes are represented in JSON as `data_b64`.
- The older helper envelope family `{"t":"req"}` / `{"t":"res"}` / `{"t":"evt"}` remains internal and is not part of the public SDK surface.
