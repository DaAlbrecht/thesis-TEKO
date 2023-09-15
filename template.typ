// The project function defines how your document looks.
// It takes your content and some metadata and formats it.
// Go ahead and customize it to your liking!
#let project(title: "", abstract: [], authors: (), date: none, logo: none, body) = {
  // Set the document's basic properties.
  set document(author: authors, title: title)
  set page(numbering: "1", number-align: center)
  set text(font: "New Computer Modern", lang: "en")
  set heading(numbering: "1.1")

  // Title page.
  // The page can contain a logo if you pass one with `logo: "logo.png"`.
  v(0.6fr)
  if logo != none {
    align(right, image(logo, width: 26%))
  }
  v(9.6fr)

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
  outline(depth: 3, indent: true)
  outline(title: "List of figures", target: figure.where(kind: image))
  outline(title: "List of tables", target: figure.where(kind: table))
  pagebreak()

  // Main body.
  set par(justify: true)

  body
  pagebreak()
  bibliography("bibliography.yaml")
  outline(title: "Appendix", target: figure.where(kind: "appendix"))
}
