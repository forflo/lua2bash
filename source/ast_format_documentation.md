# Expression node class
Nodes whose tags have one of the following
values are considered to be in this class.

"Op", "Id", "True", "False", "Nil", "Number", "String", "Table",
"Function", "Call", "Pair", "Paren", "Index"

Expression nodes can be tested with the function
util.isExpNode

# Statement node class
Nodes whose tags have one of the following values
are considered to denote statements.

"Call", "Fornum", "Local", "Forin", "Repeat",
"Return", "Break", "If", "While", "Do", "Set"

Statement nodes can be tested with the function
util.isStmtNode

# Block node class
Nodes whose tags have one of the following values
are considered to directly contain zero or more
statement nodes.

"Block", "Do"

Block nodes can be tested with the function
util.isBlockNode

# Constant node class
Nodes that denote constants, that is the fundamental
building blocks of values. Nodes of this class
are guaranteed to not contain any sub AST

"True", "False", "Number", "Nil", "String"

Constant nodes can be tested with the function
util.isConstantNode
