// The project function defines how your document looks.
// It takes your content and some metadata and formats it.
// Go ahead and customize it to your liking!
#let project(title: "", abstract: [], authors: (), date: none, logo: none, school: "", degree: "", class: "", body) = {
  // Set the document's basic properties.
  set document(author: authors, title: title)
  set page(numbering: "1", number-align: center)
  set text(font: "New Computer Modern", lang: "en")
  set heading(numbering: "1.1")

[
  #set align(center)
  #text(school)
  #linebreak()
  #text(degree)
  #linebreak()
  #text(class)
]

  // Title page.
  // The page can contain a logo if you pass one with `logo: "logo.png"`.
  v(0.6fr)
  if logo != none {
    align(right, image(logo, width: 26%))
  }
  v(3.6fr)

  text(1.1em, date)
  v(1.2em, weak: true)
  text(2em, weight: 700, title)

  // Author information.
  pad(top: 0.7em, right: 20%, grid(
    columns: (1fr,) * calc.min(3, authors.len()),
    gutter: 1em,
    ..authors.map(author => align(start, strong(author))),
  ))

  v(2.4fr)
  pagebreak()

  // Abstract page.
  v(1fr)
  align(
    center,
  )[
      #heading(outlined: false, numbering: none, text(0.85em, smallcaps[Abstract]))
      #abstract
    ]
  v(1.618fr)

  pagebreak()

  // Table of contents.
  outline(title: "Table of contents", depth: 3, indent: true)
  pagebreak()
  outline(title: "List of figures", target: figure.where(kind: image))
  outline(title: "List of tables", target: figure.where(kind: table))
  outline(title: "List of listings", target: figure.where(kind: raw))

  pagebreak()

  // Main body.
  set par(justify: true)

  body
  pagebreak()

let annex(body) = {
    counter(heading).update(0)
    set heading(numbering: "A", outlined: false)

    show heading: it => {
        if it.level == 1 {
            pagebreak(weak: true)
            block[
                #set par(leading: 0.4em, justify: false)
                #underline(smallcaps[Annex #counter(heading).display(it.numbering): #it.body], evade: true, offset: 4pt)
                #v(0.2em)
            ]
        } else if it.level == 2 {
            block[
                #underline(smallcaps(it.body), evade: true, offset: 3pt)

                #v(10pt)
            ]
        }
    }
    body
}
  show: annex
  include "./content/annexes.typ"

}
