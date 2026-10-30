export const FUNCTIONS = { min: 2, max: 2, pow: 2, sqrt: 1, exp: 1, ln: 1, log10: 1, abs: 1, floor: 1, ceil: 1, round: 1, sign: 1, clamp: 3, if: 3 };
export const CONSTANTS = { pi: Math.PI, e: Math.E };

const NUMBER = /^(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?/;
const IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*/;
const OPERATOR = /^(?:<=|>=|==|!=|[-+*/%^()<>,])/;

class FormulaError extends Error {
  constructor(code) {
    super(code);
    this.code = code;
  }
}

function tokenize(text) {
  const tokens = [];
  let rest = text;
  while (rest.length > 0) {
    const space = rest.match(/^\s+/);
    if (space) {
      rest = rest.slice(space[0].length);
      continue;
    }
    let match = rest.match(NUMBER);
    if (match) tokens.push({ type: "num", text: match[0], value: Number(match[0]) });
    else if ((match = rest.match(IDENTIFIER))) tokens.push({ type: "id", text: match[0] });
    else if ((match = rest.match(OPERATOR))) tokens.push({ type: "op", text: match[0] });
    else throw new FormulaError("SYNTAX");
    rest = rest.slice(match[0].length);
  }
  return tokens;
}

function parseTokens(tokens, names) {
  let index = 0;
  const peek = () => tokens[index];
  const isOp = (text) => peek()?.type === "op" && peek().text === text;
  const expect = (text) => {
    if (!isOp(text)) throw new FormulaError("SYNTAX");
    index += 1;
  };

  function comparison() {
    let left = sum();
    while (peek()?.type === "op" && ["<", "<=", ">", ">=", "==", "!="].includes(peek().text)) {
      const op = tokens[index].text;
      index += 1;
      left = { t: "bin", op, l: left, r: sum() };
    }
    return left;
  }

  function sum() {
    let left = product();
    while (isOp("+") || isOp("-")) {
      const op = tokens[index].text;
      index += 1;
      left = { t: "bin", op, l: left, r: product() };
    }
    return left;
  }

  function product() {
    let left = unary();
    while (isOp("*") || isOp("/") || isOp("%")) {
      const op = tokens[index].text;
      index += 1;
      left = { t: "bin", op, l: left, r: unary() };
    }
    return left;
  }

  function unary() {
    if (isOp("-")) {
      index += 1;
      return { t: "neg", x: unary() };
    }
    if (isOp("+")) {
      index += 1;
      return unary();
    }
    return power();
  }

  function power() {
    const base = primary();
    if (isOp("^")) {
      index += 1;
      return { t: "bin", op: "^", l: base, r: unary() };
    }
    return base;
  }

  function primary() {
    const token = peek();
    if (!token) throw new FormulaError("SYNTAX");
    if (token.type === "num") {
      index += 1;
      return { t: "num", v: token.value };
    }
    if (token.type === "id") {
      index += 1;
      if (isOp("(")) return call(token.text);
      if (token.text in CONSTANTS) return { t: "num", v: CONSTANTS[token.text] };
      if (!names.includes(token.text)) throw new FormulaError("UNKNOWN_IDENTIFIER");
      return { t: "var", name: token.text };
    }
    if (isOp("(")) {
      index += 1;
      const inner = comparison();
      expect(")");
      return inner;
    }
    throw new FormulaError("SYNTAX");
  }

  function call(name) {
    if (!(name in FUNCTIONS)) throw new FormulaError("UNKNOWN_FUNCTION");
    expect("(");
    const args = [comparison()];
    while (isOp(",")) {
      index += 1;
      args.push(comparison());
    }
    expect(")");
    if (args.length !== FUNCTIONS[name]) throw new FormulaError("ARITY");
    return { t: "call", name, args };
  }

  const ast = comparison();
  if (index < tokens.length) throw new FormulaError("SYNTAX");
  return ast;
}

function applyCall(name, a) {
  switch (name) {
    case "min": return Math.min(a[0], a[1]);
    case "max": return Math.max(a[0], a[1]);
    case "pow": return Math.pow(a[0], a[1]);
    case "sqrt": return Math.sqrt(a[0]);
    case "exp": return Math.exp(a[0]);
    case "ln": return Math.log(a[0]);
    case "log10": return Math.log10(a[0]);
    case "abs": return Math.abs(a[0]);
    case "floor": return Math.floor(a[0]);
    case "ceil": return Math.ceil(a[0]);
    case "round": return Math.floor(a[0] + 0.5);
    case "sign": return Math.sign(a[0]) + 0;
    case "clamp": return Math.min(Math.max(a[0], a[1]), a[2]);
    default: return a[0] !== 0 ? a[1] : a[2];
  }
}

function applyBinary(op, l, r) {
  switch (op) {
    case "+": return l + r;
    case "-": return l - r;
    case "*": return l * r;
    case "/": return l / r;
    case "%": return l % r;
    case "^": return Math.pow(l, r);
    case "<": return l < r ? 1 : 0;
    case "<=": return l <= r ? 1 : 0;
    case ">": return l > r ? 1 : 0;
    case ">=": return l >= r ? 1 : 0;
    case "==": return l === r ? 1 : 0;
    default: return l !== r ? 1 : 0;
  }
}

function run(node, vars) {
  switch (node.t) {
    case "num": return node.v;
    case "var": return vars[node.name];
    case "neg": return -run(node.x, vars);
    case "bin": return applyBinary(node.op, run(node.l, vars), run(node.r, vars));
    default: return applyCall(node.name, node.args.map((arg) => run(arg, vars)));
  }
}

const cache = new Map();

export function compile(text, names = []) {
  const key = names.join(",") + "|" + text;
  if (cache.has(key)) return cache.get(key);
  let result;
  try {
    if (String(text).trim() === "") throw new FormulaError("EMPTY");
    const ast = parseTokens(tokenize(String(text)), names);
    result = { ok: true, run: (vars) => run(ast, vars) };
  } catch (error) {
    if (!(error instanceof FormulaError)) throw error;
    result = { ok: false, code: error.code };
  }
  if (cache.size > 500) cache.clear();
  cache.set(key, result);
  return result;
}

export function evaluate(text, vars = {}) {
  const compiled = compile(text, Object.keys(vars));
  if (!compiled.ok) return { ok: false, code: compiled.code };
  const value = compiled.run(vars);
  return Number.isFinite(value) ? { ok: true, value } : { ok: false, code: "NOT_FINITE" };
}
