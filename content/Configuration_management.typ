#import "@preview/tablex:0.0.5": tablex, cellx

The microservice uses environment variables to configure the behavior. The following variables are supported:


  #figure(
      table(
    columns: (1fr, 1fr,auto),
    rows: (auto),
    align: (left,left, center + horizon),
    [*Variable*],
    [*Description*],
    [*Default*],
    [AMQP_CONNECTION_POOL_SIZE],
    [The number of connections to the AMQP server.],
    [5],
    [AMQP_USERNAME],
    [The username to use when connecting to the AMQP server.],
    [guest],
    [AMQP_PASSWORD],
    [The password to use when connecting to the AMQP server.],
    [guest],
    [AMQP_HOST],
    [The hostname of the AMQP server.],
    [localhost],
    [AMQP_PORT],
    [The port of the AMQP server.],
    [5672],
    [AMQP_MANAGEMENT_PORT],
    [The port of the AMQP management server.],
    [15672],
    [AMQP_TRANSACTION_HEADER],
    [The name of the header that contains the transaction ID.],
    [None],
    [AMQP_ENABLE_TIMESTAMP],
    [Whether the amqp messages have timestamps or not.],
    [true],
    [ENABLE_METRICS],
    [Whether to enable metrics or not.],
    [false],
    ),
    kind: table,
    caption: "Environment variables"
    )

#pagebreak()
