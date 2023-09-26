use anyhow::{Context, Result};
use futures_lite::StreamExt;
use lapin::{
    options::{
        BasicAckOptions, BasicConsumeOptions, BasicPublishOptions, BasicQosOptions,
        ExchangeDeclareOptions, QueueDeclareOptions,
    },
    protocol::basic::AMQPProperties,
    types::{AMQPValue, FieldTable, ShortString},
    Channel, Connection, ConnectionProperties, ExchangeKind,
};
use tokio::time::Instant;

#[tokio::main]
async fn main() -> Result<()> {
    let channel = create_rmq_connection(
        "amqp://guest:guest@localhost:5672".to_string(),
        "connection_name".to_string(),
    )
    .await;

    let declare_options = ExchangeDeclareOptions {
        durable: true,
        auto_delete: false,
        ..Default::default()
    };
    channel
        .exchange_declare(
            "baz_exchange",
            ExchangeKind::Direct,
            declare_options,
            FieldTable::default(),
        )
        .await?;

    channel
        .basic_qos(1000u16, BasicQosOptions { global: false })
        .await?;

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

    channel
        .queue_bind(
            "foo_queue",
            "baz_exchange",
            "baz_exchange",
            Default::default(),
            FieldTable::default(),
        )
        .await
        .context("Failed to bind queue to exchange")?;

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
}

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

pub fn stream_consume_args() -> FieldTable {
    let mut queue_args = FieldTable::default();
    queue_args.insert(
        ShortString::from("x-stream-offset"),
        AMQPValue::LongString("first".into()),
    );
    queue_args
}

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
