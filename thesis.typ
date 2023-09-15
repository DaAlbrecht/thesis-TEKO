#import "template.typ": *
#import "metadata.typ": *
#import "@preview/tablex:0.0.5": tablex, cellx

#show figure.where(kind: "appendix"): it => it.body
#let appendix = figure.with(kind: "appendix", numbering: "A", supplement: [Appendix])


#show: project.with(
  title: "Microservice for messaging-based replay function",
  authors: ("David",),
  abstract: lorem(59),
  date: "September 15, 2023",
)

= Executive summary

#pagebreak()

= Curriculum vitae

#include "personal/cv.typ"

= Introduction

In the present thesis, a solution is developed to facilitate the retransmission
of messages within a RabbitMQ infrastructure, specifically within an append-only
queue. Numerous clients of Integon rely upon RabbitMQ as their designated
message broker, necessitating the capability to replay messages in the event of
an error or system anomaly. The visual representation provided below in
@append_only_queue elaborates the fundamental concept of an append-only queue.

#figure(
  image("assets/append_only_queue.png", width: 80%),
  caption: "Append only queue",
)<append_only_queue>


The subsequent @append_only_queue_replay, presented below, visually shows
desired state, illustrating the incorporation of a mechanism for message
replaying.

#figure(
  image("assets/replay_message.png", width: 80%),
  caption: "Append only queue with replay",
)<append_only_queue_replay>

= Task analysis

Here, we'll cover the initial context resulting from the #appendix[Assignment]<Assignment> and
outline the requirements and objectives.

== Task description

Multiple customers of Integon rely upon RabbitMQ as their designated messaging
broker. Different Systems write messages into a queue, that needs to be
processed by other systems. If for some reason a specific message should be
processed again, the owner of the processing system has no possibility to retry
processing the message. Said owner has to contact the owner of the sending
system and ask for a retransmission of the message. This is a time-consuming and
costly process. The goal of this thesis is to develop a microservice that allows
requeuing messages without needing to contact the owner of the sending system.
The requeuing should be possible via API call.

=== Out of scope

The goal is to also embed the microservice into already existing observability systems to enable
requeing of messages via UI. This is out of scope for this thesis and will be
implemented in a follow-up project.


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
    [ID],
    [Stakeholder],
    [Description],
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
    [ID],
    [Trace from],
    [Description],
    [REQ-1],
    [DEV],
    [The communication with RabbitMQ should be done with an existing library],
    [REQ-2],
    [DEV],
    [The microservice should be written in a programming language that is supported by Integon],
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
    [The microservice should fit into existing architecture of different customers],
    [REQ-16],
    [INT,OPS],
    [The microservice should be easy to integrate into existing CI/CD pipelines],
    [REQ-17],
    [OSS],
    [The microservice should be easy to contribute to],
    [REQ-18],
    [OSS],
    [The microservice should be easy to understand],
  ),
  kind: table,
  caption: [Stakeholder Requirements],
)

=== System architecture and design

In this section, a high level overview of the system architecture and design is
given. This is not the implementation architecture of the microservice itself,
but the architecture of the microservice and its points of contact with other
potential systems according to the stakeholder requirements.

This high level overview of the architecture is used to derive the concrete
system requirements.

=== System Requirements 

= Use cases

= Projectplan

= Research

= Evaluation

== Architecture 

== API Library

= Alignment with the requirements TODO: better title

= Conclusion

= Closing remarks

= Acknowledgement

= Declaration of independence

Work that is demonstrably taken over in full or in the essential parts unchanged
or without correct reference to the source is considered prefabricated and will
not be evaluated.

#text(weight: "bold")[I confirm that I have written this thesis independently and have marked all sources used. This thesis has not already been submitted to an examination committee in the same or a similar form.]

#linebreak()

Name / First name: 

#for i in range(5) {
linebreak()
}

Place / Date / Signature:

