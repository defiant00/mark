# mark

Implemented in [Zig](https://ziglang.org/), last compiled with 0.11.0-dev.4004+a57608217.

* `*text*` **bold**
* `_text_` _italics_
* `-` unordered list
* `n.` ordered list
* `-`+ on its own line - divider
* `# text` to `##### text` heading
* `> text` quote
* `[ ]` unchecked check box
* `[X]` checked check box
* `\n` is a `<br>`
  * multiple `\n` is a new paragraph `<p></p>`
* `"text"` is literal text
  * `""` is a literal `"`
* link
* image
* anchor
* table

```
code

as many ` as you want surrounding code
newlines determine if it's a block or inline
optional type, `type:code`

`csharp:
code
`

`js:let x = 7;`
```
