#import "@preview/tablex:0.0.5": tablex, cellx
#import "@preview/codelst:1.0.0": sourcecode

== API Library

To interact with RabbitMQ streams, a client library is needed.
There are two different types of client libraries

- An AMQP 0.9.1 client library that can specify optional queue and consumer arguments#footnote([https://www.rabbitmq.com/streams.html#usage])
- RabbitMQ streams client libraries that support the new protocol#footnote([https://www.rabbitmq.com/devtools.html])

Since the streaming protocol is still subject to change, and the microservice is
not acting as a high throughput consumer or publisher the extra speed, gained
with the streaming protocol is not needed. Additionally, after a brief
exploration of the documentation and examples for the streaming protocol appeared
to be less well-maintained compared to the AMQP 0.9.1 client libraries, leading
to encounters with broken code snippets and API changes.

As a result, I decided to exclude the RabbitMQ stream client libraries from
consideration and instead concentrate on evaluating the AMQP 0.9.1 client
libraries, which offer support for optional queue and consumer arguments.

To evaluate the AMQP 0.9.1 client libraries, I created a simple publisher and
consumer application, which publishes a message to a queue and then consumes it.
This simple demo application was then used to evaluate the client libraries.

*Setup*

For this application, I used RabbitMQ deployed as a docker container. RabbitMQ 
can be deployed with the following command:
#figure(
sourcecode(numbering: none)[```bash 
docker run -it --rm --name rabbitmq -p 5552:5552 -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management
```],
caption: "RabbitMQ as docker container",
)<api-lib-setup>

The RabbitMQ management interface can be accessed at #link("http://localhost:15672/") with
the following credentials: 

- username: guest
- password: guest

=== Rust - lapin 

Rust is my most familiar language. I have used it for many different projects.
There are several different client libraries available for Rust, but I decided
to use lapin, because it is the most popular and well-maintained client library.

==== Installation 

lapin is available on crates.io, the Rust package registry. It can be installed with the following command:
#figure(
sourcecode(numbering: none)[```bash 
cargo add lapin 
```],
caption: "lapin installation",
)

Additionally, lapin requires an asynchronous runtime. I decided to use tokio,
because it is the most popular asynchronous runtime for Rust.

#figure(
sourcecode(numbering: none)[```bash 
cargo add tokio --features full
```],
caption: "tokio installation",
)

==== API usage 

First, the clients need to establish a connection to the RabbitMQ server.
The server is running on localhost and the default port is 5672. The credentials
are the default credentials for RabbitMQ.

With the following code snippets, a connection to the RabbitMQ server is established.

#figure(
sourcecode()[```rs
#[tokio::main]
async fn main() -> Result<()> {
    let channel = create_rmq_connection(
        "amqp://guest:guest@localhost:5672".to_string(),
        "connection_name".to_string(),
    )
    .await;
    Ok(()) 
}
    ``` 
    ],
    caption: "lapin connection main", 
)

The process of establishing a connection is a bit more complicated compared to other languages due to the asynchronous nature of Rust.
To make the code more idiomatic, the connection is established in a separate function.

#figure(
sourcecode()[```rs
pub async fn create_rmq_connection(connection_string: String, connection_name: String) -> Channel {
    let start_time = Instant::now();
    let options = ConnectionProperties::default()
        .with_connection_name(connection_name.into())
        .with_executor(tokio_executor_trait::Tokio::current())
        .with_reactor(tokio_reactor_trait::Tokio);
    loop {
        let connection = Connection::connect(connection_string.as_ref(), options.clone())
            .await
            .unwrap();
        if let Ok(channel) = connection.create_channel().await {
            return channel;
        }
        assert!(
            start_time.elapsed() < std::time::Duration::from_secs(2 * 60),
            "Failed to connect to RabbitMQ"
        );
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }
}
```],
caption: "lapin connection",
)

Rust does not have a built-in asynchronous runtime. Instead, it relies on
external asynchronous runtimes. lapin supports several different asynchronous
runtimes. This makes it a bit more complicated to establish a connection compared
to other languages, where the asynchronous runtime is built into the language.

#figure(
sourcecode()[```rs 
let options = ConnectionProperties::default()
        .with_connection_name(connection_name.into())
        .with_executor(tokio_executor_trait::Tokio::current())
        .with_reactor(tokio_reactor_trait::Tokio);
```],
caption: "lapin connection options",
)

After setting up the connection options, a connection is tried to be established.
If the connection is successful, a channel is created and returned. 
If the connection is not established within 2 minutes, the program exits.

#figure(
sourcecode()[```rs 
loop {
    let connection = Connection::connect(connection_string.as_ref(), options.clone())
        .await
        .unwrap();
    if let Ok(channel) = connection.create_channel().await {
        return channel;
    }
    assert!(
        start_time.elapsed() < std::time::Duration::from_secs(2 * 60),
        "Failed to connect to RabbitMQ"
    );
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
}
```],
caption: "lapin connection loop",
)

After the connection is established, an exchange is created. 

#figure(
sourcecode()[```rs
channel
    .exchange_declare(
        "baz_exchange",
        ExchangeKind::Direct,
        declare_options,
        FieldTable::default(),
    )
    .await?;
```],
caption: "lapin exchange declaration",
)

After the exchange is created, a queue is created.

#figure(
sourcecode()[```rs
channel
    .queue_declare(
        "foo_queue",
        QueueDeclareOptions {
            durable: true,
            auto_delete: false,
            ..Default::default()
        },
        stream_declare_args(),
    )
    .await
    .context("Failed to create stream")?;
```],
caption: "lapin queue declaration",
)

The `queue_declare` function takes additional arguments with the type
`FieldTable`#footnote(
  [https://docs.rs/amq-protocol-types/7.1.2/amq_protocol_types/struct.FieldTable.html],
).
These additional arguments are used to specify the optional queue and consumer
arguments needed for RabbitMQ streams.

#figure(
sourcecode()[```rs
pub fn stream_declare_args() -> FieldTable {
    let mut queue_args = FieldTable::default();
    queue_args.insert(
        ShortString::from("x-queue-type"),
        AMQPValue::LongString("stream".into()),
    );
    queue_args.insert(
        ShortString::from("x-max-length-bytes"),
        AMQPValue::LongLongInt(600000000),
    );
    queue_args.insert(
        ShortString::from("x-stream-max-segment-size-bytes"),
        AMQPValue::LongLongInt(500000000),
    );
    queue_args
}
```],
caption: "lapin queue arguments",
)

Mainly the `x-queue-type` argument is used to specify the queue as a stream
queue. The `x-max-length-bytes` argument is used to specify the maximum size of
the queue in bytes. The `x-stream-max-segment-size-bytes` argument is used to
specify the maximum size of a segment in bytes.


After the queue is created, a new thread is spawned, which is used to consume messages from the queue.

#figure(
sourcecode()[```rs
tokio::spawn(async move {
    let channel_b = create_rmq_connection(
        "amqp://guest:guest@localhost:5672".to_string(),
        "connection_name".to_string(),
    )
    .await;

    channel_b
        .basic_qos(1000u16, BasicQosOptions { global: false })
        .await
        .unwrap();

    let mut consumer = channel_b
        .basic_consume(
            "foo_queue",
            "foo_consumer",
            BasicConsumeOptions::default(),
            stream_consume_args(),
        )
        .await
        .unwrap();

    while let Some(delivery) = consumer.next().await {
        println!("Received message");
        let delivery_tag = delivery.expect("error in consumer").delivery_tag;
        channel_b
            .basic_ack(delivery_tag, BasicAckOptions::default())
            .await
            .expect("ack");
    }
});
```],
caption: "lapin consume messages",
)

the `basic_consume` function also takes additional arguments with the type `FieldTable`#footnote(
  [https://docs.rs/amq-protocol-types/7.1.2/amq_protocol_types/struct.FieldTable.html],
). 
These arguments are created with the `stream_consume_args` function.

#figure(
sourcecode()[```rs 
pub fn stream_consume_args() -> FieldTable {
    let mut queue_args = FieldTable::default();
    queue_args.insert(
        ShortString::from("x-stream-offset"),
        AMQPValue::LongString("first".into()),
    );
    queue_args
}
```],
caption: "lapin consume arguments",
)

The `x-stream-offset` argument is used to specify the offset from which the consumer should start consuming messages@x-stream-offset

The main thread concurrently publishes a message to the queue, the consumer thread is consuming messages from.

#figure(
sourcecode()[```rs
loop {
    println!("Publishing message");
    channel
        .basic_publish(
            "baz_exchange",
            "baz_exchange",
            BasicPublishOptions::default(),
            b"Hello world!",
            AMQPProperties::default(),
        )
        .await?;
    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
}
```],
caption: "lapin publish message",
)

This publishes a message to the exchange `baz_exchange` with the routing key `baz_exchange`. The payload of the message is `Hello world!`.

=== Java - rabbitmq-java-client

TODO: add short introduction



==== Installation 

The rabbitmq-java-client is available on maven central. It can be installed by adding the following dependency to the pom.xml file.

#figure(
sourcecode(numbering: none)[```xml 
<dependency>
    <groupId>com.rabbitmq</groupId>
    <artifactId>amqp-client</artifactId>
    <version>5.18.0</version>
</dependency>
```],
caption: "rabbitmq-java-client installation",
)

==== API usage 

Similar to Lapin, first a connection to the RabbitMQ server is established.

#figure(
sourcecode()[```java 
ConnectionFactory factory = new ConnectionFactory();
factory.setUri("amqp://guest:guest@127.0.0.1:5672");
Connection conn = factory.newConnection();
System.out.println("Connection established");
``` 
],
caption: "rabbitmq-java-client connection",
)

After the connection is established, a new thread is spawned, which is used to
consume messages from the queue. This thread gets its own channel.

#figure(sourcecode()[```java
new Thread(() -> {
    try {
        Channel channel = conn.createChannel();

        channel.exchangeDeclare(exchangeName, "direct", true);
        System.out.println("Exchange declared");
        channel.queueDeclare(
                "java-stream",
                true, // durable
                false, false, // not exclusive, not auto-delete
                Collections.singletonMap("x-queue-type", "stream"));
        channel.queueBind("java-stream", exchangeName, exchangeName);

        channel.basicQos(100); // QoS must be specified
        channel.basicConsume(
                "java-stream",
                false,
                Collections.singletonMap("x-stream-offset", "first"), // "first" offset specification
                (consumerTag, message) -> {
                    System.out.println("Received message: " + new String(message.getBody(), "UTF-8"));
                    channel.basicAck(message.getEnvelope().getDeliveryTag(), false); // ack is required
                },
                consumerTag -> {
                });
    } catch (IOException e) {
        e.printStackTrace();
    }
}).start();
```], caption: "rabbitmq-java-client consume messages")

In the same way as with lapin, the queue is declared as a stream queue with the
`x-queue-type` argument. The only difference between the two clients is that
lapin returns an iterator over the messages, while rabbitmq-java-client uses a
callback function to consume messages. Otherwise, the two clients are very
similar.

#linebreak()

In the main thread, a new channel is created, which is used to publish messages to the queue.

#figure(
sourcecode()[```java 
while (true) {
    byte[] messageBodyBytes = "Hello, world!".getBytes();
    channel_b.basicPublish(exchangeName, exchangeName, null, messageBodyBytes);
    System.out.println("Sent message: " + new String(messageBodyBytes, "UTF-8"));
}
```],
caption: "rabbitmq-java-client publish message",
)

The Publishing of messages is also very similar to lapin.

=== Go - amqp091-go

==== Installation 

The amqp091-go client library is available on GitHub. It can be installed with the following command:

#figure(
sourcecode(numbering: none)[```bash 
go get https://github.com/rabbitmq/amqp091-go```],
caption: "amqp091-go installation",
)

The library changed its name from `streadway/amqp` to `rabbitmq/amqp091-go`. To reduce friction with the api documentation and examples, an alias is advised.

#figure(
sourcecode(numbering: none)[```go
amqp "github.com/rabbitmq/amqp091-go"```],
caption: "amqp091-go alias",
)

==== API usage

Similar to the other clients, first a connection to the RabbitMQ server is established.

#figure(
sourcecode()[```go 
connectionString := "amqp://guest:guest@localhost:5672/"
connection, _ := amqp.Dial(connectionString)
```],
caption: "amqp091-go connection",
)

After the connection is established, a channel is created and used to declare an exchange as well as a queue.

#figure(
sourcecode()[```go 
channel, _ := connection.Channel()
channel.ExchangeDeclare("golang-exchange", "direct", true, false, false, false, nil)

Queueargs := make(amqp.Table)
Queueargs["x-queue-type"] = "stream"
channel.QueueDeclare("golang-queue", true, false, false, false, Queueargs)
channel.QueueBind("golang-queue", "golang-exchange", "golang-exchange", false, nil)
```],
caption: "amqp091-go exchange and queue declaration",
)

After the queue is declared, a new thread is spawned, which is used to consume messages from the queue.

#figure(
sourcecode()[```go 
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
```],
caption: "amqp091-go consume messages",
)

On the main thread, a new channel is created, which is used to publish messages to the queue.

#figure(
sourcecode()[```go 
channel_b, _ := connection.Channel()

for {
        channel_b.Publish("golang-exchange", "golang-exchange", false, false, amqp.Publishing{
                Body: []byte("Hello World"),
        })
        time.Sleep(100 * time.Millisecond)
        println("Message sent")
}
```],
caption: "amqp091-go publish messages",
)

Overall, the experience with amqp091-go was very similar to the other libraries.

#pagebreak()

=== Evaluation matrix

#figure(
tablex(
columns: (auto, auto, auto, auto,auto,auto),
rows: (auto),
align: (left, center + horizon, left, center + horizon, center + horizon, center + horizon),
[*Criteria*],
[*Weight(1-5)*],
[*Description*],
[*lapin*],
[*rabbitmq-java-client*],
[*amqp091-go*],
[Installation],
[2],
[Easy and well-documented installation process],
[2],
[0],
[1],
[API Clarity and Consistency],
[5],
[Clear, consistent, and intuitive API design],
[4],
[5],
[4],
[Documentation],
[5],
[Clear, complete, and well-maintained documentation],
[3],
[4],
[3],
[Community],
[4],
[Active and helpful community],
[4],
[4],
[4],
[language familiarity],
[5],
[How familiar I am with the language],
[5],
[2],
[2],
[Platform Compatibility],
[4],
[Support for Unix based systems],
[4],
[4],
[4],
[Performance],
[3],
[Message Throughput],
[3],
[3],
[3],
[Error Handling],
[3],
[Clear and consistent error handling],
[3],
[3],
[3],
[Licensing Terms],
[5],
[Open-source license],
[5],
[5],
[5],
[Total],
[36],
[],
[33],
[30],
[29],
)
)

The installation process for all three libraries was well documented. With Java,
the initial setup was not as easy as with the other two. The only annoyance with
Go was, that the maintainer changed resulting in a new repository. This resulted
in extra steps. All APIs were clear and consistent. The documentation for all
three libraries was clear and complete. The community for all three libraries
was active and helpful. The APIs all implement the same standard and therefore
are very similar in use and functionality. Furthermore, all three libraries were
open-source and featured permissive licenses, none of which were copyleft
licenses. As demonstrated in the examples, their usage and functionality were
remarkably alike. In the end, it boils down to personal preference and
familiarity with the language. Since I am most familiar with Rust, I decided to
use lapin for the microservice.

#pagebreak()

== Architecture<architecture>

The microservice is implemented in Rust. Two off-the-shelf libraries are used to 
implement the microservice. The first library is lapin, which is used to interact
with RabbitMQ. The second library is axum, which is used to implement the webserver.

#figure(
image("../assets/microservice_components.svg"),
caption: "Microservice Architecture",
kind: image,
)

The central component of the microservice is the replay component. The replay logic
implements the use cases described in @Use_cases.

#pagebreak()

The replay component is split into three use cases.
#figure(
image("../assets/replay_components.svg"),
caption: "Replay Architecture",
kind: image,
)

For each use case, a separate sequence diagram is provided.

#pagebreak()

*Get*<replay-get>

A get request with a queue and a timeframe (from, to) is sent to the
microservice. The replay component creates a new consumer and starts consuming
messages from the queue. The consumer is stopped after the timeframe is reached.

#figure(
image("../assets/sequence_diagram_get.svg"),
caption: "Replay Sequence Diagram Get",
kind: image,
)

The consumed messages get aggregated and returned to the client.

#pagebreak()

*Post (timeframe)*<replay-post-timeframe>

A post request with a queue and a timeframe (from, to) is sent to the microservice.
The replay component creates a new consumer and starts consuming messages from the queue.
The consumer is stopped after the timeframe is reached. Each consumed message gets 
published to the same queue.

#figure(
image("../assets/sequence_diagram_post_timeframe.svg"),
caption: "Replay Sequence Diagram Post Timeframe",
kind: image,
)

The messages that get published to the queue acquire a new transaction ID on publish.
After all messages are published, a list of transaction IDs is returned to the client.

#pagebreak()

*Post (transaction)*<replay-post-transaction>

A post request with a queue and a single transaction ID is sent to the microservice.
The replay component creates a new consumer and consumes the message with the given
transaction ID from the queue.

#figure(
image("../assets/sequence_diagram_post_transaction.svg"),
caption: "Replay Sequence Diagram Post Transaction",
kind: image,
)

The consumed message gets published again to the same queue but with a new transaction ID.
The newly created transaction ID is returned to the client.

#pagebreak()
