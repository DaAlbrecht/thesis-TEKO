#import "template.typ": *
#import "metadata.typ": *
#import "@preview/tablex:0.0.5": tablex, cellx
#import "personal/Cover.typ" as cover

#show figure.where(kind: "appendix"): it => it.body
#let appendix = figure.with(kind: "appendix", numbering: "A", supplement: [Appendix])
#show link: underline


#show: project.with(
  title: "Microservice for messaging-based replay function",
  authors: (cover.author,),
  abstract: include("content/Abstract.typ"),
  date: "October 30, 2023",
  school: cover.school,
  degree: cover.degree,
  class: cover.class,
)

= Executive summary

#include "./content/Executive_summary.typ"

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
  [CI],
  [Continuous Integration],
  [CD],
  [Continuous Delivery],
  [iff],
  [if and only if],
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

#include "./content/Implementation.typ"

= Verification

#include "./content/Verification.typ"

= Configuration management

#include "./content/Configuration_management.typ"

= Conclusion

#include "./personal/Conclusion.typ"

= Closing remarks

#include "./personal/Closing_remarks.typ"

= Acknowledgement

#include "./personal/Acknowledgement.typ"

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

