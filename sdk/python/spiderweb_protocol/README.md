# Spiderweb Protocol SDK for Python

Reference Python helpers for the current Spiderweb public wire surface:

- unified-v2 control
- Acheron runtime (`acheron-1`)
- node FS handshake and Acheron FS messages (`unified-v2-fs`)

The generated constants in `spiderweb_protocol/generated.py` come from
`zig build sync-sdk`.

This package stays transport-agnostic by default. Supply your own async
transport adapter that can send and receive text websocket frames.

If you want a bundled websocket adapter, install the optional `websocket`
extra and use `WebSocketTextTransport.connect(...)`.
