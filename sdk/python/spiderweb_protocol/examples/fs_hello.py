import asyncio

from spiderweb_protocol import FsClient, TextTransport


class DemoTransport(TextTransport):
    async def send_text(self, text: str) -> None:
        print("send:", text)

    async def receive_text(self) -> str:
        raise RuntimeError("provide a real websocket transport adapter")

    async def close(self) -> None:
        return None


async def main() -> None:
    client = FsClient(DemoTransport())
    await client.hello()


asyncio.run(main())
