/// Syntax tree for the supported subset.
library;

sealed class Node {
  Node(this.line, this.column);

  /// 1-based source position.
  final int line;
  final int column;
}

// --- statements -----------------------------------------------------------

final class TextNode extends Node {
  TextNode(super.line, super.column, this.text);
  final String text;
}

final class OutputNode extends Node {
  OutputNode(super.line, super.column, this.expr);
  final Expr expr;
}

final class ForNode extends Node {
  ForNode(
    super.line,
    super.column,
    this.targets,
    this.iterable,
    this.body,
    this.orElse,
  );
  final List<String> targets;
  final Expr iterable;
  final List<Node> body;
  final List<Node>? orElse;
}

final class IfNode extends Node {
  IfNode(super.line, super.column, this.test, this.body, this.orElse);
  final Expr test;
  final List<Node> body;
  final List<Node>? orElse;
}

final class SetNode extends Node {
  SetNode(super.line, super.column, this.targets, this.value);
  final List<String> targets;
  final Expr value;
}

// --- expressions ----------------------------------------------------------

sealed class Expr extends Node {
  Expr(super.line, super.column);
}

final class Literal extends Expr {
  Literal(super.line, super.column, this.value);
  final Object? value;
}

final class Name extends Expr {
  Name(super.line, super.column, this.name);
  final String name;
}

final class Lookup extends Expr {
  Lookup(super.line, super.column, this.target, this.key);
  final Expr target;
  final Expr key;
}

/// A parenthesised expression: a precedence boundary (see jsassoc.dart).
final class Group extends Expr {
  Group(super.line, super.column, this.inner);
  final Expr inner;
}

final class ListLiteral extends Expr {
  ListLiteral(super.line, super.column, this.items);
  final List<Expr> items;
}

final class DictLiteral extends Expr {
  DictLiteral(super.line, super.column, this.keys, this.values);
  final List<Expr> keys;
  final List<Expr> values;
}

final class InlineIf extends Expr {
  InlineIf(super.line, super.column, this.test, this.body, this.orElse);
  final Expr test;
  final Expr body;
  final Expr? orElse;
}

/// `and`, `or`, `~`, arithmetic, `in` / `not in`.
final class Binary extends Expr {
  Binary(super.line, super.column, this.op, this.left, this.right);
  final String op;
  final Expr left;
  final Expr right;
}

/// `not`, unary `-` and `+`, and `floor` (Nunjucks `//` is emitted as
/// `Math.floor(a / b)`).
final class Unary extends Expr {
  Unary(super.line, super.column, this.op, this.operand);
  final String op;
  final Expr operand;
}

/// `a < b == c`: evaluated left to right, each result feeding the next.
final class Compare extends Expr {
  Compare(super.line, super.column, this.first, this.ops, this.operands);
  final Expr first;
  final List<String> ops;
  final List<Expr> operands;
}

final class FilterCall extends Expr {
  FilterCall(super.line, super.column, this.name, this.target, this.args);
  final String name;
  final Expr target;
  final List<Expr> args;
}
