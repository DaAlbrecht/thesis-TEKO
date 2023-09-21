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

RabbitMQ, or rather AMQP-0-9-1 achieves this by decoupling the sending and receiving systems.
The sending system is called a producer and the receiving system is called a
consumer.

#figure(
image("../assets/rabbitmq_components.svg"),
caption: [RabbitMQ component overview],
kind: image,
)

A 'connection' represents a persistent, long-lived TCP connection established
between a client and a RabbitMQ broker. Within this connection, producers have
the capability to create 'channels,' which can be thought of as virtual
connections nested within the primary connection.

These channels serve as conduits for producers to transmit messages to an entity
known as an 'exchange,' which can be likened to a message-routing intermediary,
akin to a post office in a metaphorical sense. The primary function of the
exchange is to receive messages from producers and, based on predefined rules
called 'bindings,' route these messages to various queues.

In this context, a 'queue' acts as a storage buffer for messages. 

A binding is a relationship between an exchange and a queue. Additionally, a
binding can have an optional 'binding key' parameter that further refines the 
routing process. The binding key is a string that the exchange can use to 
determine how to route the message to the queue. The binding key is specific to
the exchange type. For an overview of the different exchange types, see @exchange-types.

Consumers have two options for interacting with queues: they can either passively subscribe to
a queue and receive messages as they arrive, or they can actively fetch messages
from the queue when they choose to do so.

== Exchange<exchange>

Exchanges are AMQP-0-9-1 entities. An exchange receives messages from producers
and pushes them to queues depending on rules called bindings. An exchange routs
a message to zero or more queues. AMQP-0-9-1 defines four types of
exchanges@rabbitmq-exchange-types:


#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  left),
[*Exchange Type*],
[*Default pre-declared names*],
[Direct exchange],
[(Empty string) and amq.direct],
[Fanout exchange],
[amq.fanout],
[Topic exchange],
[amq.topic],
[Headers exchange],
[amq.match (and amq.headers in RabbitMQ)]
),
kind: table,
caption: [Exchange Types],
)<exchange-types>

=== Default Exchange 

The default exchange@rabbitmq-default-exchange is an unattributed exchange provided by the broker without
a specific name (it's represented by an empty string). The default exchange is a RabbitMQ extension to the AMQP 0-9-1 direct exchange specification.
The default exchange routes every message it receives to a queue with the same name as the routing key of the message.

#figure(
image("../assets/rabbitmq_default_exchange.svg" ,width: 70%),
caption: [Default Exchange],
kind: image,
)


For instance, if you were to define a queue with the name "inventory" the AMQP
0-9-1 broker would automatically establish a binding to the default exchange,
using "inventory" as binding key (also refered as routing key, but this is
ambigous and therfore not used here). Consequently, a message sent to the
default exchange with the routing key "inventory" will be directed to the "inventory"
queue. Essentially, the default exchange creates the illusion of delivering
messages directly to queues, even though that's not precisely what's occurring
from a technical standpoint.

=== Direct Exchange 

A direct exchange@rabbitmq-direct-exchange operates by delivering messages to queues based on their
binding key. It is well-suited for single-target (unicast) message routing but
can also be applied to multicast routing scenarios.

Here's a breakdown of how it functions:

#figure(
image("../assets/rabbitmq_direct_exchange.svg" ,width: 70%),
caption: [Direct Exchange],
kind: image,
)

A queue establishes a binding with the exchange using a specific binding key,
denoted as K. Whenever a new message arrives at the direct exchange with a
routing key R, the exchange forwards it to the associated queue if and only if
the binding key K matches R. In cases where multiple queues are bound to the
same direct exchange with identical binding key K, the exchange will transmit
the message to all queues where K equals R.

=== Fanout Exchange 

A fanout exchange@rabbitmq-fanout-exchange distributes messages to every queue connected to it,
disregarding the routing key. If there are N queues linked to a fanout exchange,
when a new message is sent to the exchange, a duplicate of the message is
dispatched to all N queues. Fanout exchanges are perfectly suited for
broadcasting messages.

#figure(
image("../assets/rabbitmq_fanout_exchange.svg" ,width: 70%),
caption: [Fanout Exchange],
kind: image,
)

== Routing

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

