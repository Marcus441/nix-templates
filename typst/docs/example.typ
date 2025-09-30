#set page(paper: "a4")
#set heading(numbering: "1.")

#show link: set text(fill: blue, weight: 700)
#show link: underline

= The Typst Playground

Welcome to the Typst Playground! This is a sandbox where you can experiment with
Typst. You can type anywhere in the editor panel on the left. The preview panel
to the right will update live.

= Basics <basics>

Typst is a _markup_ language. You use it to express not just the content, but
also the structure and formatting of your document. For example, surrounding a
word with underscores _emphasizes_ it with italics and starting a line with an
equals sign creates a section heading.

Typst has lightweight syntax like this for the most common formatting needs.
Among other things, you can use it to:

- *Strongly emphasize* some text
- Refer to @basics
- Typeset math: $a, b in { 1/2, sqrt(4 a b) }$

That's just the surface though! Typst has powerful systems for scripting,
styling, introspection, and more. In the realm of a Typst document, there is
nothing you can't automate.

= Next steps

To learn more about Typst, we recommend you to check out our tutorial at
https://typst.app/docs/tutorial.

Once you've explored Typst a bit, why not set yourself up a proper editing
environment?

#import "@preview/tiaoma:0.3.0"
#let next-step(url, body) = grid(columns: 2, gutter: 1em, tiaoma.qrcode(url, width: 3em), {
  show strong: link.with(url)
  body
})

#next-step(
  "https://typst.app/signup",
)[
  To get access to multi-file projects, live collaboration, and more, *sign up* to
  our web app for free.
]

#next-step(
  "https://typst.app/open-source/#download",
)[
  You can also *download* our free and open-source command line tool to continue
  your journey locally.
]
