== Verification plan
  #[
  #show regex("\w"): it => [#sym.zws;#it]
#figure(
  table(
    columns: (auto, auto, auto, auto,auto),
    rows: auto,
    align: (center+horizon, center+horizon, left, left ,center + horizon),
    [*ID*],
    [*From*],
    [*Test case*],
    [*Should be*],
    [*Is*],
    [VER-1],
    [REQ-1],
    [Check the time of the last commit of the amqp library],
    [Last commit is newer than 01.01.2022],
    text(fill: rgb(34,139,34))[OK],
    [VER-2],
    [REQ-2],
    [Check the source code of the microservice],
    [The microservice is written in rust, go or java],
    text(fill: rgb(34,139,34))[OK],
    [VER-3],
    [REQ-3],
    [The container is a docker image],
    [The container is a docker image],
    text(fill: rgb(34,139,34))[OK],
    [VER-4],
    [REQ-4],
    [Start the container and use the command `top` to see the resources used by the container],
    [The container uses less than 500MB of RAM and less than 0.5 cpu cores],
    text(fill: rgb(34,139,34))[OK],
    [VER-5],
    [REQ-5],
    [Check the source code of the microservice for an openapi specification],
    [The microservice has an openapi specification],
    text(fill: rgb(34,139,34))[OK],
    [VER-6],
    [REQ-6],
    [Enable metrics and start the microservice. Use the endpoint `/metrics` to get the metrics.],
    [The metrics are in the prometheus format],
    text(fill: rgb(34,139,34))[OK],
    [VER-7],
    [REQ-7],
    [Start the microservice and check for stdout logs],
    [The microservice logs to stdout],
    text(fill: rgb(34,139,34))[OK],
    [VER-8],
    [REQ-8],
    [Start the microservice and visit the endpoint `/health`],
    [The endpoint `/health` returns a 200 status code],
    text(fill: rgb(34,139,34))[OK],
    [VER-9],
    [REQ-9, REQ-10, REQ-14, REQ-15, REQ-16],
    [Run `cargo test` in the microservice directory],
    [All tests pass],
    text(fill: rgb(34,139,34))[OK],
    [VER-9],
    [REQ-11],
    [Visit the repository at #link("https://github.com/DaAlbrecht/rabbit-revival")],
    [The repository is public and provides a contribution guide],
    text(fill: rgb(34,139,34))[OK],
    [VER-10],
    [REQ-12],
    [Visit the repository at #link("https://github.com/DaAlbrecht/rabbit-revival"), a readme is present],
    [A readme is present],
    text(fill: rgb(34,139,34))[OK],
    )
  )
]

#pagebreak()
== Stakeholder feedback