package main

import (
	amqp "github.com/rabbitmq/amqp091-go"
	"time"
)

func main() {
	connectionString := "amqp://guest:guest@localhost:5672/"
	connection, _ := amqp.Dial(connectionString)

	channel, _ := connection.Channel()
	channel.ExchangeDeclare("golang-exchange", "direct", true, false, false, false, nil)

	Queueargs := make(amqp.Table)
	Queueargs["x-queue-type"] = "stream"
	channel.QueueDeclare("golang-queue", true, false, false, false, Queueargs)
	channel.QueueBind("golang-queue", "golang-exchange", "golang-exchange", false, nil)

	args := make(amqp.Table)
	args["x-stream-offset"] = "first"
	channel.Qos(100, 0, false)

	go func() {
		stream, err := channel.Consume("golang-queue", "", false, false, false, false, args)
		if err != nil {
			panic(err)
		}
		for message := range stream {
			println(string(message.Body))
		}
	}()
	channel_b, _ := connection.Channel()

	for {
		channel_b.Publish("golang-exchange", "golang-exchange", false, false, amqp.Publishing{
			Body: []byte("Hello World"),
		})
		time.Sleep(100 * time.Millisecond)
		println("Message sent")
	}

}
