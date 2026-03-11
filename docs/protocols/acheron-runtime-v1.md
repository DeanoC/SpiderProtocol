# Acheron Runtime Protocol (`acheron-1`)

Status: generated from `sdk/spec/protocol.json`

This reference covers the public Acheron runtime message envelope used before node-FS specific operations. The source of truth is the current Zig implementation in `unified_types.zig`, `unified_parse.zig`, and `unified_build.zig`.

## Constants

- runtime version: `acheron-1`
- channel: `acheron`
- request correlation field: `tag`
- generic error message type: `acheron.error`

## Envelope Rules

- Every runtime message must include `channel: "acheron"`.
- Every `type` must be in the `acheron.*` namespace.
- Runtime requests correlate by `tag`.
- Generic runtime errors use `acheron.error`.

## Required Runtime Handshake

1. Send `acheron.t_version` with `version: "acheron-1"`.
2. Wait for `acheron.r_version`.
3. Send `acheron.t_attach`.
4. Wait for `acheron.r_attach`.

## Public Runtime Catalog

| Message | Category | Direction |
| --- | --- | --- || `acheron.t_version` | runtime | request |
| `acheron.r_version` | runtime | response |
| `acheron.t_attach` | runtime | request |
| `acheron.r_attach` | runtime | response |
| `acheron.t_walk` | runtime | request |
| `acheron.r_walk` | runtime | response |
| `acheron.t_open` | runtime | request |
| `acheron.r_open` | runtime | response |
| `acheron.t_read` | runtime | request |
| `acheron.r_read` | runtime | response |
| `acheron.t_write` | runtime | request |
| `acheron.r_write` | runtime | response |
| `acheron.t_stat` | runtime | request |
| `acheron.r_stat` | runtime | response |
| `acheron.t_clunk` | runtime | request |
| `acheron.r_clunk` | runtime | response |
| `acheron.t_flush` | runtime | request |
| `acheron.r_flush` | runtime | response |
| `acheron.error` | runtime | error |

## Generic Error Envelope

```json
{"channel":"acheron","type":"acheron.error","tag":5,"ok":false,"error":{"code":"forbidden","message":"..."}}
```

See fixture: `sdk/spec/fixtures/acheron/error.response.json`.

## Explicit Exclusions
- `acheron.t_hello`
- `acheron.fs_t_*`
- `acheron.fs_r_*`
- `acheron.fs_evt_*`
- `acheron.fs_error`
- internal helper envelopes such as `{"t":"req"}` are implementation detail only
