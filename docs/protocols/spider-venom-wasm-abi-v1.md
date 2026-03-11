# Spider Venom WASM ABI v1

Status: generated from `sdk/spec/wasm_abi.json`

This document captures the current Spider Venom WASM ABI metadata exposed by the canonical Zig runtime. It is reference material for future SDK work; this milestone does not add language-specific venom authoring libraries.

## Exports
- `spider_venom_abi_version`
- `spider_venom_alloc`
- `spider_venom_invoke_json`

## Host Import Module

- `spider_host_v1`

## Host Imports

- `spider_host_capabilities() -> u64`
- `spider_host_now_ms() -> u64`
- `spider_host_log(level, ptr, len) -> u32`
- `spider_host_random_fill(ptr, len) -> u32`
- `spider_host_emit_event_json(ptr, len) -> u32`

## Capability Bits

- `0`: log
- `1`: clock
- `2`: random
- `3`: emit_event

## Related Canonical References

- `docs/protocols/namespace-driver-abi-v1.md`
- `sdk/spec/wasm_abi.json`
