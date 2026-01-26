#!/usr/bin/env python3
"""F' threading-inspired smoke test for Shedskin (no method passing)."""

from typing import Any, Dict, List, Optional


class TaskContext:
    """Deterministic task runner mimicking an F' rate group."""

    def __init__(self, name: str):
        self.name = name
        self._tasks: List[Any] = []
        self._queue: List[Any] = []

    def add_task(self, task: Any):
        self._tasks.append(task)

    def schedule_async(self, task: Any):
        self._queue.append(task)

    def run_once(self):
        for task in self._tasks:
            task.run()
        while self._queue:
            job = self._queue.pop(0)
            job.run()


class AsyncJob:
    def __init__(self, handler: Any, data: Any):
        self.handler = handler
        self.data = data

    def run(self):
        self.handler.handle(self.data)


class InputPort:
    """Simplified F' input port com contexto opcional."""

    def __init__(self, name: str, data_type: str):
        self.name = name
        self.data_type = data_type
        self._handler: Optional[Any] = None
        self._context: Optional[TaskContext] = None

    def register_handler(self, handler: Any, context: Optional[TaskContext] = None):
        self._handler = handler
        self._context = context

    def invoke(self, data: Any):
        if not self._handler:
            return
        if self._context:
            job = AsyncJob(self._handler, data)
            self._context.schedule_async(job)
        else:
            self._handler.handle(data)


class OutputPort:
    """Simplified F' output port that fans out to multiple inputs."""

    def __init__(self, name: str, data_type: str):
        self.name = name
        self.data_type = data_type
        self._connections: List[InputPort] = []

    def connect(self, input_port: InputPort):
        if input_port.data_type == self.data_type:
            self._connections.append(input_port)

    def emit(self, data: Any):
        for connection in self._connections:
            connection.invoke(data)


class CommandMessage:
    def __init__(self, command_id: int, args: Dict[str, int]):
        self.command_id = command_id
        self.args = args


class CommandComponent:
    """Produces command messages for downstream components."""

    def __init__(self):
        self.command_out = OutputPort("command_out", "CommandMessage")

    def issue(self, command_id: int, payload: Dict[str, int]):
        msg = CommandMessage(command_id, payload)
        self.command_out.emit(msg)
        return msg


class TickTask:
    def __init__(self, component: "ExecutionComponent"):
        self.component = component

    def run(self):
        self.component.event_log.append("tick")


class CommandHandler:
    def __init__(self, component: "ExecutionComponent"):
        self.component = component

    def handle(self, message: CommandMessage):
        keys = sorted(list(message.args.keys()))
        parts: List[str] = []
        for key in keys:
            value = message.args[key]
            parts.append(f"{key}={value}")
        description = f"cmd:{message.command_id}|" + ",".join(parts)
        self.component.event_log.append(description)


class ExecutionComponent:
    """Consumes commands and logs execution order."""

    def __init__(self):
        self.command_in = InputPort("command_in", "CommandMessage")
        self.context = TaskContext("exec")
        self.event_log: List[str] = []
        self.tick_task = TickTask(self)
        self.handler = CommandHandler(self)
        self.context.add_task(self.tick_task)

    def register(self):
        self.command_in.register_handler(self.handler, self.context)


def run_smoke() -> List[str]:
    commander = CommandComponent()
    executor = ExecutionComponent()
    executor.register()
    commander.command_out.connect(executor.command_in)

    # Set operations exercise the runtime helpers
    targets = set(["nav", "nav", "science"])
    assert len(targets) == 2
    targets.discard("nav")
    assert "nav" not in targets

    commander.issue(1, {"speed": 3, "heading": 90})
    executor.context.run_once()

    commander.issue(2, {"speed": 1})
    commander.issue(3, {"speed": 2})
    executor.context.run_once()

    expected = [
        "tick",
        "cmd:1|heading=90,speed=3",
        "tick",
        "cmd:2|speed=1",
        "cmd:3|speed=2",
    ]
    assert executor.event_log == expected
    return executor.event_log


if __name__ == "__main__":
    log = run_smoke()
    print("F' threading smoke log:", log)
