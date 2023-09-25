#import "@preview/tablex:0.0.5": tablex, cellx
#import "@preview/codelst:1.0.0": sourcecode

To interact with RabbitMQ streams, a client library is needed.
There are two different types of client libraries

- An AMQP 0.9.1 client library that can specify optional queue and consumer arguments#footnote([https://www.rabbitmq.com/streams.html#usage])
- RabbitMQ streams client libraries that support the new protocol#footnote([https://www.rabbitmq.com/devtools.html])

Since the streaming protocol is still subject to change, and the microservice is
not acting as a high throughput consumer or publisher the extra speed, gained
with the streaming protocol is not needed. Additionally, after a brief
exploration the documentation and examples for the streaming protocol appeared
to be less well-maintained compared to the AMQP 0.9.1 client libraries, leading
to encounters with broken code snippets and API changes.

As a result, I decided to exclude the RabbitMQ streams client libraries from
consideration and instead concentrate on evaluating the AMQP 0.9.1 client
libraries, which offer support for optional queue and consumer arguments.

To evaluate the AMQP 0.9.1 client libraries, I created a simple publisher and
consumer application, which publishes a message to a queue and then consumes it.
This simple demo application was then used to evaluate the client libraries.

*Setup*<setup>

For this application i used RabbitMQ deployed as a docker container. RabbitMQ 
can be deployed with the following command:
#figure(
sourcecode(numbering: none)[```bash 
docker run -it --rm --name rabbitmq -p 5552:5552 -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management
```],
caption: "RabbitMQ as docker container",
)

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

First the clients needs to establish a connection to the RabbitMQ server.
The server is running on localhost and the default port 5672. The credentials
are the default credentials for RabbitMQ.

With the following code snippets a connection to the RabbitMQ server is established.

*Main function*

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

*Function to create a connection*

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

*Breakdown*

Rust does not have a built in asynchronous runtime. Instead, it relies on
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

The `queue_declare` functions takes additional arguments with the type
`FieldTable`#footnote(
  [https://docs.rs/amq-protocol-types/7.1.2/amq_protocol_types/struct.FieldTable.html],
).
These additional arguments are used to specify the optional queue and consumer
arguments needed for RabbitMQ streams.

After the queue is created, a new thread is spawned, which is used to  consuming messages from the queue.

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
These arguemnts get created with the `stream_consume_args` function.

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

=== Go - amqp091-go

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
[x],
[x],
[x],
[API Clarity and Consistency],
[5],
[Clear, consistent, and intuitive API design],
[x],
[x],
[x],
[Documentation],
[5],
[Clear, complete, and well-maintained documentation],
[x],
[x],
[x],
[Community],
[4],
[Active and helpful community],
[x],
[x],
[x],
[language familiarity],
[5],
[How familiar I am with the language],
[x],
[x],
[x],
[Platform Compatibility],
[4],
[Support for Unix based systems],
[x],
[x],
[x],
[Performance],
[3],
[Message Throughput],
[x],
[x],
[x],
[Error Handling],
[3],
[Clear and consistent error handling],
[x],
[x],
[x],
[Licensing Terms],
[5],
[Open-source license],
[x],
[x],
[x],
[Total],
[36],
[],
[],
[],
)
)
