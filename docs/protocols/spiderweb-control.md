# Spiderweb Control Protocol (`spiderweb-control`)

Status: generated from `sdk/spec/protocol.json`

This is the canonical control-plane reference for public Spiderweb clients. The source of truth is the current Zig implementation in `unified_types.zig`, `unified_parse.zig`, and `unified_build.zig`.

## Constants

- protocol name: `spiderweb-control`
- websocket endpoint: control lives on the base websocket path (`/`)
- request correlation field: `id`
- error message type: `control.error`

## Envelope Rules

- Every message must include `channel: "control"`.
- Every message must include a `type` in the `control.*` namespace.
- `id` is required for request/response correlation in normal client flows.
- `control.error` uses `ok: false` plus `error.code` and `error.message`.
- Legacy control names rejected by the current parser are excluded from this reference.

## Required Handshake

1. Send `control.version` with payload `{"protocol":"spiderweb-control"}`.
2. Wait for `control.version_ack`.
3. Send `control.connect`.
4. Wait for `control.connect_ack`.

## Public Message Catalog

| Message | Category | Direction |
| --- | --- | --- || `control.version` | handshake | request |
| `control.version_ack` | handshake | response |
| `control.connect` | handshake | request |
| `control.connect_ack` | handshake | response |
| `control.session_attach` | session | request |
| `control.session_status` | session | request |
| `control.mount_attach` | mount | request |
| `control.mount_graph_delta` | mount | event |
| `control.mount_file_read` | mount | request |
| `control.mount_file_write` | mount | request |
| `control.mount_path_readlink` | mount | request |
| `control.mount_path_mkdir` | mount | request |
| `control.mount_path_unlink` | mount | request |
| `control.mount_path_rmdir` | mount | request |
| `control.mount_path_rename` | mount | request |
| `control.mount_path_symlink` | mount | request |
| `control.mount_path_setxattr` | mount | request |
| `control.mount_path_getxattr` | mount | request |
| `control.mount_path_listxattr` | mount | request |
| `control.mount_path_removexattr` | mount | request |
| `control.mount_path_lock` | mount | request |
| `control.mount_path_setattr` | mount | request |
| `control.session_resume` | session | request |
| `control.session_list` | session | request |
| `control.session_close` | session | request |
| `control.session_restore` | session | request |
| `control.session_history` | session | request |
| `control.ping` | operations | request |
| `control.pong` | operations | response |
| `control.metrics` | operations | request |
| `control.auth_status` | auth | request |
| `control.auth_rotate` | auth | request |
| `control.node_invite_create` | node | request |
| `control.node_join_request` | node | request |
| `control.node_join_pending_list` | node | request |
| `control.node_join_approve` | node | request |
| `control.node_join_deny` | node | request |
| `control.node_join` | node | request |
| `control.node_ensure` | node | request |
| `control.node_lease_refresh` | node | request |
| `control.venom_bind` | venom | request |
| `control.venom_upsert` | venom | request |
| `control.venom_get` | venom | request |
| `control.node_list` | node | request |
| `control.node_get` | node | request |
| `control.node_delete` | node | request |
| `control.workspace_create` | workspace | request |
| `control.workspace_update` | workspace | request |
| `control.workspace_delete` | workspace | request |
| `control.workspace_list` | workspace | request |
| `control.workspace_get` | workspace | request |
| `control.workspace_template_list` | workspace | request |
| `control.workspace_template_get` | workspace | request |
| `control.workspace_mount_set` | workspace | request |
| `control.workspace_mount_remove` | workspace | request |
| `control.workspace_mount_list` | workspace | request |
| `control.workspace_bind_set` | workspace | request |
| `control.workspace_bind_remove` | workspace | request |
| `control.workspace_bind_list` | workspace | request |
| `control.workspace_token_rotate` | workspace | request |
| `control.workspace_token_revoke` | workspace | request |
| `control.workspace_activate` | workspace | request |
| `control.workspace_up` | workspace | request |
| `control.workspace_status` | workspace | request |
| `control.reconcile_status` | workspace | request |
| `control.audit_tail` | audit | request |
| `control.packages_list` | venom | request |
| `control.packages_catalog` | venom | request |
| `control.packages_updates` | venom | request |
| `control.packages_update` | venom | request |
| `control.packages_update_all` | venom | request |
| `control.packages_get` | venom | request |
| `control.packages_channel_get` | venom | request |
| `control.packages_channel_set` | venom | request |
| `control.packages_channel_clear` | venom | request |
| `control.packages_install` | venom | request |
| `control.packages_enable` | venom | request |
| `control.packages_switch` | venom | request |
| `control.packages_disable` | venom | request |
| `control.packages_rollback` | venom | request |
| `control.packages_remove` | venom | request |
| `control.error` | error | error |

## Error Envelope

Canonical error shape:

```json
{"channel":"control","type":"control.error","id":"req-1","ok":false,"error":{"code":"missing_field","message":"..."}}
```

See fixture: `sdk/spec/fixtures/control/error.response.json`.

## Explicit Exclusions

These names are not part of the public protocol surface represented here:
- `session.send`
- `control.debug_subscribe`
- `control.debug_unsubscribe`
- `control.node_service_watch`
- `control.node_service_unwatch`
- `control.node_service_event`
- `control.venom_watch`
- `control.venom_unwatch`
- `control.venom_event`
