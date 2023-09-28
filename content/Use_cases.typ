Three  main use cases exist. 
- Replay a message based on a header value (Transaction ID) and  a queue
- Replay a message based on a given time interval and  a queue 
- Get messages based on a given time interval and  a queue

#figure(
image("../assets/use_case_diagram.svg", width: 70%),
kind: image,
caption: "Use case diagram",
)<use_case_diagram>

As mentioned in @Out_of_scope the microservice will be integrated into a
customers observability System. The observability system will have a custom
button, that allows to replay a message on button press. For this to work the
first use case is needed. The second use case is not directly related to a customer's need but a nice-to-have feature.
It's especially useful for testing purposes.
