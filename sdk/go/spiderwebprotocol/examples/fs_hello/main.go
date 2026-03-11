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
		"ws://127.0.0.1:18891/v2/fs",
		nil,
	)
	if err != nil {
		log.Fatal(err)
	}
	defer transport.Close()

	client := spiderwebprotocol.NewFsClient(transport)

	helloAck, err := client.Hello(ctx, 1, nil)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("fs hello ack: %#v", helloAck)

	lookupAck, err := client.Lookup(ctx, 2, 1, "README.md")
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("lookup ack: %#v", lookupAck)
}
