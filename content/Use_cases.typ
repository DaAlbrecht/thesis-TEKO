Two main use cases exist. 
- Replay a message based on a header value (Transaction ID)
- Replay a message based on a given time interval

#figure(
image("../assets/use_case_diagram.svg", width: 70%),
kind: image,
caption: "Use case diagram",
)<use_case_diagram>

As mentioned in @Out_of_scope the microservice is will be integrated in a
customers observability System. The observability system will have a custom
button, that allows to replay a message on button press. For this to work the
first use case is needed. The second use case is not directly related to a customers need but a nice to have feature.
Its especially useful for testing purposes.
