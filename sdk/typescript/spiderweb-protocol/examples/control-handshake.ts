import {
  ControlClient,
  WebSocketTextTransport,
} from "../src/index.js";

async function main(): Promise<void> {
  const transport = await WebSocketTextTransport.connect("ws://127.0.0.1:18790/");
  const client = new ControlClient(transport);

  console.log(await client.negotiateVersion("example-version"));
  console.log(await client.connect("example-connect"));

  await transport.close();
}

void main();
