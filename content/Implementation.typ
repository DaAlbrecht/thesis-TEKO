#import "@preview/tablex:0.0.5": tablex, cellx

== Prequesites

For the development of the replay microservice, the following tools are required:

#figure(
  tablex(
    columns: (auto,1fr,auto),
    rows:(auto),
    align: (center + horizon, left, left),
    [*Name*],
    [*Description*],
    [*Install*],
    [Rust],
    [The microservice is written in Rust. The rust toolchain is required to build the microservice.],
    [#link("https://www.rust-lang.org/tools/install")],
    [Docker],
    [The microservice aswell as RabbitMQ are run in docker containers.],
    [#link("https://docs.docker.com/get-docker/")],
    [RabbitMQ],
    [The microservice uses RabbitMQ as a message broker.],
    [The container can be started as shown in @api-lib-setup],
    [curl],
    [The microservice can be tested using curl.],
    [#link("https://curl.se/download.html")],
    ),
    kind: table,
    caption: [development prerequisites]
  )

  == Webservice

  == Replay component

  == Container

  == CI/CD 

