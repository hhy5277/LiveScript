# CoffeeScript can be used both on the server, as a command-line compiler based
# on Node.js/V8, or to run CoffeeScripts directly in the browser. This module
# contains the main entry functions for tokenzing, parsing, and compiling source
# CoffeeScript into JavaScript.

fs       = require 'fs'
path     = require 'path'
{Lexer}  = require './lexer'
{parser} = require './parser'

# TODO: Remove registerExtension when fully deprecated
if require.extensions
  require.extensions['.coffee'] = (module, filename) ->
    code = exports.compile fs.readFileSync filename, 'utf8'
    module._compile code, filename
else if require.registerExtension
  require.registerExtension '.coffee', -> exports.compile it

# The current CoffeeScript version number.
exports.VERSION = '0.9.4'

# Compile a string of CoffeeScript code to JavaScript, using the Coffee/Jison
# compiler.
exports.compile = (code, options = {}) ->
  try
    (parser.parse lexer.tokenize code).compile options
  catch err
    err.message = "In #{options.fileName}, #{err.message}" if options.fileName
    throw err

# Tokenize a string of CoffeeScript code, and return the array of tokens.
exports.tokens = (code, options) ->
  lexer.tokenize code, options

# Tokenize and parse a string of CoffeeScript code, and return the AST. You can
# then compile it by calling `.compile()` on the root, or traverse it by using
# `.traverse()` with a callback.
exports.nodes = (code, options) ->
  parser.parse lexer.tokenize code, options

# Compile and execute a string of CoffeeScript (on the server), correctly
# setting `__filename`, `__dirname`, and relative `require()`.
exports.run = (code, options) ->
  root = module
  root = root.parent while root.parent
  root.filename = fs.realpathSync options.fileName or '.'
  root.moduleCache and= {}
  if require.extensions or path.extname(root.filename) isnt '.coffee'
    code = exports.compile code, options
  root._compile code, root.filename

# Compile and evaluate a string of CoffeeScript (in a Node.js-like environment).
# The CoffeeScript REPL uses this to run the input.
exports.eval = (code, options) ->
  __filename = options.fileName
  __dirname  = path.dirname __filename
  eval exports.compile code, options

# Instantiate a Lexer for our use here.
lexer = new Lexer

# The real Lexer produces a generic stream of tokens. This object provides a
# thin wrapper around it, compatible with the Jison API. We can then pass it
# directly as a "Jison lexer".
parser.lexer =
  lex: ->
    [tag, @yytext, @yylineno] = @tokens[@pos++] or ['']
    tag
  setInput: (@tokens) -> @pos = 0
  upcomingInput: -> ''

parser.yy = require './nodes'
