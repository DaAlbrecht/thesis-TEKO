This thesis presents the development of a practical microservice designed to
replay messages from a RabbitMQ stream. The main goal was to create an
open-source Docker container that seamlessly integrates into existing
infrastructures, enabling the efficient replay of messages from RabbitMQ
streams.
#linebreak()
A comprehensive research phase was undertaken to evaluate various AMQP clients
available. Through an evaluation matrix, the most efficient and
reliable AMQP client was identified. 
#linebreak()
The microservice was implemented using Rust, a programming language known for
its speed and safety. This choice allowed the creation of a robust architecture
that supports message replay based on specific time ranges or message headers.
#linebreak()

Key Features:

1. Time-based Replay: Messages can be replayed within specified time frames, making it easy to bulk replay messages from a specific time period.
2. Header-based Replay: Selective message replay based on specific headers allows users to precisely target messages.

#linebreak()
The requirements and stakeholder needs were successfully met, and the 
microservice is successfully implemented and tested, marking this 
project as a success.
#linebreak()
Looking ahead, the next step is to deploy the microservice in an existing
infrastructure and create integration templates to embed the microservice in
different observability tools.
#linebreak()
In summary, this thesis provides a practical solution to the problem of
replaying messages from RabbitMQ streams. The microservice is open-source and
can be used according to the terms of the MIT license. 
#pagebreak()
