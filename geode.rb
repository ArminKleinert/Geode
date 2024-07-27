#!/usr/bin/env ruby
# frozen_string_literal: true

# [\s]                  Spaces
# ,                     Comma
# #.*                   Matches whole comment
# ->                    Lambda-arrow
# \\h{                  Prefix for shorter maps
# \\a\[                 Prefix for comma-less arrays
# [()\[\]{}]            Matches opening and closing brackets.
# \*\*                  Matches **
# <=>                   Matches <=>
# [<>][<>=]?            Matches <, >, <<, >>, <=, >=
# !~                    Matches !~
# =[=~]?                Matches == and =~
# \+\+                  Matches ++ (later re-written into .succ)
# \-\-                  Matches -- (later re-written into .pred)
# [!+\-\*\/\^&\|][=]?   Matches !, +, -, *, /, ^, &, |, !=, +=, -=, *=, /=, ^=, &=, |=
# "(?:\\.|[^\\"])*"?    Matches strings
# [a-zA-Z0-9\._?!&]+    Matches symbols and numbers.


# Scan the text using RE, remove empty tokens and remove comments.
def tokenize(s, regexp)
  s.scan(regexp).flatten.reject { |w| w.empty? }
end

def prefixed_ast(sym, tokens, level)
  list(sym, make_ast(tokens, level + 1, "", true))
end

def raise_if_unexpected(expected, t, level)
  raise "Unexpected '#{t}'" if level == 0 || expected != t
end

def read_symbol(t)
  t
end

# (... -> ...)            => {|...| ...}
# (.sym(...))             => {|it| it.sym(...)}
def process_list(tks)
  if tks[0].start_with?(".")
    ["{|it|it"] + tks + ["}"]
  elsif tks.size == 1 && tks[0].start_with?("&:")
    ["{|it|it." + tks[0][2..] + "}"]
  elsif tks.include?("->")
    i = tks.index "->"
    ["{|"] + tks[0...i] + ["|"] + tks[(i+1)..] + ["}"]
  else
    ["("] + tks + [")"]
  end
end

def process_array(tks)
  ["[", tks.map(&:strip).reject(&:empty?).join(", "),"]"]
end

# {sym}                   => {|it| it.respond_to?(:sym) ? it.send(:sym) : sym(it)}
# {... -> ...}            => {|it, ...| ...}
def process_curlies(tks)
  if tks.size == 1
    ["{|it|it.respond_to?(:\"#{tks[0]}\") ? it.send(:\"#{tks[0]}\") : #{tks[0]}(it)}"]
  elsif tks.include? "->"
    i = tks.index "->"
    a = ["{|it"]
    a << ", " if i != 0
    a += tks[0...i] + ["|"] + tks[(i+1)..] + ["}"]
    a
  else
    ["{|it|"] + tks + ["}"]
  end
end
                                      
def make_ast(tokens, level = 0, expected = "", stop_after_1 = false)
  root = []
  while (t = tokens.shift) != nil
    case t
    when "->"
      root << "->"
    when "\\h{"
      a = ["["] + make_ast(tokens, level + 1, "}") + ["].to_h"]
      root += a
    when "{"
      root += process_curlies(make_ast(tokens, level+1, "}"))
    when "("
      root += process_list(make_ast(tokens, level+1, ")"))
    when ")"
      raise_if_unexpected(expected, t, level)
      return root
    when "\\a["
      root += process_array(make_ast(tokens, level + 1, "]"))
    when "["
      root << "[" << make_ast(tokens, level + 1, "]") << "]"
    when "]"
      raise_if_unexpected(expected, t, level)
      return root
    when "}"
      raise_if_unexpected(expected, t, level)
      return root
    when '"'
      raise LyraError.new("Unexpected '\"'", :"parse-error")
    when /^"(?:\\.|[^\\"])*"$/
      root << t
    when /^[!+\-\*\/\^&\|][=]?$/
      root << t
    when "++"
      root << ".succ"
    when "--"
      root << ".pred"
    else
      root << read_symbol(t)
    end
    return root[0] if stop_after_1
  end
  if level != 0
    raise LyraError.new("Expected ')', got EOF", :"parse-error") 
  end
  root.join
end

require 'optparse'
require 'date'

options = {:outfile =>nil, :ev =>false, :irb =>false, :del => false, :rbi => "ruby", :args => ""}
OptionParser.new do |parser|
  parser.on("-h", "--help", "Show usage information.") do
    puts parser.help
    exit 0
  end
  
  parser.on("-o", "--out outputfile", "Specify output file.") do |output|
    options[:outfile] = output
  end
  
  parser.on("-e", "--ev", "--eval", "Run the output using ruby or the interpreter specified in -rbi.") do
    options[:ev] = true
  end
  
  parser.on("-i", "--irb", "Start irb with output file. Sets -ev option to off.") do
    options[:irb] = true
  end
  
  parser.on("-a [args]", "--args [args]", "Specify the arguments for the interpreter if -ev or -irb is used.") do |args|
    options[:args] = args
  end
  
  parser.on("-d", "--del", "Deletes the output file after execution.") do
    options[:del] = true
  end
  
  #parser.on("-cc", "--compiler=[comp]", "Set the c compiler for the preprocessor.") do |compiler|
  #  options[:compiler] = compiler
  #end
  
  parser.on("-I", "--rbi interpreter", "Sets the ruby interpreter to use for evaluation if -ev is set. Defaults to 'ruby'.") do |interpreter|
    options[:rbi] = interpreter
  end

  PARSER = parser
end.parse!(ARGV)

options[:input_files] = ARGV
file_suffix = Time.now.to_i.to_s

if options[:input_files].empty?
  puts "No input files."
  puts PARSER.help
  exit 1
end

if options[:outfile].nil?
  options[:outfile] = "#{options[:input_files][0]}#{file_suffix}.rb"
end

# TODO: Extend for multiple files
def main(from, to)
  regexp = /([\s]|,|#.*|->|\\h{|\\a\[|[()\[\]{}]|\*\*|<=>|[<>][<>=]?|!~|=[=~]?|\+\+|\-\-|[!+\-\*\/\^&\|][=]?|"(?:\\.|[^\\"])*"?|[a-zA-Z0-9\._?!&]+)/
  IO.write(to, make_ast(tokenize(IO.read(from), regexp)))
end

main(options[:input_files][0], options[:outfile])

if options[:irb]
  options[:ev] = false
  system "irb -r ./#{options[:outfile]} #{options[:args]}"
elsif options[:ev]
  files = options[:input_files][1..]
  files.unshift(options[:outfile])
  system "#{options[:rbi]} #{files.join(" ")} #{options[:args]}"
end

if options[:del]
  file = options[:outfile]
  File.delete(file) if File.exists? file
end

#p options

