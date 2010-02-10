process.mixin require './scope'

# The abstract base class for all CoffeeScript nodes.
# All nodes are implement a "compile_node" method, which performs the
# code generation for that node. To compile a node, call the "compile"
# method, which wraps "compile_node" in some extra smarts, to know when the
# generated code should be wrapped up in a closure. An options hash is passed
# and cloned throughout, containing messages from higher in the AST,
# information about the current scope, and indentation level.

exports.Expressions       : -> @name: this.constructor.name; @values: arguments
exports.LiteralNode       : -> @name: this.constructor.name; @values: arguments
exports.ReturnNode        : -> @name: this.constructor.name; @values: arguments
exports.CommentNode       : -> @name: this.constructor.name; @values: arguments
exports.CallNode          : -> @name: this.constructor.name; @values: arguments
exports.ExtendsNode       : -> @name: this.constructor.name; @values: arguments
exports.ValueNode         : -> @name: this.constructor.name; @values: arguments
exports.AccessorNode      : -> @name: this.constructor.name; @values: arguments
exports.IndexNode         : -> @name: this.constructor.name; @values: arguments
exports.RangeNode         : -> @name: this.constructor.name; @values: arguments
exports.SliceNode         : -> @name: this.constructor.name; @values: arguments
exports.ThisNode          : -> @name: this.constructor.name; @values: arguments
exports.AssignNode        : -> @name: this.constructor.name; @values: arguments
exports.OpNode            : -> @name: this.constructor.name; @values: arguments
exports.CodeNode          : -> @name: this.constructor.name; @values: arguments
exports.SplatNode         : -> @name: this.constructor.name; @values: arguments
exports.ObjectNode        : -> @name: this.constructor.name; @values: arguments
exports.ArrayNode         : -> @name: this.constructor.name; @values: arguments
exports.PushNode          : -> @name: this.constructor.name; @values: arguments
exports.ClosureNode       : -> @name: this.constructor.name; @values: arguments
exports.WhileNode         : -> @name: this.constructor.name; @values: arguments
exports.ForNode           : -> @name: this.constructor.name; @values: arguments
exports.TryNode           : -> @name: this.constructor.name; @values: arguments
exports.ThrowNode         : -> @name: this.constructor.name; @values: arguments
exports.ExistenceNode     : -> @name: this.constructor.name; @values: arguments
exports.ParentheticalNode : -> @name: this.constructor.name; @values: arguments
exports.IfNode            : -> @name: this.constructor.name; @values: arguments

exports.Expressions.wrap  : (values) -> @values: values

# Some helper functions

# Tabs are two spaces for pretty printing.
TAB: '  '
TRAILING_WHITESPACE: /\s+$/g

# Keep the identifier regex in sync with the Lexer.
IDENTIFIER:   /^[a-zA-Z$_](\w|\$)*$/

# Flatten nested arrays recursively.
flatten: (list) ->
  memo: []
  for item in list
    return memo.concat(flatten(item)) if item instanceof Array
    memo.push(item)
    memo
  memo

# Remove all null values from an array.
compact: (input) ->
  item for item in input when item?

# Dup an array or object.
dup: (input) ->
  if input instanceof Array
    val for val in input
  else
    output: {}
    (output[key]: val) for key, val of input
    output

# Merge objects.
merge: (src, dest) ->
  (dest[key]: val) for key, val of src
  dest

# Do any of the elements in the list pass a truth test?
any: (list, test) ->
  result: true for item in list when test(item)
  !!result.length

# Delete a key from an object, returning the value.
del: (obj, key) ->
  val: obj[key]
  delete obj[key]
  val

# Quickie inheritance convenience wrapper to reduce typing.
inherit: (parent, props) ->
  klass: del(props, 'constructor')
  klass extends parent
  (klass.prototype[name]: prop) for name, prop of props
  klass

# # Provide a quick implementation of a children method.
# children: (klass, attrs...) ->
#   klass::children: ->
#     nodes: this[attr] for attr in attrs
#     compact flatten nodes

# Mark a node as a statement, or a statement only.
statement: (klass, only) ->
  klass::is_statement:       -> true
  (klass::is_statement_only:  -> true) if only

# The abstract base class for all CoffeeScript nodes.
# All nodes are implement a "compile_node" method, which performs the
# code generation for that node. To compile a node, call the "compile"
# method, which wraps "compile_node" in some extra smarts, to know when the
# generated code should be wrapped up in a closure. An options hash is passed
# and cloned throughout, containing messages from higher in the AST,
# information about the current scope, and indentation level.
Node: exports.Node: ->

# This is extremely important -- we convert JS statements into expressions
# by wrapping them in a closure, only if it's possible, and we're not at
# the top level of a block (which would be unnecessary), and we haven't
# already been asked to return the result.
Node::compile: (o) ->
  @options: dup(o or {})
  @indent:  o.indent
  top:      if @top_sensitive() then o.top else del o, 'top'
  closure:  @is_statement() and not @is_statement_only() and not top and
            not o.returns and not this instanceof CommentNode and
            not @contains (node) -> node.is_statement_only()
  if closure then @compile_closure(@options) else @compile_node(@options)

# Statements converted into expressions share scope with their parent
# closure, to preserve JavaScript-style lexical scope.
Node::compile_closure: (o) ->
  @indent: o.indent
  o.shared_scope: o.scope
  ClosureNode.wrap(this).compile(o)

# Quick short method for the current indentation level, plus tabbing in.
Node::idt: (tabs) ->
  idt: (@indent || '')
  idt += TAB for i in [0...(tabs or 0)]
  idt

# Does this node, or any of its children, contain a node of a certain kind?
Node::contains: (block) ->
  for node in @children
    return true if block(node)
    return true if node instanceof Node and node.contains block
  false

# Default implementations of the common node methods.
Node::unwrap:             -> this
Node::children:           []
Node::is_statement:       -> false
Node::is_statement_only:  -> false
Node::top_sensitive:      -> false

# A collection of nodes, each one representing an expression.
Expressions: exports.Expressions: inherit Node, {

  constructor: (nodes) ->
    @children: @expressions: flatten nodes
    this

  # Tack an expression on to the end of this expression list.
  push: (node) ->
    @expressions.push(node)
    this

  # Tack an expression on to the beginning of this expression list.
  unshift: (node) ->
    @expressions.unshift(node)
    this

  # If this Expressions consists of a single node, pull it back out.
  unwrap: ->
    if @expressions.length is 1 then @expressions[0] else this

  # Is this an empty block of code?
  empty: ->
    @expressions.length is 0

  # Is the node last in this block of expressions?
  is_last: (node) ->
    l: @expressions.length
    @last_index ||= if @expressions[l - 1] instanceof CommentNode then 2 else 1
    node is @expressions[l - @last_index]

  compile: (o) ->
    o ||= {}
    if o.scope then Node::compile.call(this, o) else @compile_root(o)

  # Compile each expression in the Expressions body.
  compile_node: (o) ->
    (@compile_expression(node, dup(o)) for node in @expressions).join("\n")

  # If this is the top-level Expressions, wrap everything in a safety closure.
  compile_root: (o) ->
    o.indent: @indent: indent: if o.no_wrap then '' else TAB
    o.scope: new Scope(null, this, null)
    code: if o.globals then @compile_node(o) else @compile_with_declarations(o)
    code: code.replace(TRAILING_WHITESPACE, '')
    if o.no_wrap then code else "(function(){\n"+code+"\n})();"

  # Compile the expressions body, with declarations of all inner variables
  # pushed up to the top.
  compile_with_declarations: (o) ->
    code: @compile_node(o)
    args: @contains (node) -> node instanceof ValueNode and node.is_arguments()
    argv: if args and o.scope.check('arguments') then '' else 'var '
    code: @idt() + argv + "arguments = Array.prototype.slice.call(arguments, 0);\n" + code if args
    code: @idt() + 'var ' + o.scope.compiled_assignments() + ";\n" + code  if o.scope.has_assignments(this)
    code: @idt() + 'var ' + o.scope.compiled_declarations() + ";\n" + code if o.scope.has_declarations(this)
    code

  # Compiles a single expression within the expressions body.
  compile_expression: (node, o) ->
    @indent: o.indent
    stmt:    node.is_statement()
    # We need to return the result if this is the last node in the expressions body.
    returns: del(o, 'returns') and @is_last(node) and not node.is_statement_only()
    # Return the regular compile of the node, unless we need to return the result.
    return (if stmt then '' else @idt()) + node.compile(merge(o, {top: true})) + (if stmt then '' else ';') unless returns
    # If it's a statement, the node knows how to return itself.
    return node.compile(merge(o, {returns: true})) if node.is_statement()
    # Otherwise, we can just return the value of the expression.
    return @idt() + 'return ' + node.compile(o) + ';'

}

# Wrap up a node as an Expressions, unless it already is one.
Expressions.wrap: (nodes) ->
  return nodes[0] if nodes.length is 1 and nodes[0] instanceof Expressions
  new Expressions(nodes)

statement Expressions

# Literals are static values that can be passed through directly into
# JavaScript without translation, eg.: strings, numbers, true, false, null...
LiteralNode: exports.LiteralNode: inherit Node, {

  constructor: (value) ->
    @children: [@value: value]
    this

  # Break and continue must be treated as statements -- they lose their meaning
  # when wrapped in a closure.
  is_statement: ->
    @value is 'break' or @value is 'continue'

  compile_node: (o) ->
    idt: if @is_statement() then @idt() else ''
    end: if @is_statement() then ';' else ''
    idt + @value + end

}

LiteralNode::is_statement_only: LiteralNode::is_statement

# Return an expression, or wrap it in a closure and return it.
ReturnNode: exports.ReturnNode: inherit Node, {

  constructor: (expression) ->
    @children: [@expression: expression]
    this

  compile_node: (o) ->
    return @expression.compile(merge(o, {returns: true})) if @expression.is_statement()
    @idt() + 'return ' + @expression.compile(o) + ';'

}

statement ReturnNode, true

# A value, indexed or dotted into, or vanilla.
ValueNode: exports.ValueNode: inherit Node, {

  SOAK: " == undefined ? undefined : "

  constructor: (base, properties) ->
    @children:   flatten(@base: base, @properties: (properties or []))
    this

  push: (prop) ->
    @properties.push(prop)
    @children.push(prop)
    this

  has_properties: ->
    @properties.length or @base instanceof ThisNode

  is_array: ->
    @base instanceof ArrayNode and not @has_properties()

  is_object: ->
    @base instanceof ObjectNode and not @has_properties()

  is_splice: ->
    @has_properties() and @properties[@properties.length - 1] instanceof SliceNode

  is_arguments: ->
    @base is 'arguments'

  unwrap: ->
    if @properties.length then this else @base

  # Values are statements if their base is a statement.
  is_statement: ->
    @base.is_statement and @base.is_statement() and not @has_properties()

  compile_node: (o) ->
    soaked:   false
    only:     del(o, 'only_first')
    props:    if only then @properties[0...@properties.length] else @properties
    baseline: @base.compile o
    parts:    [baseline]

    for prop in props
      if prop instanceof AccessorNode and prop.soak
        soaked: true
        if @base instanceof CallNode and prop is props[0]
          temp: o.scope.free_variable()
          parts[parts.length - 1]: '(' + temp + ' = ' + baseline + ')' + @SOAK + (baseline: temp + prop.compile(o))
        else
          parts[parts.length - 1]: @SOAK + (baseline += prop.compile(o))
      else
        part: prop.compile(o)
        baseline += part
        parts.push(part)

    @last: parts[parts.length - 1]
    @source: if parts.length > 1 then parts[0...parts.length].join('') else null
    code: parts.join('').replace(/\)\(\)\)/, '()))')
    return code unless soaked
    '(' + code + ')'

}

# Pass through CoffeeScript comments into JavaScript comments at the
# same position.
CommentNode: exports.CommentNode: inherit Node, {

  constructor: (lines) ->
    @lines: lines
    this

  compile_node: (o) ->
    delimiter: "\n" + @idt() + '//'
    delimiter + @lines.join(delimiter)

}

statement CommentNode

# Node for a function invocation. Takes care of converting super() calls into
# calls against the prototype's function of the same name.
CallNode: exports.CallNode: inherit Node, {

  constructor: (variable, args) ->
    @children:  flatten [@variable: variable, @args: (args or [])]
    @prefix:    ''
    this

  new_instance: ->
    @prefix: 'new '
    this

  push: (arg) ->
    @args.push(arg)
    @children.push(arg)
    this

  # Compile a vanilla function call.
  compile_node: (o) ->
    return @compile_splat(o) if any @args, (a) -> a instanceof SplatNode
    args: (arg.compile(o) for arg in @args).join(', ')
    return @compile_super(args, o) if @variable is 'super'
    @prefix + @variable.compile(o) + '(' + args + ')'

  # Compile a call against the superclass's implementation of the current function.
  compile_super: (args, o) ->
    methname: o.scope.method.name
    arg_part: if args.length then ', ' + args else ''
    meth: if o.scope.method.proto
      o.scope.method.proto + '.__superClass__.' + methname
    else
      methname + '.__superClass__.constructor'
    meth + '.call(this' + arg_part + ')'

  # Compile a function call being passed variable arguments.
  compile_splat: (o) ->
    meth: @variable.compile o
    obj:  @variable.source or 'this'
    args: for arg, i in @args
      code: arg.compile o
      code: if arg instanceof SplatNode then code else '[' + code + ']'
      if i is 0 then code else '.concat(' + code + ')'
    @prefix + meth + '.apply(' + obj + ', ' + args.join('') + ')'

  # If the code generation wished to use the result of a function call
  # in multiple places, ensure that the function is only ever called once.
  compile_reference: (o) ->
    reference: o.scope.free_variable()
    call: new ParentheticalNode(new AssignNode(reference, this))
    [call, reference]

}

# Node to extend an object's prototype with an ancestor object.
# After goog.inherits from the Closure Library.
ExtendsNode: exports.ExtendsNode: inherit Node, {

  constructor: (child, parent) ->
    @children:  [@child: child, @parent: parent]
    this

  # Hooking one constructor into another's prototype chain.
  compile_node: (o) ->
    constructor:  o.scope.free_variable()
    child:        @child.compile(o)
    parent:       @parent.compile(o)
    @idt() + constructor + ' = function(){};\n' + @idt() +
      constructor + '.prototype = ' + parent + ".prototype;\n" + @idt() +
      child + '.__superClass__ = ' + parent + ".prototype;\n" + @idt() +
      child + '.prototype = new ' + constructor + "();\n" + @idt() +
      child + '.prototype.constructor = ' + child + ';'

}

statement ExtendsNode

# A dotted accessor into a part of a value, or the :: shorthand for
# an accessor into the object's prototype.
AccessorNode: exports.AccessorNode: inherit Node, {

  constructor: (name, tag) ->
    @children:  [@name: name]
    @prototype: tag is 'prototype'
    @soak:      tag is 'soak'
    this

  compile_node: (o) ->
    '.' + (if @prototype then 'prototype.' else '') + @name.compile(o)

}

# An indexed accessor into a part of an array or object.
IndexNode: exports.IndexNode: inherit Node, {

  constructor: (index) ->
    @children: [@index: index]
    this

  compile_node: (o) ->
    '[' + @index.compile(o) + ']'

}

# A this-reference, using '@'.
ThisNode: exports.ThisNode: inherit Node, {

  constructor: (property) ->
    @property: property or null
    this

  compile_node: (o) ->
    'this' + (if @property then '.' + @property else '')

}

# A range literal. Ranges can be used to extract portions (slices) of arrays,
# or to specify a range for list comprehensions.
RangeNode: exports.RangeNode: inherit Node, {

  constructor: (from, to, exclusive) ->
    @children:  [@from: from, @to: to]
    @exclusive: !!exclusive
    this

  compile_variables: (o) ->
    @indent:   o.indent
    @from_var: o.scope.free_variable()
    @to_var:   o.scope.free_variable()
    @from_var + ' = ' + @from.compile(o) + '; ' + @to_var + ' = ' + @to.compile(o) + ";\n" + @idt()

  compile_node: (o) ->
    return    @compile_array(o) unless o.index
    idx:      del o, 'index'
    step:     del o, 'step'
    equals:   if @exclusive then '' else '='
    intro:    '(' + @from_var + ' <= ' + @to_var + ' ? ' + idx
    compare:  intro + ' <' + equals + ' ' + @to_var + ' : ' + idx + ' >' + equals + ' ' + @to_var + ')'
    incr:     intro + ' += ' + step + ' : ' + idx + ' -= ' + step + ')'
    vars + '; ' + compare + '; ' + incr

  # Expand the range into the equivalent array, if it's not being used as
  # part of a comprehension, slice, or splice.
  # TODO: This generates pretty ugly code ... shrink it.
  compile_array: (o) ->
    body: Expressions.wrap(new LiteralNode 'i')
    arr:  Expressions.wrap(new ForNode(body, {source: (new ValueNode(this))}, 'i'))
    (new ParentheticalNode(new CallNode(new CodeNode([], arr)))).compile(o)

}

# An array slice literal. Unlike JavaScript's Array#slice, the second parameter
# specifies the index of the end of the slice (just like the first parameter)
# is the index of the beginning.
SliceNode: exports.SliceNode: inherit Node, {

  constructor: (range) ->
    @children: [@range: range]
    this

  compile_node: (o) ->
    from:       @range.from.compile(o)
    to:         @range.to.compile(o)
    plus_part:  if @range.exclusive then '' else ' + 1'
    ".slice(" + from + ', ' + to + plus_part + ')'

}

# An object literal.
ObjectNode: exports.ObjectNode: inherit Node, {

  constructor: (props) ->
    @objects: @properties: props or []
    this

  # All the mucking about with commas is to make sure that CommentNodes and
  # AssignNodes get interleaved correctly, with no trailing commas or
  # commas affixed to comments. TODO: Extract this and add it to ArrayNode.
  compile_node: (o) ->
    o.indent: @idt(1)
    non_comments: prop for prop in @properties when not (prop instanceof CommentNode)
    last_noncom:  non_comments[non_comments.length - 1]
    props: for prop, i in @properties
      join:   ",\n"
      join:   "\n" if prop is last_noncom or prop instanceof CommentNode
      join:   '' if i is non_comments.length - 1
      indent: if prop instanceof CommentNode then '' else @idt(1)
      indent + prop.compile(o) + join
    '{\n' + props.join('') + '\n' + @idt() + '}'

}

# An array literal.
ArrayNode: exports.ArrayNode: inherit Node, {

  constructor: (objects) ->
    @children: @objects: objects or []
    this

  compile_node: (o) ->
    o.indent: @idt(1)
    objects: for obj, i in @objects
      code: obj.compile(o)
      if obj instanceof CommentNode
        '\n' + code + '\n' + o.indent
      else if i is @objects.length - 1
        code
      else
        code + ', '
    objects: objects.join('')
    ending: if objects.indexOf('\n') >= 0 then "\n" + @idt() + ']' else ']'
    '[' + objects + ending

}

# A faux-node that is never created by the grammar, but is used during
# code generation to generate a quick "array.push(value)" tree of nodes.
PushNode: exports.PushNode: {

  wrap: (array, expressions) ->
    expr: expressions.unwrap()
    return expressions if expr.is_statement_only() or expr.contains (n) -> n.is_statement_only()
    Expressions.wrap(new CallNode(
      new ValueNode(new LiteralNode(array), [new AccessorNode(new LiteralNode('push'))]), [expr]
    ))

}

# A faux-node used to wrap an expressions body in a closure.
ClosureNode: exports.ClosureNode: {

  wrap: (expressions, statement) ->
    func: new ParentheticalNode(new CodeNode([], Expressions.wrap(expressions)))
    call: new CallNode(new ValueNode(func, new AccessorNode(new LiteralNode('call'))), [new LiteralNode('this')])
    if statement then Expressions.wrap(call) else call

}

# Setting the value of a local variable, or the value of an object property.
AssignNode: exports.AssignNode: inherit Node, {

  PROTO_ASSIGN: /^(\S+)\.prototype/
  LEADING_DOT:  /^\.(prototype\.)?/

  constructor: (variable, value, context) ->
    @children: [@variable: variable, @value: value]
    @context: context
    this

  top_sensitive: ->
    true

  is_value: ->
    @variable instanceof ValueNode

  is_statement: ->
    @is_value() and (@variable.is_array() or @variable.is_object())

  compile_node: (o) ->
    top:    del o, 'top'
    return  @compile_pattern_match(o) if @is_statement()
    return  @compile_splice(o) if @is_value() and @variable.is_splice()
    stmt:   del o, 'as_statement'
    name:   @variable.compile(o)
    last:   if @is_value() then @variable.last.replace(@LEADING_DOT, '') else name
    match:  name.match(@PROTO_ASSIGN)
    proto:  match and match[1]
    if @value instanceof CodeNode
      @value.name:  last  if last.match(IDENTIFIER)
      @value.proto: proto if proto
    return name + ': ' + @value.compile(o) if @context is 'object'
    o.scope.find(name) unless @is_value() and @variable.has_properties()
    val: name + ' = ' + @value.compile(o)
    return @idt() + val + ';' if stmt
    val: '(' + val + ')' if not top or o.returns
    val: @idt() + 'return ' + val if o.returns
    val

  # Implementation of recursive pattern matching, when assigning array or
  # object literals to a value. Peeks at their properties to assign inner names.
  # See: http://wiki.ecmascript.org/doku.php?id=harmony:destructuring
  compile_pattern_match: (o) ->
    val_var: o.scope.free_variable()
    assigns: [@idt() + val_var + ' = ' + @value.compile(o) + ';']
    o.top: true
    o.as_statement: true
    for obj, i in @variable.base.objects
      [obj, i]: [obj.value, obj.variable.base] if @variable.is_object()
      access_class: if @variable.is_array() then IndexNode else AccessorNode
      if obj instanceof SplatNode
        val: new LiteralNode(obj.compile_value(o, val_var, @variable.base.objects.indexOf(obj)))
      else
        val: new ValueNode(val_var, [new access_class(new LiteralNode(i))])
      assigns.push(new AssignNode(obj, val).compile(o))
    assigns.join("\n")

  compile_splice: (o) ->
    name:   @variable.compile(merge(o, {only_first: true}))
    range:  @variable.properties.last.range
    plus:   if range.exclusive then '' else ' + 1'
    from:   range.from.compile(o)
    to:     range.to.compile(o) + ' - ' + from + plus
    name + '.splice.apply(' + name + ', [' + from + ', ' + to + '].concat(' + @value.compile(o) + '))'

}

# A function definition. The only node that creates a new Scope.
# A CodeNode does not have any children -- they're within the new scope.
CodeNode: exports.CodeNode: inherit Node, {

  constructor: (params, body, tag) ->
    @params:  params
    @body:    body
    @bound:   tag is 'boundfunc'
    this

  compile_node: (o) ->
    shared_scope: del o, 'shared_scope'
    top:          del o, 'top'
    o.scope:      shared_scope or new Scope(o.scope, @body, this)
    o.returns:    true
    o.top:        true
    o.indent:     @idt(if @bound then 2 else 1)
    del o, 'no_wrap'
    del o, 'globals'
    if @params[@params.length - 1] instanceof SplatNode
      splat: @params.pop()
      splat.index: @params.length
      @body.unshift(splat)
    (o.scope.parameter(param)) for param in @params
    code: if @body.expressions.length then '\n' + @body.compile_with_declarations(o) + '\n' else ''
    name_part: if @name then ' ' + @name else ''
    func: 'function' + (if @bound then '' else name_part) + '(' + @params.join(', ') + ') {' + code + @idt(if @bound then 1 else 0) + '}'
    func: '(' + func + ')' if top and not @bound
    return func unless @bound
    inner: '(function' + name_part + '() {\n' + @idt(2) + 'return __func.apply(__this, arguments);\n' + @idt(1) + '});'
    '(function(__this) {\n' + @idt(1) + 'var __func = ' + func + ';\n' + @idt(1) + 'return ' + inner + '\n' + @idt() + '})(this)'

  top_sensitive: ->
    true

}

# A splat, either as a parameter to a function, an argument to a call,
# or in a destructuring assignment.
SplatNode: exports.SplatNode: inherit Node, {

  constructor: (name) ->
    @children: [@name: name]
    this

  compile_node: (o) ->
    if @index then @compile_param(o) else @name.compile(o)

  compile_param: (o) ->
    o.scope.find @name
    @name + ' = Array.prototype.slice.call(arguments, ' + @index + ')'

  compile_value: (o, name, index) ->
    "Array.prototype.slice.call(" + @name + ', ' + @index + ')'

}

# A while loop, the only sort of low-level loop exposed by CoffeeScript. From
# it, all other loops can be manufactured.
WhileNode: exports.WhileNode: inherit Node, {

  constructor: (condition, body) ->
    @children:[@condition: condition, @body: body]
    this

  top_sensitive: ->
    true

  compile_node: (o) ->
    returns:    del(o, 'returns')
    top:        del(o, 'top') and not returns
    o.indent:   @idt(1)
    o.top:      true
    cond:       @condition.compile(o)
    set:        ''
    if not top
      rvar:     o.scope.free_variable()
      set:      @idt() + rvar + ' = [];\n'
      @body:    PushNode.wrap(rvar, @body)
    post:       if returns then '\n' + @idt() + 'return ' + rvar + ';' else ''
    pre:        set + @idt() + 'while (' + cond + ')'
    return pre + ' null;' + post if not @body
    pre + ' {\n' + @body.compile(o) + '\n' + @idt() + '}' + post

}

statement WhileNode

# Simple Arithmetic and logical operations. Performs some conversion from
# CoffeeScript operations into their JavaScript equivalents.
OpNode: exports.OpNode: inherit Node, {

  CONVERSIONS: {
    '==':   '==='
    '!=':   '!=='
    'and':  '&&'
    'or':   '||'
    'is':   '==='
    'isnt': '!=='
    'not':  '!'
  }

  CHAINABLE:        ['<', '>', '>=', '<=', '===', '!==']
  ASSIGNMENT:       ['||=', '&&=', '?=']
  PREFIX_OPERATORS: ['typeof', 'delete']

  constructor: (operator, first, second, flip) ->
    @children: [@first: first, @second: second]
    @operator: @CONVERSIONS[operator] or operator
    @flip: !!flip
    this

  is_unary: ->
    not @second

  is_chainable: ->
    @CHAINABLE.indexOf(@operator) >= 0

  compile_node: (o) ->
    return @compile_chain(o)      if @is_chainable() and @first.unwrap() instanceof OpNode and @first.unwrap().is_chainable()
    return @compile_assignment(o) if @ASSIGNMENT.indexOf(@operator) >= 0
    return @compile_unary(o)      if @is_unary()
    return @compile_existence(o)  if @operator is '?'
    @first.compile(o) + ' ' + @operator + ' ' + @second.compile(o)

  # Mimic Python's chained comparisons. See:
  # http://docs.python.org/reference/expressions.html#notin
  compile_chain: (o) ->
    shared: @first.unwrap().second
    [@first.second, shared]: shared.compile_reference(o) if shared instanceof CallNode
    '(' + @first.compile(o) + ') && (' + shared.compile(o) + ' ' + @operator + ' ' + @second.compile(o) + ')'

  compile_assignment: (o) ->
    [first, second]: [@first.compile(o), @second.compile(o)]
    o.scope.find(first) if @first.unwrap.match(IDENTIFIER)
    return first + ' = ' + ExistenceNode.compile_test(o, @first) + ' ? ' + first + ' : ' + second if @operator is '?='
    first + ' = ' + first + ' ' + @operator.substr(0, 2) + ' ' + second

  compile_existence: (o) ->
    [first, second]: [@first.compile(o), @second.compile(o)]
    ExistenceNode.compile_test(o, @first) + ' ? ' + first + ' : ' + second

  compile_unary: (o) ->
    space: if @PREFIX_OPERATORS.indexOf(@operator) >= 0 then ' ' else ''
    parts: [@operator, space, @first.compile(o)]
    parts: parts.reverse() if @flip
    parts.join('')

}










































