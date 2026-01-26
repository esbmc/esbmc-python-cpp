#!/usr/bin/env python3
"""Utility to massage Python files into a Shedskin-friendly subset."""

import argparse
import ast
import copy


def is_dataclass_decorator(dec):
    if isinstance(dec, ast.Name):
        return dec.id == "dataclass"
    if isinstance(dec, ast.Attribute):
        return dec.attr == "dataclass"
    return False


def is_enum_base(base):
    if isinstance(base, ast.Name):
        return base.id == "Enum"
    if isinstance(base, ast.Attribute):
        return base.attr == "Enum"
    return False


class DataclassTransformer(ast.NodeTransformer):
    def visit_ClassDef(self, node):  # noqa: N802
        node = self.generic_visit(node)
        has_dataclass = any(is_dataclass_decorator(d) for d in node.decorator_list)
        node.decorator_list = [d for d in node.decorator_list if not is_dataclass_decorator(d)]

        has_enum = any(is_enum_base(base) for base in node.bases)
        if has_enum:
            node.bases = []

        if has_dataclass:
            if not any(isinstance(stmt, ast.FunctionDef) and stmt.name == "__init__" for stmt in node.body):
                node.body.insert(0, self._build_init(node))
        return node

    def _build_init(self, node):
        fields = []
        for stmt in node.body:
            if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
                fields.append((stmt.target.id, stmt.value))

        args = [ast.arg(arg="self")]
        defaults = []
        for name, default in fields:
            args.append(ast.arg(arg=name))
            defaults.append(default if default is not None else ast.Constant(value=None))

        init_body = []
        for name, _ in fields:
            assign = ast.Assign(
                targets=[ast.Attribute(value=ast.Name(id="self", ctx=ast.Load()), attr=name, ctx=ast.Store())],
                value=ast.Name(id=name, ctx=ast.Load()),
            )
            init_body.append(assign)
        if not init_body:
            init_body.append(ast.Pass())

        init_func = ast.FunctionDef(
            name="__init__",
            args=ast.arguments(
                posonlyargs=[],
                args=args,
                vararg=None,
                kwonlyargs=[],
                kw_defaults=[],
                kwarg=None,
                defaults=defaults,
            ),
            body=init_body,
            decorator_list=[],
            returns=None,
        )
        return init_func


class LambdaLifter(ast.NodeTransformer):
    def __init__(self):
        self.counter = 0
        self.new_funcs = []

    def visit_Module(self, node):  # noqa: N802
        node = self.generic_visit(node)
        node.body.extend(self.new_funcs)
        return node

    def visit_Lambda(self, node):  # noqa: N802
        name = f"__shedskin_lambda_{self.counter}"
        self.counter += 1
        func_def = ast.FunctionDef(
            name=name,
            args=copy.deepcopy(node.args),
            body=[ast.Return(value=self.visit(node.body))],
            decorator_list=[],
            returns=None,
        )
        ast.fix_missing_locations(func_def)
        self.new_funcs.append(func_def)
        return ast.Name(id=name, ctx=ast.Load())


class AttrCallRewriter(ast.NodeTransformer):
    def __init__(self):
        self.need_has = False
        self.need_set = False

    def visit_Module(self, node):  # noqa: N802
        node = self.generic_visit(node)
        helpers = []
        if self.need_has:
            helpers.append(self._make_has_helper())
        if self.need_set:
            helpers.append(self._make_set_helper())
        node.body = helpers + node.body
        return node

    def visit_Call(self, node):  # noqa: N802
        node = self.generic_visit(node)
        if isinstance(node.func, ast.Name):
            if node.func.id == "hasattr" and len(node.args) == 2:
                self.need_has = True
                node.func = ast.Name(id="__shedskin_hasattr", ctx=ast.Load())
            elif node.func.id == "setattr" and len(node.args) == 3:
                self.need_set = True
                node.func = ast.Name(id="__shedskin_setattr", ctx=ast.Load())
        return node

    def _make_has_helper(self):
        obj = ast.Name(id="obj", ctx=ast.Load())
        attr = ast.Name(id="name", ctx=ast.Load())
        body = [
            ast.Return(
                value=ast.Compare(
                    left=attr,
                    ops=[ast.In()],
                    comparators=[ast.Attribute(value=obj, attr="__dict__", ctx=ast.Load())],
                )
            )
        ]
        helper = ast.FunctionDef(
            name="__shedskin_hasattr",
            args=ast.arguments(
                posonlyargs=[],
                args=[ast.arg(arg="obj"), ast.arg(arg="name")],
                vararg=None,
                kwonlyargs=[],
                kw_defaults=[],
                kwarg=None,
                defaults=[],
            ),
            body=body,
            decorator_list=[],
            returns=None,
        )
        return helper

    def _make_set_helper(self):
        obj = ast.Name(id="obj", ctx=ast.Load())
        attr = ast.Name(id="name", ctx=ast.Load())
        value = ast.Name(id="value", ctx=ast.Load())
        assign = ast.Assign(
            targets=[ast.Subscript(value=ast.Attribute(value=obj, attr="__dict__", ctx=ast.Load()), slice=attr, ctx=ast.Store())],
            value=value,
        )
        helper = ast.FunctionDef(
            name="__shedskin_setattr",
            args=ast.arguments(
                posonlyargs=[],
                args=[ast.arg(arg="obj"), ast.arg(arg="name"), ast.arg(arg="value")],
                vararg=None,
                kwonlyargs=[],
                kw_defaults=[],
                kwarg=None,
                defaults=[],
            ),
            body=[assign, ast.Return(value=ast.Constant(value=None))],
            decorator_list=[],
            returns=None,
        )
        return helper


def transform_source(source: str) -> str:
    tree = ast.parse(source)
    tree = AttrCallRewriter().visit(tree)
    tree = LambdaLifter().visit(tree)
    tree = DataclassTransformer().visit(tree)
    ast.fix_missing_locations(tree)
    return ast.unparse(tree)


def main():
    parser = argparse.ArgumentParser(description="Prepare Python file for Shedskin")
    parser.add_argument("input", help="Input Python file")
    parser.add_argument("output", help="Output Python file")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        src = f.read()

    transformed = transform_source(src)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(transformed)


if __name__ == "__main__":
    main()
