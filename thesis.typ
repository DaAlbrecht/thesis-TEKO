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
  align: (center, left),
  [*Terminology*],
  [*Description*],
  [OCI],
  [Open Container Initiative],
  [AMQP],
  [Advanced Message Queuing Protocol],
  [TCP],
  [Transmission Control Protocol],
  [FIFO],
  [First In First Out],
), kind: table, caption: "Glossary")<glossary>

#pagebreak()

= Curriculum vitae

#include "personal/cv.typ"

= Introduction

#include "./content/Introduction.typ"

= Task analysis

#include "./content/task_analysis.typ"

= Use cases<Use_cases>

#include "./content/Use_cases.typ"

= Project plan

#include "./content/Projectplan.typ"

= Requirements

#include "./content/Requirements.typ"

= Research

#include "./content/Research.typ"

= Evaluation<evaluation>

#include "./content/Evaluation.typ"

= Implementation

= Verification

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

