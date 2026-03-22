import {
  FsClient,
  WebSocketTextTransport,
} from "../src/index.js";

async function main(): Promise<void> {
  const transport = await WebSocketTextTransport.connect("ws://127.0.0.1:18891/fs");
  const client = new FsClient(transport);

  console.log(await client.hello(1));
  console.log(await client.lookup(2, 42, "README.md"));

  await transport.close();
}

void main();
