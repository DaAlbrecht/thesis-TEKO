#import "@preview/tablex:0.0.5": tablex, cellx

== RabbitMQ

RabbitMQ is an open-source message broker software that is widely used for
building scalable and robust messaging systems. It provides a messaging
middleware that facilitates communication between different parts of a
distributed application. RabbitMQ is often used in scenarios where you need to
handle asynchronous communication, decouple components of a system, and ensure
reliable message delivery. It's particularly valuable in distributed systems,
microservices architectures, and for implementing various messaging patterns
like publish-subscribe, request-reply, and more.

#figure(
image("../assets/rabbitMQ.svg"),
caption: [RabbitMQ component overview],
kind: image,
)

== Exchange

== Queues

=== Streams

=== Comparasion Queues vs Streams

== Protocols

RabbitMQ supports several protocols@rabbitmq-protocols

#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  left),
[*Protocol*],
[*Description*],
[AMQP 0-9-1],
[AMQP is the fundamental protocol used by RabbitMQ. RabbitMQ was initially 
created to facilitate the use of AMQP. AMQP is a binary protocol that defines
strong messaging semantics. The protocol is easy to implement for clients and is
therfore supported in a large number of clients and languages.],
[STOMP],
[STOMP is a text-based messaging protocol. STOMP emphasizes simplicity. It does
not define strict messaging semantics and is therefore easy to implement. Its
also the only protocol that can be used manually over telnet],
[MQTT],
[MQTT is a binary communication protocol that places a strong emphasis on
lightweight publish/subscribe messaging. It is designed primarily for use with
resource-constrained devices. While it offers clear and well-defined messaging
principles for publish/subscribe interactions, it lacks similar specifications
for other messaging styles.],
[AMQP 1.0],
[Although they share a similar name, AMQP 1.0 is a completely different protocol
from AMQP 0-9-1. AMQP 1.0 places fewer semantic demands, making it easier to add
to existing brokers. Although its easier to add to existing brokers, the
protocol is substantially more complex than AMQP 0-9-1 and there are fewer
client implementations],
[HTTP and WebSockets],
[HTTP and WebSockets are not messaging protocols. RabbitMQ can transmit messages
over HTTP in the following ways:
- STOMP messaging using WebSockets.
- MQTT messaging using WebSockets.
- HTTP API to send and receive messages.],
[RabbitMQ Streams],
[The RabbitMQ Streams protocol is a new messaging protocol that is designed to be 
used with RabbitMQ Streams. Its still in development and subject to change.]
),
kind: table,
caption: [RabbitMQ Protocols],
)

The microservice needs to be able to queue a message again, therfore a streaming queue is used.
For working with streams, best suited is either the AMQP-0-9-1 or the RabbitMQ-Streams protocol.

=== AMQP 0-9-1

AMQP, also known as the Advanced Message Queuing Protocol, facilitates
communication between compliant client applications and matching messaging
middleware brokers.

=== RabbitMQ Streams Protocol

