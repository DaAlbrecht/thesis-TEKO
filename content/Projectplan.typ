#import "@preview/tablex:0.0.5": tablex, cellx

In this thesis, the use cases outlined in  @Use_cases  have been
implemented. To ensure timely completion within the established timeframe, a
project schedule has been developed. The choice of utilizing the Waterfall
project management methodology is based on the specific characteristics of this
thesis project.

The Waterfall methodology has been selected as a suitable approach due to
several key factors:
- the project is being conducted independently, without the involvement of a team, making the linear and sequential nature of
  Waterfall a practical fit.
- the project operates within strict time constraints
- the thesis description has already been submitted in advance, precluding any
  changes to the requirements.

Therefore, the Waterfall methodology aligns well with the project's unique circumstances.

As seen in @a_plan the project schedule is divided into seven different phases and has the following milestones:

== Milestones

The following milestones have been defined for the project schedule:

#figure(
  table(
    columns: (auto,auto),
    rows: auto,
    align: (left,left),
    [*Milestone*],
    [*Date*],
    [Start thesis],
    [15.09.2023],
    [Email the state of the thesis to the supervisor],
    [22.09.2023],
    [1. meeting with the thesis supervisor],
    [03.10.2023],
    [2. meeting with the thesis supervisor],
    [19.10.2023],
    [Proof reading],
    [23.10.2023],
    [End thesis],
    [30.10.2023],
    [Presentation],
    [11.11.2023]
    ),
  caption: "Project Milestones",
  )

  Two meetings with the thesis supervisor are planned. The first meeting is to gain early feedback 
  about the thesis structure while the second meeting is to discuss the implementation documentation structure and potential questions.
  The proofreading is planned to be done by a third party to ensure that the thesis is free of spelling and grammar mistakes.

#pagebreak()
== Project phases

The project consists of the following phases:

1. planning / specifics for TEKO 
2. requirements engineering
3. research
4. evaluation
5. implementation
6. verification
7. thesis 
8. presentation

#linebreak()
In the first phase, the project schedule is created. Additionally, the thesis template
is made and a skeleton for the table of content is added.
In the first phase, the TEKO specific requirements such as a short curriculum vitae
is also written.
The first phase ends with the introduction of the  problem statement.
The second phase is the requirements engineering phase. In this phase the 
stakeholders and use cases are identified and the requirements are gathered. 
RabbitMQ is a new topic in this thesis and therefore the third phase is deticated
to researching RabbitMQ components, queues and the AMQP protocol.
This research is the basis for the evaluation phase.
In the fourth phase, different AMQP client libraries are evaluated.
The evaluation is based on the research done in the previous phase.
Additionally, an architecture for the microservice is designed.
The fifth phase is the implementation phase. The implementation is based on the architecture designed in 
the previous phase.
The sixth phase is the verification phase. In this phase the microservice is
verified against the requirements.
In the seventh phase, the thesis gets finished and the additional chapters like 
a cover page or acknowledgments are added.
The last phase is the presentation. In this phase a short presentation is created and micro webpage in the thesis portal is launched.

#pagebreak()

#include "../personal/Profitability.typ"

