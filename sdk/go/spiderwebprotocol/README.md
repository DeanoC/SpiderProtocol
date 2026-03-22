# Spiderweb Protocol SDK for Go

Reference Go helpers for the current Spiderweb public wire surface:

- spiderweb-control
- Acheron runtime (`acheron-1`)
- node FS handshake and Acheron FS messages (`spiderweb-fs`)

The generated constants in [`generated.go`](./generated.go) come from
`zig build sync-sdk`.

## Scope

- strict envelope parsing and validation
- envelope builders for control and Acheron messages
- base64 helpers for `data_b64`
- low-level `ControlClient`, `AcheronClient`, and `FsClient`
- websocket text transport via [`github.com/gorilla/websocket`](https://github.com/gorilla/websocket)

## Development

```bash
go test ./...
```
