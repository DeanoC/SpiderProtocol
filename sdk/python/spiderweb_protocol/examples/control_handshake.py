import asyncio

from spiderweb_protocol import ControlClient, TextTransport


class DemoTransport(TextTransport):
    async def send_text(self, text: str) -> None:
        print("send:", text)

    async def receive_text(self) -> str:
        raise RuntimeError("provide a real websocket transport adapter")

    async def close(self) -> None:
        return None


async def main() -> None:
    client = ControlClient(DemoTransport())
    await client.negotiate_version("example-version")


asyncio.run(main())
