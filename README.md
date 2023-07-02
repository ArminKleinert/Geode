# Geode
A simple and buggy syntax extension for Ruby.

### Features

Translates some bracket-expressions as follows:

`(... -> ...)`            => `{|...| ...}`

`(.sym(...))`             => `{|it| it.sym(...)}`  
`(.sym)`                  => `{|it| it.sym}`

`{sym}`                   => `{|it| it.respond_to?(:sym) ? it.send(:sym) : sym(it)}`  
Geode has no way of checking whether `sym` is a method of `it`. Thus, this workaround is used. If you know that an instance method is used, `(.sym)` should be preferred. This transformation does mean a runtime overhead.

`{... -> ...}`            => `{|it, ...| ...}`

Two "new" operators are available:

`++` translates to `.succ`  
`--` translates to `.pred`

There are two new ways to create Hashes and Arrays:

`\a[1 2 3 4 5]` creates the array `[1, 2, 3, 4, 5]`, but you don't need to type so many commas. (Yes, it barely does anything...)  
`\h{[1, 2], [3, 4]}` translates to `[[1, 2], [3, 4]].to_h`. So it's a slight shortcut, but nicer to read than `{1 => 2, 3 => 4}`, though that is suggestive.

### Example:

test.rb:
```
puts ARGV.map{-> [it, File.foreach(it).to_a.size--]}.map(.to_s)
```

Running `ruby geode.rb test.rb -o transformed.rb` produces the following code:
```
puts ARGV.map{|it| [it, File.foreach(it).to_a.size.pred]}.map{|it|it.to_s}
```

You could also run the code using the `--ev` command and then delete it via. `--del`:
```
# In this example, we use test.rb, transformed.rb and geode.rb as examples. As the interpreter, we use truffleruby for no reason in particular.
$ ruby geode.rb test.rb -o transformed.rb -I truffleruby --ev --args test.rb transformed.rb geode.rb
["transformed.rb", 0]
["geode.rb", 204]
["test.rb", 0]
```

### TODOs:

Currently, the thing does not work within `irb`. This is a top-priority goal of mine, though.

- Get this running within `irb`.
- Use `Ripper` if possible, instead of my own stupid AST-system. (https://ruby-doc.org/stdlib-3.1.2/libdoc/ripper/rdoc/Ripper.html)
- Clean up the code.
- Install this as a little program for easier use.
