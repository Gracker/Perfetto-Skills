from __future__ import annotations

from dataclasses import dataclass
import json
import math
import re
from typing import Any, Mapping


@dataclass(frozen=True)
class Token:
    kind: str
    value: Any


_OPERATORS = (
    "===", "!==", "?.", "??", "=>", ">=", "<=", "==", "!=", "&&", "||",
    "(", ")", "[", "]", ",", ".", "!", ">", "<", "+", "-", "*", "/", "%",
)
_IDENTIFIER = re.compile(r"[A-Za-z_$][A-Za-z0-9_$]*")
_NUMBER = re.compile(r"(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?")


def _tokenize(source: str) -> list[Token]:
    tokens: list[Token] = []
    index = 0
    while index < len(source):
        char = source[index]
        if char.isspace():
            index += 1
            continue
        if source.startswith("${", index):
            end = source.find("}", index + 2)
            if end < 0:
                raise ValueError("unterminated ${...} placeholder")
            tokens.append(Token("placeholder", source[index + 2 : end]))
            index = end + 1
            continue
        if char in "'\"":
            quote = char
            index += 1
            value: list[str] = []
            while index < len(source):
                char = source[index]
                if char == quote:
                    index += 1
                    break
                if char == "\\":
                    index += 1
                    if index >= len(source):
                        raise ValueError("unterminated string escape")
                    escapes = {"n": "\n", "r": "\r", "t": "\t"}
                    value.append(escapes.get(source[index], source[index]))
                    index += 1
                    continue
                value.append(char)
                index += 1
            else:
                raise ValueError("unterminated string literal")
            tokens.append(Token("literal", "".join(value)))
            continue
        number = _NUMBER.match(source, index)
        if number:
            raw = number.group(0)
            tokens.append(Token("literal", float(raw) if any(c in raw for c in ".eE") else int(raw)))
            index = number.end()
            continue
        identifier = _IDENTIFIER.match(source, index)
        if identifier:
            raw = identifier.group(0)
            keywords = {"true": True, "false": False, "null": None, "undefined": None}
            tokens.append(Token("literal", keywords[raw]) if raw in keywords else Token("identifier", raw))
            index = identifier.end()
            continue
        operator = next((candidate for candidate in _OPERATORS if source.startswith(candidate, index)), None)
        if operator is None:
            raise ValueError(f"unsupported expression token at offset {index}: {source[index:index + 16]!r}")
        tokens.append(Token(operator, operator))
        index += len(operator)
    tokens.append(Token("eof", None))
    return tokens


class Parser:
    def __init__(self, source: str):
        self.tokens = _tokenize(source)
        self.index = 0

    def current(self, kind: str | None = None) -> Token | bool:
        token = self.tokens[self.index]
        return token if kind is None else token.kind == kind

    def peek(self, offset: int = 1) -> Token:
        return self.tokens[min(self.index + offset, len(self.tokens) - 1)]

    def accept(self, kind: str) -> Token | None:
        if self.current(kind):
            token = self.tokens[self.index]
            self.index += 1
            return token
        return None

    def expect(self, kind: str) -> Token:
        token = self.accept(kind)
        if token is None:
            actual = self.tokens[self.index].kind
            raise ValueError(f"expected {kind!r}, got {actual!r}")
        return token

    def parse(self) -> tuple[Any, ...]:
        node = self.parse_or()
        self.expect("eof")
        return node

    def parse_or(self) -> tuple[Any, ...]:
        node = self.parse_nullish()
        while self.accept("||"):
            node = ("binary", "||", node, self.parse_nullish())
        return node

    def parse_nullish(self) -> tuple[Any, ...]:
        node = self.parse_and()
        while self.accept("??"):
            node = ("binary", "??", node, self.parse_and())
        return node

    def parse_and(self) -> tuple[Any, ...]:
        node = self.parse_equality()
        while self.accept("&&"):
            node = ("binary", "&&", node, self.parse_equality())
        return node

    def parse_equality(self) -> tuple[Any, ...]:
        node = self.parse_comparison()
        while self.tokens[self.index].kind in {"===", "!==", "==", "!="}:
            operator = self.tokens[self.index].kind
            self.index += 1
            node = ("binary", operator, node, self.parse_comparison())
        return node

    def parse_comparison(self) -> tuple[Any, ...]:
        node = self.parse_additive()
        while self.tokens[self.index].kind in {">", ">=", "<", "<="}:
            operator = self.tokens[self.index].kind
            self.index += 1
            node = ("binary", operator, node, self.parse_additive())
        return node

    def parse_additive(self) -> tuple[Any, ...]:
        node = self.parse_multiplicative()
        while self.tokens[self.index].kind in {"+", "-"}:
            operator = self.tokens[self.index].kind
            self.index += 1
            node = ("binary", operator, node, self.parse_multiplicative())
        return node

    def parse_multiplicative(self) -> tuple[Any, ...]:
        node = self.parse_unary()
        while self.tokens[self.index].kind in {"*", "/", "%"}:
            operator = self.tokens[self.index].kind
            self.index += 1
            node = ("binary", operator, node, self.parse_unary())
        return node

    def parse_unary(self) -> tuple[Any, ...]:
        if self.tokens[self.index].kind in {"!", "+", "-"}:
            operator = self.tokens[self.index].kind
            self.index += 1
            return ("unary", operator, self.parse_unary())
        return self.parse_postfix()

    def _looks_like_parenthesized_lambda(self) -> bool:
        if not self.current("("):
            return False
        cursor = self.index + 1
        if self.tokens[cursor].kind != "identifier":
            return False
        cursor += 1
        while self.tokens[cursor].kind == ",":
            cursor += 1
            if self.tokens[cursor].kind != "identifier":
                return False
            cursor += 1
        return self.tokens[cursor].kind == ")" and self.tokens[cursor + 1].kind == "=>"

    def parse_argument(self) -> tuple[Any, ...]:
        if self.current("identifier") and self.peek().kind == "=>":
            name = self.expect("identifier").value
            self.expect("=>")
            return ("lambda", (name,), self.parse_or())
        if self._looks_like_parenthesized_lambda():
            self.expect("(")
            names = [self.expect("identifier").value]
            while self.accept(","):
                names.append(self.expect("identifier").value)
            self.expect(")")
            self.expect("=>")
            return ("lambda", tuple(names), self.parse_or())
        return self.parse_or()

    def parse_postfix(self) -> tuple[Any, ...]:
        node = self.parse_primary()
        while True:
            if self.current("("):
                if node[0] != "var" or node[1] != "Boolean":
                    raise ValueError("direct function calls are not allowed")
                self.expect("(")
                arguments: list[tuple[Any, ...]] = []
                if not self.current(")"):
                    arguments.append(self.parse_argument())
                    while self.accept(","):
                        arguments.append(self.parse_argument())
                self.expect(")")
                node = ("function_call", "Boolean", tuple(arguments))
                continue
            optional = bool(self.accept("?."))
            if optional or self.accept("."):
                if self.accept("["):
                    key = self.parse_or()
                    self.expect("]")
                    node = ("get", node, key, optional)
                    continue
                name = self.expect("identifier").value
                if self.accept("("):
                    args: list[tuple[Any, ...]] = []
                    if not self.current(")"):
                        args.append(self.parse_argument())
                        while self.accept(","):
                            args.append(self.parse_argument())
                    self.expect(")")
                    node = ("call", node, name, tuple(args), optional)
                else:
                    node = ("get", node, ("literal", name), optional)
                continue
            if self.accept("["):
                key = self.parse_or()
                self.expect("]")
                node = ("get", node, key, False)
                continue
            break
        return node

    def parse_primary(self) -> tuple[Any, ...]:
        token = self.accept("literal")
        if token:
            return ("literal", token.value)
        token = self.accept("identifier")
        if token:
            return ("var", token.value)
        token = self.accept("placeholder")
        if token:
            return ("placeholder", token.value)
        if self.accept("["):
            items: list[tuple[Any, ...]] = []
            if not self.current("]"):
                items.append(self.parse_or())
                while self.accept(","):
                    items.append(self.parse_or())
            self.expect("]")
            return ("array", tuple(items))
        if self.accept("("):
            node = self.parse_or()
            self.expect(")")
            return node
        raise ValueError(f"expected expression, got {self.tokens[self.index].kind!r}")


def _truthy(value: Any) -> bool:
    if value is None or value is False:
        return False
    if isinstance(value, (int, float)):
        return value != 0 and not (isinstance(value, float) and math.isnan(value))
    if isinstance(value, str):
        return bool(value)
    return True


def _get(value: Any, key: Any) -> Any:
    if value is None:
        return None
    if key == "length" and isinstance(value, (str, list, tuple, dict)):
        return len(value)
    if isinstance(value, Mapping):
        return value.get(str(key))
    if isinstance(value, (list, tuple)) and isinstance(key, (int, float)):
        index = int(key)
        return value[index] if 0 <= index < len(value) else None
    return getattr(value, str(key), None)


def _placeholder(raw: str, context: Mapping[str, Any]) -> Any:
    path, separator, default = raw.partition("|")
    value: Any = context
    for component in re.findall(r"[A-Za-z_$][A-Za-z0-9_$]*|\d+", path):
        value = _get(value, int(component) if component.isdigit() else component)
        if value is None:
            break
    if value is not None or not separator:
        return value
    try:
        return json.loads(default)
    except json.JSONDecodeError:
        return default


_ALLOWED_METHODS = {"includes", "startsWith", "find", "filter", "some", "reduce"}


def _evaluate(node: tuple[Any, ...], context: Mapping[str, Any]) -> Any:
    kind = node[0]
    if kind == "literal":
        return node[1]
    if kind == "var":
        return context.get(node[1])
    if kind == "placeholder":
        return _placeholder(node[1], context)
    if kind == "array":
        return [_evaluate(item, context) for item in node[1]]
    if kind == "get":
        return _get(_evaluate(node[1], context), _evaluate(node[2], context))
    if kind == "unary":
        value = _evaluate(node[2], context)
        return {"!": lambda: not _truthy(value), "+": lambda: +(value or 0), "-": lambda: -(value or 0)}[node[1]]()
    if kind == "binary":
        operator = node[1]
        left = _evaluate(node[2], context)
        if operator == "&&":
            return _evaluate(node[3], context) if _truthy(left) else left
        if operator == "||":
            return left if _truthy(left) else _evaluate(node[3], context)
        if operator == "??":
            return _evaluate(node[3], context) if left is None else left
        right = _evaluate(node[3], context)
        if operator in {"===", "=="}:
            return left == right
        if operator in {"!==", "!="}:
            return left != right
        if operator in {">", ">=", "<", "<="}:
            if left is None or right is None:
                return False
            return {">": left > right, ">=": left >= right, "<": left < right, "<=": left <= right}[operator]
        if operator == "+":
            return (left or 0) + (right or 0)
        if operator == "-":
            return (left or 0) - (right or 0)
        if operator == "*":
            return (left or 0) * (right or 0)
        if operator == "/":
            return (left or 0) / right
        if operator == "%":
            return (left or 0) % right
        raise ValueError(f"unsupported binary operator: {operator}")
    if kind == "lambda":
        return node
    if kind == "call":
        receiver = _evaluate(node[1], context)
        method = node[2]
        if method not in _ALLOWED_METHODS:
            raise ValueError(f"unsupported expression method: {method}")
        arguments = node[3]
        if method == "includes":
            needle = _evaluate(arguments[0], context)
            return False if receiver is None else needle in receiver
        if method == "startsWith":
            prefix = _evaluate(arguments[0], context)
            return isinstance(receiver, str) and receiver.startswith(str(prefix))
        if not isinstance(receiver, (list, tuple)) or not arguments or arguments[0][0] != "lambda":
            return None if method in {"find", "reduce"} else [] if method == "filter" else False
        lambda_node = arguments[0]

        def invoke(*values: Any) -> Any:
            nested = dict(context)
            nested.update(zip(lambda_node[1], values))
            return _evaluate(lambda_node[2], nested)

        if method == "find":
            return next((item for item in receiver if _truthy(invoke(item))), None)
        if method == "filter":
            return [item for item in receiver if _truthy(invoke(item))]
        if method == "some":
            return any(_truthy(invoke(item)) for item in receiver)
        if method == "reduce":
            accumulator = _evaluate(arguments[1], context) if len(arguments) > 1 else None
            items = list(receiver)
            if accumulator is None and items:
                accumulator = items.pop(0)
            for item in items:
                accumulator = invoke(accumulator, item)
            return accumulator
    if kind == "function_call":
        if node[1] != "Boolean" or len(node[2]) != 1:
            raise ValueError("unsupported expression function")
        return _truthy(_evaluate(node[2][0], context))
    raise ValueError(f"unsupported expression node: {kind}")


def compile_expression(source: str) -> tuple[Any, ...]:
    return Parser(source.strip()).parse()


def validate(source: str) -> None:
    compile_expression(source)


def evaluate(source: str, context: Mapping[str, Any]) -> Any:
    return _evaluate(compile_expression(source), context)


def interpolate(source: str, context: Mapping[str, Any]) -> str:
    return re.sub(
        r"\$\{([^}]+)\}",
        lambda match: "" if (value := _placeholder(match.group(1), context)) is None else str(value),
        source,
    )
