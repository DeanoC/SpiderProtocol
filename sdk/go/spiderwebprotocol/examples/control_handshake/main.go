package main

import (
	"context"
	"log"

	"spiderwebprotocol"
)

func main() {
	ctx := context.Background()

	transport, err := spiderwebprotocol.DialWebSocketTextTransport(
		ctx,
		"ws://127.0.0.1:18790/",
		nil,
	)
	if err != nil {
		log.Fatal(err)
	}
	defer transport.Close()

	client := spiderwebprotocol.NewControlClient(transport)

	versionAck, err := client.NegotiateVersion(ctx, "example-version")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("version ack: %#v", versionAck)

	connectAck, err := client.Connect(ctx, "example-connect")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("connect ack: %#v", connectAck)
}
