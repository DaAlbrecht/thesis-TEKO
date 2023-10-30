#import "@preview/tablex:0.0.5": tablex, cellx

== RabbitMQ

RabbitMQ is an open-source message broker software that is widely used for
building scalable and robust messaging systems. It provides a messaging
middleware that facilitates communication between different parts of a
distributed application. RabbitMQ is often used in scenarios where you need to
handle asynchronous communication, decouple components of a system, and ensure
reliable message delivery. It's particularly valuable in distributed systems,
and microservices architectures, as well as for implementing various messaging patterns
such as publish-subscribe, request-reply, and more.

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
one or multiple queues and receive messages as they arrive, or they can actively fetch messages
from the queue when they choose to do so.

== Exchange<exchange>

Exchanges are AMQP-0-9-1 entities. An exchange receives messages from producers
and pushes them to queues depending on rules called bindings. An exchange routes
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
It is a direct exchange with a pre-declared name that cannot be changed.
The default exchange routes every message it receives to a queue with the same name as the routing key of the message.

#figure(
image("../assets/rabbitmq_default_exchange.svg" ,width: 70%),
caption: [Default Exchange],
kind: image,
)


For instance, if you were to define a queue with the name "inventory" the AMQP
0-9-1 broker would automatically establish a binding to the default exchange,
using "inventory" as the binding key (also referred to as routing key, but this is
ambiguous and therefore not used here). Consequently, a message sent to the
default exchange with the routing key "inventory" will be directed to the "inventory"
queue. Essentially, the default exchange creates the illusion of delivering
messages directly to queues, even though that's not precisely what's occurring
from a technical standpoint.
The main difference between the default exchange and a direct exchange is, that
the default exchange cannot be explicitly bound to queues.

#pagebreak()

=== Direct Exchange 

A direct exchange@rabbitmq-direct-exchange operates by delivering messages to queues based on their
binding key. It is well-suited for single-target (unicast) message routing but
can also be applied to multicast routing scenarios.

Here is a breakdown of how it functions:

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

=== Topic Exchange

A topic exchange@rabbitmq-topic-exchange routes messages to queues based on
matching patterns between the routing key of the message and the binding key
used to establish a binding.

#figure(
image("../assets/rabbitmq_topic_exchange.svg" ,width: 70%),
caption: [Topic Exchange],
kind: image,
)

#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  left),
[*Wildcard*],
[*Description*],
[\* (star)],
[Matches exactly one word.],
[\# (hash)],
[Matches zero or more words.],
),
kind: table,
caption: [Topic Exchange Wildcards],
)

=== Headers Exchange 

A headers exchange@rabbitmq-headers-exchange routes messages based on the value
of attributes also known as headers that are associated with the message. In
this case, the routing key is not used. Instead, the attributes of the message
are evaluated against the attributes of the queue bindings#footnote([https://www.rabbitmq.com/tutorials/amqp-concepts.html#exchange-headers]). If they match, the
message is routed to the queue. 

== Queues

A RabbitMQ queue is a structured arrangement of messages, where messages are
added and removed in a FIFO manner, typically delivered to consumers. In a
general sense, a queue is a sequential data structure with two primary
operations: adding an item to the end (enqueuing) and removing an item from the
front (dequeuing).

In messaging systems, various features are closely tied to queues. Some of
RabbitMQ's queue features, like priorities#footnote([https://www.rabbitmq.com/queues.html#properties]) can
influence the order in which consumers perceive messages.

=== Streams

Streams@rabbitmq_about_streams are a new type of queue in the RabbitMQ ecosystem. Streams are a persistent and replicated data structure.
With the addition of streams, a new protocol was introduced, the RabbitMQ Streams protocol@rabbitmq_stream_spec.

Streams represent an immutable record of messages, allowing for multiple
readings until they expire. These streams maintain persistence and
replication consistently. 

When it comes to accessing messages within a RabbitMQ stream, one or more
consumers can subscribe to it and read the messages repeatedly, as many times as
needed.

The ability to read messages repeatedly is a significant advantage of streams
and what will be taken advantage of in the microservice.

==== Use Cases of streams

#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  left),
[*Use Case*],
[*Description*],
[Large fan-outs],
[Currently, when users aim to send a message to several subscribers, they must
create a unique queue for each consumer. This process can become inefficient,
particularly with a large number of consumers, especially when considering the
desire for message persistence and replication.

Streams will address this issue by enabling any number of consumers to access
the same messages from a single queue without causing any data loss. This
eliminates the necessity to establish multiple queues. Additionally, stream
consumers will have the capability to read from replicas, distributing the read
workload throughout the cluster.],
[Replay (Time-travelling)],
[Since all existing queue types in RabbitMQ operate with a consume behavior that
results in message removal from the queue once a consumer finishes processing
them, it's currently impossible to re-access messages that have already been
consumed.

Streams, however, will introduce a significant change by permitting consumers to
connect at any position within the message log and retrieve messages from that
point onward. This means that messages can be revisited and processed again as
needed.],
[Throughput Performance],
[Streams will provide a significant performance boost over the existing queue 
types.],
[Large backlogs],
[Most queues are designed to operate on an empty backlog. When a queue has a 
large backlog, it can cause performance issues. Streams will be able to handle
large backlogs without performance issues.],
),
kind: table,
caption: [Streams Use Cases],
)


#pagebreak()

== Protocols

RabbitMQ supports several protocols@rabbitmq-protocols:

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
therefore supported in a large number of clients and languages.],
[STOMP],
[STOMP is a text-based messaging protocol. STOMP emphasizes simplicity. It does
not define strict messaging semantics and is therefore easy to implement. It is
also the only protocol that can be used manually over telnet.],
[MQTT],
[MQTT is a binary communication protocol that places a strong emphasis on
lightweight publish/subscribe messaging. It is designed primarily for use with
resource-constrained devices. While it offers clear and well-defined messaging
principles for publish/subscribe interactions, it lacks similar specifications
for other messaging styles.],
[AMQP 1.0],
[Although they share a similar name, AMQP 1.0 is a completely different protocol
from AMQP 0-9-1. AMQP 1.0 places fewer semantic demands, making it easier to add
to existing brokers. Although it is easier to add to existing brokers, the
protocol is substantially more complex than AMQP 0-9-1 and there are fewer
client implementations.],
[HTTP and WebSockets],
[HTTP and WebSockets are not messaging protocols. RabbitMQ can transmit messages
over HTTP in the following ways:
- STOMP messaging using WebSockets.
- MQTT messaging using WebSockets.
- HTTP API to send and receive messages.],
[RabbitMQ Streams],
[The RabbitMQ Streams protocol is a new messaging protocol that is designed to be 
used with RabbitMQ Streams. It's still in development and subject to change.]
),
kind: table,
caption: [RabbitMQ Protocols],
)

The microservice needs to be able to queue a message again, therefore a streaming queue is used.
For working with streams, the best suited is either the AMQP-0-9-1 or the RabbitMQ-Streams protocol.

=== AMQP 0-9-1<amqp_0_9_1>

AMQP, also known as the Advanced Message Queuing Protocol, facilitates
communication between compliant client applications and matching messaging
middleware brokers.

In the next sections, we will take a brief look at the AMQP
wire-level format as specified in the AMQP 0-9-1 specification@amqp_0_9_1_spec.
This is the format that is used to send and receive messages over the network. The short excursion 
is intended to provide a better understanding of the AMQP 0-9-1 protocol and help evaluate a
suitable client library in @evaluation


==== AMQP Wire-Level Format

The client MUST start a new connection by sending a protocol header. This is an 8-byte sequence:
#figure(
rect(
```
+---+---+---+---+---+---+---+---+
|'A'|'M'|'Q'|'P'| 0 | 0 | 9 | 1 |
+---+---+---+---+---+---+---+---+
           8 bytes 
```,
fill: (rgb("#F5DEB3")),
)
,
caption: [AMQP Protocol Header],
)

The client and server then agree on a protocol version.
After this, the general format of a frame is as follows:

#figure(
rect(
```
0      1         3         7                     size+7      size+8
+------+---------+---------+     +-------------+ +-----------+
| type | channel | size    |     |   payload   | | frame-end |
+------+---------+---------+     +-------------+ +-----------+
  byte   short      long           'size' bytes     byte 
```,
 fill: (rgb("#F5DEB3")),
),
caption: [AMQP Frame Format],
kind: auto
)

There are four types of frames:

#figure(
tablex(
columns: (auto, auto),
rows:(auto),
align: (center + horizon,  center + horizon),
[*Type*],
[*Name*],
[1],
[Method],
[2],
[Header],
[3],
[Body],
[4],
[Heartbeat],
),
kind: table,
caption: [AMQP Frame Types],
)

The channel number is set to 0 for all global frames, whereas it ranges from 1
to 65535 for frames that are associated with a particular channel.

The size field indicates the payload's size, excluding the byte at the end of
the frame. Even though AMQP operates under the assumption of a dependable
protocol, we utilize the frame's end byte to identify framing errors that might
result from flawed client or server implementations.

#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  center + horizon),
[*Type*],
[*Payload*],
[Method],
cellx(fill: rgb("#F5DEB3"))[```
0          2           4
+----------+-----------+-------------- - -
| class-id | method-id | arguments...
+----------+-----------+-------------- - -
   short      short    ...```],
[Header],cellx()[```
0          2        4           12               14
+----------+--------+-----------+----------------+------------- - -
| class-id | weight | body size | property flags | property list...
+----------+--------+-----------+----------------+------------- - -
   short     short    long long      short           remainder...
```],
[Body],cellx(fill: rgb("#F5DEB3"))[```
+-----------------------+ +-----------+
| Opaque binary payload | | frame-end |
+-----------------------+ +-----------+
```],
[Heartbeat],
[no payload],
 ),
kind: table,
caption: [AMQP frame payloads],
 )

This is a general overview of the AMQP 0-9-1 protocol. For more details, see the AMQP 0-9-1 specification#footnote([https://www.rabbitmq.com/resources/specs/amqp0-9-1.pdf]).
AMQP-0-9-1 does not have first-class support for streaming queues but streams can be implemented using optional 'queue and consumer arguments' #footnote([https://www.rabbitmq.com/queues.html#optional-arguments]).

=== RabbitMQ Streams Protocol

The RabbitMQ Streams protocol is a new messaging protocol that is designed to be 
used with RabbitMQ Streams@rabbitmq_stream_spec. It is still in development and subject to change.
Similar to in @amqp_0_9_1, we take a short tour through the protocol to get a better understanding of the protocol.
For a more detailed and complete description, see the RabbitMQ Streams Protocol specification#footnote([https://github.com/rabbitmq/rabbitmq-server/blob/v3.12.x/deps/rabbitmq_stream/docs/PROTOCOL.adoc]).

==== Types 

#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  center + horizon),
[*Type*],
[*Description*],
[int8, int16, int32, int64],
[Signed integers of 8, 16, 32, and 64 bits, respectively, in big-endian order.],
[uint8, uint16, uint32, uint64],
[Unsigned integers of 8, 16, 32, and 64 bits, respectively, in big-endian order.],
[bytes],
[32-bit signed integer denoting the length of the bytes, followed by the bytes themselves. length of -1 indicates null.],
[string],
[16-bit signed integer denoting the length of the string, followed by the UTF-8 encoded string itself. length of -1 indicates null.],
[array],
[32-bit signed integer denoting the length of the array, followed by the repetition of the structure, notation uses \[\], e.g. \[int32\] for an array of int32.]
))

==== Frame Format 

Each frame is only composed of the size and the payload. The size is a 32-bit unsigned integer denoting the length of the payload in bytes.

#figure(
rect(
```
0      4               size+4
+------+---------------+
| size |    payload    |
+------+---------------+
 int32    'size' bytes
```,
fill: (rgb("#F5DEB3")),
),
kind: auto,
caption: [RabbitMQ Streams Frame Format],
)

The payload can be one of the following:

#figure(
tablex(
columns: (auto, 1fr),
rows:(auto),
align: (center + horizon,  center + horizon),
[*Type*],
[*Frame*],
[Request],
cellx()[```
0      2         4               8             size+8
+------+---------+---------------+-------------+
| key  | version | correlationId |   command   |
+------+---------+---------------+-------------+
 uint16  uint16      uint32       'size' bytes
```],
cellx()[Response],
cellx(fill: rgb("#F5DEB3"))[```
0      2         4               8              10
+------+---------+---------------+--------------+
| key  | version | correlationId | responseCode |
+------+---------+---------------+--------------+
 uint16  uint16      uint32           uint16
```],
[Command],
cellx()[```
0      2         4             size+4
+------+---------+-------------+
| key  | version |   content   |
+------+---------+-------------+
 uint16  uint16   'size' bytes
```],
),
kind: table,
caption: [RabbitMQ Streams Frame Types],
)

The key at the start of the protocol, tells the server what kind of command will follow. 

An example of a 'declarepublisher' request and the corresponding  response would look like this:

*Request*

#figure(
rect(
```
0      2         4               8              9                    9+size
+------+---------+---------------+--------------+--------------------+-------- - - 
| 0x01 | version | correlationId | publisherId  | publisherReference | stream
+------+---------+---------------+--------------+--------------------+-------- - -
 uint16  uint16      uint32           uint8         string(max255)     remainder... 
```,
fill: (rgb("#F5DEB3")),
),
kind: auto,
caption: [RabbitMQ Streams DeclarePublisherRequest Frame],
)

*Response*

#figure(
rect(
```
0        2         4               8              10
+--------+---------+---------------+--------------+
| 0x8001 | version | correlationId | responseCode |
+--------+---------+---------------+--------------+
 uint16    uint16       uint32           uint16
```,
fill: (rgb("#F5DEB3")),
),
kind: auto,
caption: [RabbitMQ Streams DeclarePublisherResponse Frame],
)

For a complete list of commands, see the RabbitMQ Streams Protocol specification#footnote([https://github.com/rabbitmq/rabbitmq-server/blob/v3.12.x/deps/rabbitmq_stream/docs/PROTOCOL.adoc#commands]).
#pagebreak()
