import math
import re

FUNCTIONS = {"min": 2, "max": 2, "pow": 2, "sqrt": 1, "exp": 1, "ln": 1, "log10": 1, "abs": 1, "floor": 1, "ceil": 1, "round": 1, "sign": 1, "clamp": 3, "if": 3}
CONSTANTS = {"pi": math.pi, "e": math.e}

NUMBER = re.compile(r"(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?")
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
OPERATOR = re.compile(r"<=|>=|==|!=|[-+*/%^()<>,]")
SPACE = re.compile(r"\s+")
COMPARISONS = ("<", "<=", ">", ">=", "==", "!=")


class FormulaError(Exception):
    def __init__(self, code):
        super().__init__(code)
        self.code = code


def _tokenize(text):
    tokens = []
    position = 0
    while position < len(text):
        match = SPACE.match(text, position)
        if match:
            position = match.end()
            continue
        match = NUMBER.match(text, position)
        if match:
            tokens.append(("num", match.group(0)))
        else:
            match = IDENTIFIER.match(text, position)
            if match:
                tokens.append(("id", match.group(0)))
            else:
                match = OPERATOR.match(text, position)
                if not match:
                    raise FormulaError("SYNTAX")
                tokens.append(("op", match.group(0)))
        position = match.end()
    return tokens


class _Parser:
    def __init__(self, tokens, names):
        self.tokens = tokens
        self.names = names
        self.index = 0

    def _is_op(self, *texts):
        return self.index < len(self.tokens) and self.tokens[self.index][0] == "op" and self.tokens[self.index][1] in texts

    def _next_op(self):
        text = self.tokens[self.index][1]
        self.index += 1
        return text

    def _expect(self, text):
        if not self._is_op(text):
            raise FormulaError("SYNTAX")
        self.index += 1

    def parse(self):
        node = self.comparison()
        if self.index < len(self.tokens):
            raise FormulaError("SYNTAX")
        return node

    def comparison(self):
        left = self.sum()
        while self._is_op(*COMPARISONS):
            op = self._next_op()
            left = ("bin", op, left, self.sum())
        return left

    def sum(self):
        left = self.product()
        while self._is_op("+", "-"):
            op = self._next_op()
            left = ("bin", op, left, self.product())
        return left

    def product(self):
        left = self.unary()
        while self._is_op("*", "/", "%"):
            op = self._next_op()
            left = ("bin", op, left, self.unary())
        return left

    def unary(self):
        if self._is_op("-"):
            self.index += 1
            return ("neg", self.unary())
        if self._is_op("+"):
            self.index += 1
            return self.unary()
        return self.power()

    def power(self):
        base = self.primary()
        if self._is_op("^"):
            self.index += 1
            return ("bin", "^", base, self.unary())
        return base

    def primary(self):
        if self.index >= len(self.tokens):
            raise FormulaError("SYNTAX")
        kind, text = self.tokens[self.index]
        if kind == "num":
            self.index += 1
            return ("num", float(text))
        if kind == "id":
            self.index += 1
            if self._is_op("("):
                return self.call(text)
            if text in CONSTANTS:
                return ("num", CONSTANTS[text])
            if text not in self.names:
                raise FormulaError("UNKNOWN_IDENTIFIER")
            return ("var", text)
        if self._is_op("("):
            self.index += 1
            inner = self.comparison()
            self._expect(")")
            return inner
        raise FormulaError("SYNTAX")

    def call(self, name):
        if name not in FUNCTIONS:
            raise FormulaError("UNKNOWN_FUNCTION")
        self._expect("(")
        args = [self.comparison()]
        while self._is_op(","):
            self.index += 1
            args.append(self.comparison())
        self._expect(")")
        if len(args) != FUNCTIONS[name]:
            raise FormulaError("ARITY")
        return ("call", name, args)


def _power(base, exponent):
    try:
        result = math.pow(base, exponent)
    except OverflowError:
        return math.inf
    except (ValueError, ZeroDivisionError):
        return math.nan
    return result


def _divide(left, right):
    if right == 0:
        return math.nan if left == 0 or math.isnan(left) else math.copysign(math.inf, left) * math.copysign(1, right)
    return left / right


def _modulo(left, right):
    if right == 0 or math.isinf(left):
        return math.nan
    return math.fmod(left, right)


def _log(value, function):
    if value < 0 or math.isnan(value):
        return math.nan
    if value == 0:
        return -math.inf
    return function(value)


def _exp(value):
    try:
        return math.exp(value)
    except OverflowError:
        return math.inf


def _sign(value):
    if math.isnan(value):
        return math.nan
    return float((value > 0) - (value < 0))


def _call(name, a):
    if name == "min":
        return min(a[0], a[1])
    if name == "max":
        return max(a[0], a[1])
    if name == "pow":
        return _power(a[0], a[1])
    if name == "sqrt":
        return math.sqrt(a[0]) if a[0] >= 0 else math.nan
    if name == "exp":
        return _exp(a[0])
    if name == "ln":
        return _log(a[0], math.log)
    if name == "log10":
        return _log(a[0], math.log10)
    if name == "abs":
        return abs(a[0])
    if name in ("floor", "ceil", "round"):
        if not math.isfinite(a[0]):
            return a[0]
        if name == "floor":
            return float(math.floor(a[0]))
        if name == "ceil":
            return float(math.ceil(a[0]))
        return float(math.floor(a[0] + 0.5))
    if name == "sign":
        return _sign(a[0])
    if name == "clamp":
        return min(max(a[0], a[1]), a[2])
    return a[1] if a[0] != 0 else a[2]


def _binary(op, left, right):
    if op == "+":
        return left + right
    if op == "-":
        return left - right
    if op == "*":
        return left * right
    if op == "/":
        return _divide(left, right)
    if op == "%":
        return _modulo(left, right)
    if op == "^":
        return _power(left, right)
    if op == "<":
        return 1.0 if left < right else 0.0
    if op == "<=":
        return 1.0 if left <= right else 0.0
    if op == ">":
        return 1.0 if left > right else 0.0
    if op == ">=":
        return 1.0 if left >= right else 0.0
    if op == "==":
        return 1.0 if left == right else 0.0
    return 1.0 if left != right else 0.0


def _run(node, variables):
    kind = node[0]
    if kind == "num":
        return node[1]
    if kind == "var":
        return float(variables[node[1]])
    if kind == "neg":
        return -_run(node[1], variables)
    if kind == "bin":
        return _binary(node[1], _run(node[2], variables), _run(node[3], variables))
    return _call(node[1], [_run(arg, variables) for arg in node[2]])


def compile_formula(text, names=()):
    if not isinstance(text, str) or text.strip() == "":
        raise FormulaError("EMPTY")
    ast = _Parser(_tokenize(text), set(names)).parse()
    return lambda variables: _run(ast, variables)


def evaluate(text, variables=None):
    variables = variables or {}
    try:
        value = compile_formula(text, variables.keys())(variables)
    except FormulaError as error:
        return {"ok": False, "code": error.code}
    if not math.isfinite(value):
        return {"ok": False, "code": "NOT_FINITE"}
    return {"ok": True, "value": value}
