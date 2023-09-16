#import "@preview/tablex:0.0.5": tablex, cellx

== Task description

Multiple customers of Integon rely upon RabbitMQ as their designated messaging
broker. Different Systems write messages into a queue, that needs to be
processed by other systems. If for some reason a specific message should be
processed again, the owner of the processing system cannot retry
processing the message. Said owner has to contact the owner of the sending
system and ask for a retransmission of the message. This is a time-consuming and
costly process. The goal of this thesis is to develop a microservice that allows
queueing messages again, without needing to contact the owner of the sending system.
The queuing should be possible via API call.

=== Out of scope

The goal is to also embed the microservice into already existing observability
systems to enable requeing of messages via UI. This is out of the scope of this
thesis and will be implemented in a follow-up project.

== Initial situation

The microservice needs to be developed from scratch. There is no existing
architecture or codebase to build upon.

== Requirements

The following Stakeholders are identified:

#figure(
  tablex(
    columns: (auto, 1fr, 2fr),
    rows: (auto),
    align: (center, center, left),
    [*ID*],
    [*Stakeholder*],
    [*Description*],
    [DEV],
    [Developer],
    [The microservice developer],
    [CUS],
    [Customer],
    [The customer of Integon, who wants to use the microservice],
    [OPS],
    [Operations],
    [The team who is responsible for deploying and operating the microservice],
    [INT],
    [Integon],
    [The company Integon],
    [OSS],
    [Open-Source-software Community],
    [The microservice could be published as open-source software],
  ),
  kind: table,
  caption: [Stakeholders and their abbreviation],
)

=== Stakeholder Requirements

#figure(
  tablex(
    columns: (auto, auto, 1fr),
    rows: (auto),
    align: (center, center, left),
    [*ID*],
    [*Trace from*],
    [*Description*],
    [REQ-1],
    [DEV],
    [The communication with RabbitMQ should be done with an existing library],
    [REQ-2],
    [DEV],
    [The microservice should be written in a programming language that is supported
      by Integon],
    [REQ-3],
    [OPS],
    [The microservice should be deployable in a containerized environment],
    [REQ-4],
    [OPS],
    [The microservice should be resource efficient],
    [REQ-5],
    [OPS],
    [The microservice should be easy to operate],
    [REQ-6],
    [OPS],
    [The microservice should be easy to monitor],
    [REQ-7],
    [OPS,INT],
    [The microservice should be easy to integrate into existing monitoring systems],
    [REQ-8],
    [OPS,INT],
    [The microservice should be easy to integrate into existing logging systems],
    [REQ-9],
    [OPS,INT],
    [The microservice should be easy to integrate into existing alerting systems],
    [REQ-10],
    [OPS,CUS,INT],
    [The microservice should be easy to integrate into existing deployment systems],
    [REQ-11],
    [CUS],
    [The microservice should be easy to use],
    [REQ-12],
    [INT],
    [The microservice should be easy to maintain],
    [REQ-13],
    [INT],
    [The microservice should be easy to extend],
    [REQ-14],
    [INT],
    [The microservice should be easy to test],
    [REQ-15],
    [INT],
    [The microservice should fit into the existing architecture of different customers],
    [REQ-16],
    [INT,OPS],
    [The microservice should be easy to integrate into existing CI/CD pipelines],
    [REQ-17],
    [OSS],
    [The microservice should be easy to contribute to],
    [REQ-18],
    [OSS],
    [The microservice should be easy to understand],
    [REQ-19],
    [OPS],
    [The microservice should be traceable],
  ),
  kind: table,
  caption: [Stakeholder Requirements],
)

=== System architecture and design

In this section, a high-level overview of the system architecture and design is
given. This is not the implementation architecture of the microservice itself,
but the architecture of the microservice and its points of contact with other
potential systems according to the stakeholder requirements.

This high-level overview of the architecture is used to derive the concrete
system requirements.

#figure(
  image("../assets/high_level_design.svg"),
  kind: image,
  caption: [System architecture],
)

==== External interfaces

According to the high-level design, the following external interfaces can be
extracted:

#figure(
  tablex(
    columns: (auto, auto, 1fr, 2fr),
    rows: (auto),
    align: (center,center,center,left),
    [*ID*],
    [*Trace from*],
    [*Name*],
    [*Description*],
    [EXT-1],
    [REQ-1],
    [RabbitMQ],
    [RabbitMQ is used as the messaging broker],
    [EXT-2],
    [REQ-2],
    [RabbitMQ client],
    [The microservice uses a RabbitMQ client library to communicate with RabbitMQ],
    [EXT-3],
    [REQ-3],
    [OCI],
    [The microservice is deployed in a containerized environment],
    [EXT-4],
    [REQ-7],
    [Prometheus],
    [Prometheus needs to be supported as a metrics backend],
    [EXT-5],
    [REQ-8],
    [Stdout],
    [Stdout needs to be supported as a logging target],
    [EXT-6],
    [REQ-19],
    [Tracing],
    [Tracing needs to be supported],
  ),
  kind: table,
  caption: [External interfaces],
)

=== System Requirements
