import {
  acheronMessageTypes,
  acheronRuntimeVersion,
  controlMessageTypes,
  controlProtocol,
  legacyRejectedAcheronMessageTypes,
  legacyRejectedControlMessageTypes,
  nodeFsProtocol,
  type AcheronMessageType,
  type ControlMessageType,
} from "./generated.js";

const controlMessageTypeSet = new Set<string>(controlMessageTypes);
const acheronMessageTypeSet = new Set<string>(acheronMessageTypes);
const legacyRejectedControlSet = new Set<string>(legacyRejectedControlMessageTypes);
const legacyRejectedAcheronSet = new Set<string>(legacyRejectedAcheronMessageTypes);

export interface ControlErrorPayload {
  code: string;
  message: string;
}

export interface AcheronErrorPayload {
  code?: string;
  errno?: number;
  message: string;
}

export interface ControlEnvelope<Payload = unknown> {
  channel: "control";
  type: ControlMessageType;
  id?: string;
  ok?: boolean;
  payload?: Payload;
  error?: ControlErrorPayload;
  [key: string]: unknown;
}

export interface AcheronEnvelope<Payload = unknown> {
  channel: "acheron";
  type: AcheronMessageType;
  tag?: number;
  ok?: boolean;
  payload?: Payload;
  error?: AcheronErrorPayload;
  [key: string]: unknown;
}

export type ParsedEnvelope<Payload = unknown> =
  | ControlEnvelope<Payload>
  | AcheronEnvelope<Payload>;

export class SpiderProtocolError extends Error {
  readonly code: string;
  readonly details?: unknown;

  constructor(code: string, message: string, details?: unknown) {
    super(message);
    this.name = "SpiderProtocolError";
    this.code = code;
    this.details = details;
  }
}

export interface TextTransport {
  send(text: string): Promise<void>;
  receive(): Promise<string>;
  close(code?: number, reason?: string): Promise<void> | void;
}

export class WebSocketTextTransport implements TextTransport {
  readonly #socket: WebSocket;
  readonly #pending: string[] = [];
  readonly #waiters: Array<{
    resolve: (message: string) => void;
    reject: (error: unknown) => void;
  }> = [];
  #closed = false;
  #closeError: SpiderProtocolError | null = null;

  private constructor(socket: WebSocket) {
    this.#socket = socket;
    socket.addEventListener("message", (event: MessageEvent) => {
      if (typeof event.data !== "string") {
        return;
      }
      const waiter = this.#waiters.shift();
      if (waiter) {
        waiter.resolve(event.data);
        return;
      }
      this.#pending.push(event.data);
    });
    socket.addEventListener("error", () => {
      this.#closeWithError(
        new SpiderProtocolError(
          "websocket_error",
          "websocket transport emitted an error event",
        ),
      );
    });
    socket.addEventListener("close", (event) => {
      this.#closeWithError(
        new SpiderProtocolError(
          "websocket_closed",
          `websocket closed (${event.code}) ${event.reason}`.trim(),
        ),
      );
    });
  }

  static async connect(
    url: string,
    protocols?: string | string[],
  ): Promise<WebSocketTextTransport> {
    if (typeof WebSocket === "undefined") {
      throw new SpiderProtocolError(
        "missing_websocket",
        "global WebSocket is not available; provide a custom TextTransport instead",
      );
    }

    const socket = new WebSocket(url, protocols);
    await new Promise<void>((resolve, reject) => {
      const cleanup = () => {
        socket.removeEventListener("open", handleOpen);
        socket.removeEventListener("error", handleError);
      };
      const handleOpen = () => {
        cleanup();
        resolve();
      };
      const handleError = () => {
        cleanup();
        reject(
          new SpiderProtocolError(
            "websocket_open_failed",
            "websocket connection failed before open",
          ),
        );
      };
      socket.addEventListener("open", handleOpen);
      socket.addEventListener("error", handleError);
    });
    return new WebSocketTextTransport(socket);
  }

  async send(text: string): Promise<void> {
    this.#throwIfClosed();
    this.#socket.send(text);
  }

  async receive(): Promise<string> {
    this.#throwIfClosed();
    const pending = this.#pending.shift();
    if (pending !== undefined) {
      return pending;
    }

    return new Promise<string>((resolve, reject) => {
      this.#waiters.push({ resolve, reject });
    });
  }

  async close(code?: number, reason?: string): Promise<void> {
    if (this.#closed) {
      return;
    }
    this.#closed = true;
    this.#socket.close(code, reason);
  }

  #throwIfClosed(): void {
    if (this.#closed) {
      throw this.#closeError ?? new SpiderProtocolError("transport_closed", "transport is closed");
    }
  }

  #closeWithError(error: SpiderProtocolError): void {
    if (this.#closed) {
      return;
    }
    this.#closed = true;
    this.#closeError = error;
    while (this.#waiters.length > 0) {
      const waiter = this.#waiters.shift();
      waiter?.reject(error);
    }
  }
}

export function encodeDataB64(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

export function decodeDataB64(dataB64: string): Uint8Array {
  const binary = atob(dataB64);
  const out = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    out[index] = binary.charCodeAt(index);
  }
  return out;
}

export function buildControlEnvelope<Payload = unknown>(
  type: ControlMessageType,
  options: { id?: string; ok?: boolean; payload?: Payload; error?: ControlErrorPayload } = {},
): ControlEnvelope<Payload> {
  return {
    channel: "control",
    type,
    ...(options.id !== undefined ? { id: options.id } : {}),
    ...(options.ok !== undefined ? { ok: options.ok } : {}),
    ...(options.payload !== undefined ? { payload: options.payload } : {}),
    ...(options.error !== undefined ? { error: options.error } : {}),
  };
}

export function buildControlAck<Payload = unknown>(
  type: Exclude<ControlMessageType, "control.error">,
  id?: string,
  payload?: Payload,
): ControlEnvelope<Payload> {
  return buildControlEnvelope(type, { id, ok: true, payload });
}

export function buildControlError(
  code: string,
  message: string,
  id?: string,
): ControlEnvelope<never> {
  return buildControlEnvelope("control.error", {
    id,
    ok: false,
    error: { code, message },
  });
}

export function buildAcheronEnvelope<Payload = unknown>(
  type: AcheronMessageType,
  options: { tag?: number; ok?: boolean; payload?: Payload; error?: AcheronErrorPayload } = {},
): AcheronEnvelope<Payload> {
  return {
    channel: "acheron",
    type,
    ...(options.tag !== undefined ? { tag: options.tag } : {}),
    ...(options.ok !== undefined ? { ok: options.ok } : {}),
    ...(options.payload !== undefined ? { payload: options.payload } : {}),
    ...(options.error !== undefined ? { error: options.error } : {}),
  };
}

export function buildAcheronResponse<Payload = unknown>(
  type: Exclude<AcheronMessageType, "acheron.error" | "acheron.err_fs" | "acheron.e_fs_inval" | "acheron.e_fs_inval_dir">,
  tag?: number,
  payload?: Payload,
): AcheronEnvelope<Payload> {
  return buildAcheronEnvelope(type, { tag, ok: true, payload });
}

export function buildAcheronError(
  code: string,
  message: string,
  tag?: number,
): AcheronEnvelope<never> {
  return buildAcheronEnvelope("acheron.error", {
    tag,
    ok: false,
    error: { code, message },
  });
}

export function buildAcheronFsError(
  errno: number,
  message: string,
  tag?: number,
): AcheronEnvelope<never> {
  return buildAcheronEnvelope("acheron.err_fs", {
    tag,
    ok: false,
    error: { errno, message },
  });
}

export function buildAcheronEvent<Payload = unknown>(
  type: Extract<AcheronMessageType, "acheron.e_fs_inval" | "acheron.e_fs_inval_dir">,
  payload?: Payload,
): AcheronEnvelope<Payload> {
  return buildAcheronEnvelope(type, { payload });
}

export function buildControlVersionRequest(id: string): ControlEnvelope<{ protocol: typeof controlProtocol }> {
  return buildControlEnvelope("control.version", {
    id,
    payload: { protocol: controlProtocol },
  });
}

export function buildControlConnectRequest(id: string): ControlEnvelope<Record<string, never>> {
  return buildControlEnvelope("control.connect", { id, payload: {} });
}

export function buildAcheronVersionRequest(
  tag: number,
  options: { msize?: number; version?: string } = {},
): AcheronEnvelope<Record<string, never>> {
  const version = options.version ?? acheronRuntimeVersion;
  const msize = options.msize ?? 1_048_576;
  return {
    channel: "acheron",
    type: "acheron.t_version",
    tag,
    msize,
    version,
  } as AcheronEnvelope<Record<string, never>>;
}

export function buildAcheronAttachRequest(
  tag: number,
  fid = 1,
): AcheronEnvelope<Record<string, never>> {
  return {
    channel: "acheron",
    type: "acheron.t_attach",
    tag,
    fid,
  } as AcheronEnvelope<Record<string, never>>;
}

export function buildFsHelloRequest(
  tag: number,
  payload: Record<string, unknown> = { protocol: nodeFsProtocol.protocol, proto: nodeFsProtocol.proto },
): AcheronEnvelope<Record<string, unknown>> {
  return buildAcheronEnvelope("acheron.t_fs_hello", { tag, payload });
}

export function parseEnvelope(input: string | Record<string, unknown>): ParsedEnvelope {
  const raw = typeof input === "string" ? safeParseJson(input) : input;
  if (!isRecord(raw)) {
    throw new SpiderProtocolError("invalid_envelope", "message must decode to a JSON object", raw);
  }

  const channel = expectString(raw, "channel");
  const type = expectString(raw, "type");
  if (channel === "control") {
    if (!type.startsWith("control.")) {
      throw new SpiderProtocolError("namespace_mismatch", "control channel requires a control.* type", raw);
    }
    if (legacyRejectedControlSet.has(type)) {
      throw new SpiderProtocolError("unsupported_legacy_type", `legacy control type ${type} is rejected`, raw);
    }
    if (!controlMessageTypeSet.has(type)) {
      throw new SpiderProtocolError("unsupported_type", `unsupported control type ${type}`, raw);
    }
    if ("id" in raw && raw.id !== undefined && typeof raw.id !== "string") {
      throw new SpiderProtocolError("invalid_id", "control id must be a string", raw);
    }
    return raw as ControlEnvelope;
  }

  if (channel === "acheron") {
    if (!type.startsWith("acheron.")) {
      throw new SpiderProtocolError("namespace_mismatch", "acheron channel requires an acheron.* type", raw);
    }
    if (legacyRejectedAcheronSet.has(type)) {
      throw new SpiderProtocolError("unsupported_legacy_type", `legacy acheron type ${type} is rejected`, raw);
    }
    if (!acheronMessageTypeSet.has(type)) {
      throw new SpiderProtocolError("unsupported_type", `unsupported acheron type ${type}`, raw);
    }
    if ("tag" in raw && raw.tag !== undefined && (typeof raw.tag !== "number" || !Number.isInteger(raw.tag))) {
      throw new SpiderProtocolError("invalid_tag", "acheron tag must be an integer", raw);
    }
    return raw as AcheronEnvelope;
  }

  throw new SpiderProtocolError("invalid_channel", `unsupported channel ${channel}`, raw);
}

export function stringifyEnvelope(envelope: ParsedEnvelope): string {
  return JSON.stringify(envelope);
}

export class ControlClient {
  readonly #transport: TextTransport;

  constructor(transport: TextTransport) {
    this.#transport = transport;
  }

  async negotiateVersion(id = "control-version"): Promise<ControlEnvelope<{ protocol: string }>> {
    return this.request("control.version", id, { protocol: controlProtocol }) as Promise<
      ControlEnvelope<{ protocol: string }>
    >;
  }

  async connect(id = "control-connect"): Promise<ControlEnvelope<Record<string, unknown>>> {
    return this.request("control.connect", id, {}) as Promise<
      ControlEnvelope<Record<string, unknown>>
    >;
  }

  async request(
    type: Exclude<ControlMessageType, "control.error">,
    id: string,
    payload?: unknown,
  ): Promise<ControlEnvelope> {
    await this.#transport.send(
      stringifyEnvelope(buildControlEnvelope(type, { id, payload })),
    );

    while (true) {
      const envelope = parseEnvelope(await this.#transport.receive());
      if (envelope.channel !== "control") {
        continue;
      }
      if (envelope.id !== id) {
        continue;
      }
      if (envelope.type === "control.error") {
        throw protocolErrorFromControlEnvelope(envelope);
      }
      return envelope;
    }
  }
}

export class AcheronClient {
  readonly #transport: TextTransport;

  constructor(transport: TextTransport) {
    this.#transport = transport;
  }

  async negotiateVersion(tag = 1, msize = 1_048_576): Promise<AcheronEnvelope> {
    return this.request(buildAcheronVersionRequest(tag, { msize }), "acheron.r_version");
  }

  async attach(tag = 2, fid = 1): Promise<AcheronEnvelope> {
    return this.request(buildAcheronAttachRequest(tag, fid), "acheron.r_attach");
  }

  async request(
    envelope: AcheronEnvelope,
    expectedType: AcheronMessageType,
    onEvent?: (event: AcheronEnvelope) => void,
  ): Promise<AcheronEnvelope> {
    await this.#transport.send(stringifyEnvelope(envelope));

    while (true) {
      const parsed = parseEnvelope(await this.#transport.receive());
      if (parsed.channel !== "acheron") {
        continue;
      }
      if (isAcheronEvent(parsed)) {
        onEvent?.(parsed);
        continue;
      }
      if (parsed.tag !== envelope.tag) {
        continue;
      }
      if (parsed.type === "acheron.error" || parsed.type === "acheron.err_fs") {
        throw protocolErrorFromAcheronEnvelope(parsed);
      }
      if (parsed.type !== expectedType) {
        throw new SpiderProtocolError(
          "unexpected_type",
          `expected ${expectedType} but received ${parsed.type}`,
          parsed,
        );
      }
      return parsed;
    }
  }
}

export class FsClient {
  readonly #acheron: AcheronClient;

  constructor(transport: TextTransport) {
    this.#acheron = new AcheronClient(transport);
  }

  async hello(tag = 1, payload: Record<string, unknown> = { protocol: nodeFsProtocol.protocol, proto: nodeFsProtocol.proto }): Promise<AcheronEnvelope> {
    return this.#acheron.request(buildFsHelloRequest(tag, payload), "acheron.r_fs_hello");
  }

  async lookup(tag: number, node: number, name: string): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_lookup", "acheron.r_fs_lookup", tag, {
      node,
      payload: { name },
    });
  }

  async getattr(tag: number, node: number): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_getattr", "acheron.r_fs_getattr", tag, {
      node,
      payload: {},
    });
  }

  async readdirp(tag: number, node: number, cookie = 0, count = 128): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_readdirp", "acheron.r_fs_readdirp", tag, {
      node,
      payload: { cookie, count },
    });
  }

  async open(tag: number, node: number, mode = "r"): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_open", "acheron.r_fs_open", tag, {
      node,
      payload: { mode },
    });
  }

  async read(tag: number, handle: number, offset = 0, count = 4096): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_read", "acheron.r_fs_read", tag, {
      h: handle,
      payload: { offset, count },
    });
  }

  async write(tag: number, handle: number, data: Uint8Array | string, offset = 0): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_write", "acheron.r_fs_write", tag, {
      h: handle,
      payload: { offset, data_b64: encodeDataB64(data) },
    });
  }

  async close(tag: number, handle: number): Promise<AcheronEnvelope> {
    return this.#requestFs("acheron.t_fs_close", "acheron.r_fs_close", tag, {
      h: handle,
      payload: {},
    });
  }

  async #requestFs(
    type: AcheronMessageType,
    expectedType: AcheronMessageType,
    tag: number,
    extra: Record<string, unknown>,
  ): Promise<AcheronEnvelope> {
    return this.#acheron.request({
      channel: "acheron",
      type,
      tag,
      ...extra,
    } as AcheronEnvelope, expectedType);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function safeParseJson(raw: string): Record<string, unknown> {
  try {
    return JSON.parse(raw) as Record<string, unknown>;
  } catch (error) {
    throw new SpiderProtocolError("invalid_json", "message is not valid JSON", error);
  }
}

function expectString(object: Record<string, unknown>, key: string): string {
  const value = object[key];
  if (typeof value !== "string") {
    throw new SpiderProtocolError("missing_field", `${key} must be a string`, object);
  }
  return value;
}

function isAcheronEvent(envelope: AcheronEnvelope): boolean {
  return envelope.type === "acheron.e_fs_inval" || envelope.type === "acheron.e_fs_inval_dir";
}

function protocolErrorFromControlEnvelope(envelope: ControlEnvelope): SpiderProtocolError {
  const error: Record<string, unknown> = isRecord(envelope.error) ? envelope.error : {};
  return new SpiderProtocolError(
    typeof error["code"] === "string" ? error["code"] : "control_error",
    typeof error["message"] === "string" ? error["message"] : "control request failed",
    envelope,
  );
}

function protocolErrorFromAcheronEnvelope(envelope: AcheronEnvelope): SpiderProtocolError {
  const error: Record<string, unknown> = isRecord(envelope.error) ? envelope.error : {};
  if (typeof error["errno"] === "number") {
    return new SpiderProtocolError(
      "acheron_fs_error",
      typeof error["message"] === "string" ? error["message"] : "acheron fs request failed",
      envelope,
    );
  }
  return new SpiderProtocolError(
    typeof error["code"] === "string" ? error["code"] : "acheron_error",
    typeof error["message"] === "string" ? error["message"] : "acheron request failed",
    envelope,
  );
}
