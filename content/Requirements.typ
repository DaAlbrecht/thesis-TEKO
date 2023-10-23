#import "@preview/tablex:0.0.5": tablex, cellx
#import "@preview/codelst:1.0.0": sourcecode
#show figure.where(kind: raw): set block(breakable: true)

The following Stakeholders are identified:

#figure(
  tablex(
    columns: (auto, 1fr, 2fr),
    rows: (auto),
    align: (center + horizon, center + horizon, left),
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
    [Open source software Community],
    [The microservice could be published as open-source software],
  ),
  kind: table,
  caption: [Stakeholders and their abbreviation],
)

#pagebreak()

== Stakeholder Requirements<stakeholder_requirements>

#figure(
  tablex(
    columns: (auto, auto, 1fr),
    rows: (auto),
    align: (center + horizon, center + horizon, left),
    [*ID*],
    [*Trace from*],
    [*Description*],
    [STR-1],
    [DEV],
    [The communication with RabbitMQ should be done with an existing library],
    [STR-2],
    [DEV],
    [The microservice should be written in a programming language that is supported
      by Integon],
    [STR-3],
    [OPS],
    [The microservice should be deployable in a containerized environment],
    [STR-4],
    [OPS],
    [The microservice should be resource-efficient],
    [STR-5],
    [OPS],
    [The microservice should be easy to operate],
    [STR-6],
    [OPS],
    [The microservice should be easy to monitor],
    [STR-7],
    [OPS,INT],
    [The microservice should be easy to integrate into existing monitoring systems],
    [STR-8],
    [OPS,INT],
    [The microservice should be easy to integrate into existing logging systems],
    [STR-9],
    [OPS,INT],
    [The microservice should be easy to integrate into existing alerting systems],
    [STR-10],
    [OPS,CUS,INT],
    [The microservice should be easy to integrate into existing deployment systems],
    [STR-11],
    [CUS],
    [The microservice can replay messages from a specific queue and time range],
    [STR-12],
    [INT],
    [The microservice should be easy to maintain],
    [STR-13],
    [INT],
    [The microservice should be easy to extend],
    [STR-14],
    [INT],
    [The microservice should be easy to test],
    [STR-15],
    [INT],
    [The microservice should fit into the existing architecture of different customers],
    [STR-16],
    [INT,OPS],
    [The microservice should be easy to integrate into existing CI/CD pipelines],
    [STR-17],
    [OSS],
    [The microservice should be easy to contribute to],
    [STR-18],
    [OSS],
    [The microservice should be easy to understand],
    [STR-19],
    [OPS],
    [The microservice should be traceable],
    [STR-20],
    [CUS],
    [The microservice can replay messages from a specific transaction ID and queue],
    [STR-21],
    [CUS, OSS],
    [The microservice can list all messages in a given time range and queue],
  ),
  kind: table,
  caption: [Stakeholder Requirements],
)

== System architecture and design

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

=== External interfaces

The microservice needs to interact with different systems to be compliant with
the stakeholder requirements @stakeholder_requirements.
#linebreak()
The following table identifies the external interfaces of the microservice.

#figure(
  tablex(
    columns: (auto, auto, 1fr, 2fr),
    rows: (auto),
    align: (center + horizon, center + horizon, center + horizon, left),
    [*ID*],
    [*Trace from*],
    [*Name*],
    [*Description*],
    [EXT-1],
    [STR-1],
    [RabbitMQ],
    [RabbitMQ is used as the messaging broker],
    [EXT-2],
    [STR-2],
    [RabbitMQ client],
    [The microservice uses a RabbitMQ client library to communicate with RabbitMQ],
    [EXT-3],
    [STR-3],
    [OCI],
    [The microservice is deployed in a containerized environment, and therefore
      should be compliant with the OCI specification],
    [EXT-4],
    [STR-7],
    [Prometheus],
    [Prometheus needs to be supported as a metrics backend],
    [EXT-5],
    [STR-8],
    [Stdout],
    [Stdout needs to be supported as a logging target],
    [EXT-6],
    [STR-19],
    [Tracing],
    [Tracing needs to be supported],
  ),
  kind: table,
  caption: [External interfaces],
)

=== Data follow 

The API expects to receive a request with a message ID. The message ID is used to
identify the message in the RabbitMQ queue. The microservice then sends a request to
RabbitMQ to requeue the message. The following figure shows the request flow.

#figure(
image("../assets/request_flow.svg"),
kind: image,
caption: [Request flow],
)

In both the in- and outflow, the microservice needs to aggregate observability data according to
the following table.

#figure(
  tablex(
    columns: (auto,auto,auto, 1fr),
    rows: (auto),
    align: (center + horizon,center + horizon,center + horizon,left),
    [*ID*],
    [*Trace from*],
    [*Category*],
    [*Description*],
    [OBS-1],
    [EXT-4],
    [Metrics],
    [CPU usage],
    [OBS-2],
    [EXT-4],
    [Metrics],
    [Memory usage],
    [OBS-3],
    [EXT-4],
    [Metrics],
    [Network usage],
    [OBS-4],
    [EXT-4],
    [Metrics],
    [Request duration],
    [OBS-5],
    [EXT-4],
    [Metrics],
    [Request size],
    [OBS-6],
    [EXT-4],
    [Metrics],
    [Response size],
    [OBS-7],
    [EXT-4],
    [Metrics],
    [Response duration],
    [OBS-8],
    [EXT-4],
    [Metrics],
    [Response code],
    [OBS-9],
    [EXT-4],
    [Metrics],
    [Response error],
    [OBS-10],
    [EXT-5],
    [Logs],
    [Request body],
    [OBS-11],
    [EXT-5],
    [Logs],
    [Response body],
    [OBS-12],
    [EXT-5],
    [Logs],
    [Request headers],
    [OBS-13],
    [EXT-5],
    [Logs],
    [Response headers],
    [OBS-14],
    [EXT-5],
    [Logs],
    [Request message ID],
    [OBS-15],
    [EXT-5],
    [Logs],
    [Response message ID],
    [OBS-16],
    [EXT-6],
    [Tracing],
    [Request trace],
    [OBS-17],
    [EXT-6],
    [Tracing],
    [Response trace],
  ),
  kind: table,
  caption: [Observability data],
)<observability_data>

#pagebreak()

=== OpenAPI specification<openapi_specification>

The microservice needs to have the following API specification:

#figure(
sourcecode()[
```yaml 
openapi: 3.0.1
info:
  version: 1.0.0
  title: RabbitMQ Replay API
paths:
  /replay:
    get:
      summary: Retrieve data from a specified time range and queue.
      parameters:
        - name: from
          in: query
          description: Start timestamp (inclusive).
          required: false
          schema:
            type: string
            format: date-time
        - name: to
          in: query
          description: End timestamp (exclusive).
          required: false
          schema:
            type: string
            format: date-time
        - name: queueName
          in: query
          description: Name of the queue.
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Successful retrieval of data.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Message'
        '500':
          description: Internal server error.
          content:
            application/json:
              schema:
                type: object
                properties:
                  error:
                    type: string
    post:
      summary: Submit timestamps, a transaction ID, and a queue for replay.
      requestBody:
        description: Data to submit for replay.
        required: true
        content:
          application/json:
            schema:
              oneOf:
                - type: object
                  properties:
                    from:
                      type: string
                      format: date-time
                    to:
                      type: string
                      format: date-time
                    queueName:
                      type: string
                - type: object
                  properties:
                    transactionId:
                      type: string
                    queueName:
                      type: string
      responses:
        '201':
          description: Successful replay.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Message'
        '400':
          description: Bad request. Neither timestamps nor transactionId submitted.
        '404':
          description: Transaction ID not found.
        '500':
          description: Internal server error.
          content:
            application/json:
              schema:
                type: object
                properties:
                  error:
                    type: string

components:
  schemas:
    TransactionHeader:
      type: object
      properties:
        name:
          type: string
        value:
          type: string

    Message:
      type: object
      properties:
        offset:
          type: integer
          format: int64
        transaction:
          $ref: '#/components/schemas/TransactionHeader' 
        timestamp:
          type: string
          format: date-time
        data:
          type: string
    ```],
    caption: [OpenAPI specification],
    )
#pagebreak()

== System Requirements

#figure(
tablex(
  columns: (auto, auto, 1fr),
  rows: (auto),
  align: (center + horizon, center + horizon, left),
  [*ID*],
  [*Trace from*],
  [*Description*],
  [REQ-1],
  [STR-1],
  [The RabbitMQ client library needs to be actively maintained and supported],
  [REQ-2],
  [STR-2, STR-12, STR-13, STR-16],
  [The microservice needs to be written in Rust, go or Java],
  [REQ-3],
  [STR-3, STR-10, STR-15, STR-16],
  [The microservice needs to be compliant with the OCI specification],
  [REQ-4],
  [STR-4],
  [The microservice should not use more than 500MB of memory and 0.5 CPU cores when idle],
  [REQ-5],
  [STR-5, STR-11],
  [The microservice provides an openapi specification for its API],
  [REQ-6],
  [STR-6, STR-7, STR-15],
  [The microservice provides Prometheus metrics according to @observability_data],
  [REQ-7],
  [STR-8, STR-15],
  [The microservice logs to stdout according to @observability_data],
  [REQ-8],
  [STR-9, STR-15],
  [The microservice provides a health endpoint],
  [REQ-9],
  [STR-14],
  [The microservice provides unit tests],
  [REQ-10],
  [STR-16],
  [The microservice has no dependencies on other systems],
  [REQ-11],
  [STR-17],
  [The microservice is published as open-source software, and a contribution guide is provided],
  [REQ-12],
  [STR-18],
  [The microservice provides a README.md file with a description of the microservice and its API],
  [REQ-13],
  [STR-19],
  [The microservice provides a trace header for tracing according to @observability_data],
  [REQ-14],
  [STR-20],
  [A transaction ID can be submitted to the microservice to replay messages from a specific transaction ID and queue],
  [REQ-15],
  [STR-11],
  [A time range can be submitted to the microservice to replay messages from a specific time frame  and queue],
  [REQ-16],
  [STR-21],
  [A time range and queue can be submitted to the microservice to list all messages in a given time range and queue],
),
kind: table,
caption: [System Requirements],
)
#pagebreak()
