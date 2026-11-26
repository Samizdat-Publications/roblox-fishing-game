"""Read the game's data straight from the Luau source, so the simulation never drifts
from the real numbers. Handles only what the data files use: tables, strings, numbers,
booleans, identifiers, simple arithmetic and Color3.fromRGB(...)."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHARED = ROOT / "src" / "ReplicatedStorage" / "Shared"

TOKEN = re.compile(
    r"""\s*(?:
    (?P<comment>--[^\n]*)
  | (?P<num>\d+\.?\d*(?:e[-+]?\d+)?)
  | (?P<str>"(?:[^"\\]|\\.)*")
  | (?P<name>[A-Za-z_][A-Za-z0-9_.]*)
  | (?P<op>[{}=,()*+/\-])
    )""",
    re.X,
)


def tokenize(src):
    pos = 0
    out = []
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m or m.end() == pos:
            if src[pos:].strip() == "":
                break
            raise ValueError("cannot read Luau near: " + src[pos : pos + 40])
        pos = m.end()
        kind = m.lastgroup
        if kind == "comment":
            continue
        out.append((kind, m.group(kind)))
    return out


class Parser:
    def __init__(self, tokens):
        self.t = tokens
        self.i = 0

    def peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None)

    def take(self, value=None):
        tok = self.t[self.i]
        if value is not None and tok[1] != value:
            raise ValueError(f"expected {value}, got {tok}")
        self.i += 1
        return tok

    def expr(self):
        v = self.term()
        while self.peek()[1] in ("+", "-"):
            op = self.take()[1]
            r = self.term()
            v = v + r if op == "+" else v - r
        return v

    def term(self):
        v = self.atom()
        while self.peek()[1] in ("*", "/"):
            op = self.take()[1]
            r = self.atom()
            v = v * r if op == "*" else v / r
        return v

    def atom(self):
        kind, val = self.peek()
        if val == "{":
            return self.table()
        if val == "-":
            self.take()
            return -self.atom()
        if kind == "num":
            self.take()
            return float(val)
        if kind == "str":
            self.take()
            return val[1:-1]
        if kind == "name":
            self.take()
            if val == "true":
                return True
            if val == "false":
                return False
            if val == "Color3.fromRGB":
                self.take("(")
                rgb = [self.expr()]
                while self.peek()[1] == ",":
                    self.take()
                    rgb.append(self.expr())
                self.take(")")
                return tuple(int(c) for c in rgb)
            return val
        raise ValueError(f"unexpected {kind} {val}")

    def table(self):
        self.take("{")
        arr, rec = [], {}
        while self.peek()[1] != "}":
            if self.peek()[0] == "name" and self.peek(1)[1] == "=":
                key = self.take()[1]
                self.take("=")
                rec[key] = self.expr()
            else:
                arr.append(self.expr())
            if self.peek()[1] == ",":
                self.take()
        self.take("}")
        return arr if arr and not rec else rec if rec else arr


def table_after(path, marker):
    """Parse the table literal that starts at the first '{' after `marker`."""
    src = Path(path).read_text()
    start = src.index("{", src.index(marker) + len(marker))
    depth = 0
    for j in range(start, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return Parser(tokenize(src[start : j + 1])).table()
    raise ValueError("unbalanced table in " + str(path))


def load_config():
    cfg = {}
    for line in (SHARED / "Config.luau").read_text().splitlines():
        m = re.match(r"\s*Config\.(\w+)\s*=\s*([^-\n][^\n]*?)\s*(--.*)?$", line)
        if m:
            raw = m.group(2)
            try:
                cfg[m.group(1)] = Parser(tokenize(raw)).expr()
            except ValueError:
                cfg[m.group(1)] = raw.strip('"')
    return cfg


def load_all():
    return {
        "config": load_config(),
        "fish": table_after(SHARED / "FishData.luau", "local list: { Species } ="),
        "bait": table_after(SHARED / "BaitData.luau", "local list: { Bait } ="),
        "rods": table_after(SHARED / "RodData.luau", "local list: { Rod } ="),
    }


if __name__ == "__main__":
    d = load_all()
    print(len(d["fish"]), "fish,", len(d["bait"]), "baits,", len(d["rods"]), "rods")
    print({k: d["config"][k] for k in ("DAY_LENGTH", "BITE_MIN", "BITE_MAX", "POND_OFFLINE_CAP")})
