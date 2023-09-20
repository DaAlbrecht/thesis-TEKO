#import "@preview/tablex:0.0.5": tablex, cellx
#let appendix = figure.with(kind: "appendix", numbering: "A", supplement: [Appendix])

Here, we'll cover the initial context resulting from the #appendix[Assignment]<Assignment>.

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

=== Out of scope<Out_of_scope>

The goal is to also embed the microservice into already existing observability
systems to enable requeing of messages via UI. This is out of the scope of this
thesis and will be implemented in a follow-up project.

== Initial situation

The microservice needs to be developed from scratch. There is no existing
architecture or codebase to build upon.

