# Spiderweb Protocol SDK for TypeScript

Reference TypeScript implementation for the current Spiderweb public wire
surface:

- spiderweb-control
- Acheron runtime (`acheron-1`)
- node FS handshake and Acheron FS messages (`spiderweb-fs`)

The generated constants in [`src/generated.ts`](./src/generated.ts) come from
the canonical Zig implementation via `zig build sync-sdk`.

## Scope

- strict envelope parsing and validation
- envelope builders for control and Acheron messages
- base64 helpers for `data_b64`
- low-level `ControlClient`, `AcheronClient`, and `FsClient`
- built-in websocket transport for Node/Web-style runtimes with global
  `WebSocket`

## Limitations

- the bundled websocket transport does not inject custom HTTP headers; use a
  custom `TextTransport` when auth headers or other connection customization are
  required
- higher-level mounted-filesystem abstractions are intentionally out of scope

## Development

```bash
npm install
npm run check
npm run build
```
