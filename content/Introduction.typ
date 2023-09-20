In the present thesis, a solution is developed to facilitate the retransmission
of messages within a RabbitMQ infrastructure, specifically within an append-only
queue. Numerous clients of Integon rely upon RabbitMQ as their designated
message broker, necessitating the capability to replay messages in the event of
an error or system anomaly. The visual representation provided below in
@append_only_queue elaborates on the fundamental concept of an append-only queue.

#figure(
  image("../assets/append_only_queue.png", width: 80%),
  caption: "Append only queue",
)<append_only_queue>


The subsequent @append_only_queue_replay, presented below, visually shows
desired state, illustrating the incorporation of a mechanism for the message
replaying.

#figure(
  image("../assets/replay_message.png", width: 80%),
  caption: "Append only queue with replay",
)<append_only_queue_replay>
#pagebreak()
