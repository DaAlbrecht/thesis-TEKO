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

= Glossary

#figure(tablex(
  columns: (auto, 1fr),
  rows: (auto),
  alignment: (left, left),
  [*terminology*],
  [*description*],
), kind: table, caption: "Glossary")<glossary>


= Curriculum vitae

#include "personal/cv.typ"

= Introduction

In the present thesis, a solution is developed to facilitate the retransmission
of messages within a RabbitMQ infrastructure, specifically within an append-only
queue. Numerous clients of Integon rely upon RabbitMQ as their designated
message broker, necessitating the capability to replay messages in the event of
an error or system anomaly. The visual representation provided below in
@append_only_queue elaborates on the fundamental concept of an append-only queue.

#figure(
  image("assets/append_only_queue.png", width: 80%),
  caption: "Append only queue",
)<append_only_queue>


The subsequent @append_only_queue_replay, presented below, visually shows
desired state, illustrating the incorporation of a mechanism for the message
replaying.

#figure(
  image("assets/replay_message.png", width: 80%),
  caption: "Append only queue with replay",
)<append_only_queue_replay>

= Task analysis

Here, we'll cover the initial context resulting from the #appendix[Assignment]<Assignment> and
outline the requirements and objectives.

#include "content/task_analysis.typ"

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

