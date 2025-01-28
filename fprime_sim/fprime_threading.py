from typing import Dict, Any, Callable, List, Optional
from dataclasses import dataclass
from queue import Queue
import threading
import time
import json

class TaskContext:
    """Represents an F' rate group context"""
    def __init__(self, name: str, rate_hz: float):
        self.name = name
        self.period = 1.0 / rate_hz
        self.tasks: List[Callable] = []
        self._queue: Queue = Queue()
        self._thread: Optional[threading.Thread] = None
        self.running = False

    def start(self):
        self.running = True
        self._thread = threading.Thread(target=self._run)
        self._thread.start()

    def stop(self):
        self.running = False
        if self._thread:
            self._thread.join()

    def add_task(self, task: Callable):
        self.tasks.append(task)

    def _run(self):
        while self.running:
            start_time = time.time()

            # Execute all tasks in this context
            for task in self.tasks:
                # In F', tasks are actually queued to thread pools
                # Here we simplify by executing directly
                task()

            # Process any async calls that came in
            while not self._queue.empty():
                task = self._queue.get()
                task()

            # Sleep for remaining time in period
            elapsed = time.time() - start_time
            if elapsed < self.period:
                time.sleep(self.period - elapsed)

    def schedule_async(self, task: Callable):
        """Schedule an async task in this context"""
        self._queue.put(task)

@dataclass
class Port:
    """Base class for F' ports"""
    name: str
    data_type: str
    direction: str  # "input" or "output"

@dataclass
class InputPort(Port):
    """Input port implementation"""
    def __init__(self, name: str, data_type: str):
        super().__init__(name, data_type, "input")
        self.handler: Callable = None
        self.context: Optional[TaskContext] = None

    def register_handler(self, handler: Callable, context: TaskContext = None):
        """Register handler with optional execution context"""
        self.handler = handler
        self.context = context

    def invoke(self, data: Any):
        """Invoke handler in appropriate context"""
        if not self.handler:
            return

        if self.context:
            # Schedule in specific context
            self.context.schedule_async(lambda: self.handler(data))
        else:
            # Execute in caller's context
            self.handler(data)

@dataclass
class OutputPort(Port):
    """Output port implementation"""
    def __init__(self, name: str, data_type: str):
        super().__init__(name, data_type, "output")
        self.connections: List[InputPort] = []

    def connect(self, input_port: InputPort):
        if input_port.data_type == self.data_type:
            self.connections.append(input_port)

    def emit(self, data: Any):
        for connection in self.connections:
            connection.invoke(data)

class Component:
    """Base class for F' components"""
    def __init__(self, name: str):
        self.name = name
        self.input_ports: Dict[str, InputPort] = {}
        self.output_ports: Dict[str, OutputPort] = {}
        self.contexts: Dict[str, TaskContext] = {}

    def add_input_port(self, name: str, data_type: str) -> InputPort:
        port = InputPort(name, data_type)
        self.input_ports[name] = port
        return port

    def add_output_port(self, name: str, data_type: str) -> OutputPort:
        port = OutputPort(name, data_type)
        self.output_ports[name] = port
        return port

    def add_rate_group(self, name: str, rate_hz: float) -> TaskContext:
        """Add a rate group context to this component"""
        context = TaskContext(name, rate_hz)
        self.contexts[name] = context
        return context

class Assembly:
    """F' assembly that manages components and connections"""
    def __init__(self):
        self.components: Dict[str, Component] = {}

    def add_component(self, component: Component):
        self.components[component.name] = component

    def connect_ports(self,
                     from_component: str, from_port: str,
                     to_component: str, to_port: str):
        output_port = self.components[from_component].output_ports[from_port]
        input_port = self.components[to_component].input_ports[to_port]
        output_port.connect(input_port)

    def start(self):
        """Start all rate groups in all components"""
        for component in self.components.values():
            for context in component.contexts.values():
                context.start()

    def stop(self):
        """Stop all rate groups in all components"""
        for component in self.components.values():
            for context in component.contexts.values():
                context.stop()

# Example Implementation

@dataclass
class CommandMessage:
    """Example command message type"""
    command_id: int
    args: Dict[str, Any]

@dataclass
class TelemetryMessage:
    """Example telemetry message type"""
    channel_id: int
    value: Any
    timestamp: float

class ExampleComponent(Component):
    """Example component with rate groups"""
    def __init__(self):
        super().__init__("ExampleComponent")

        # Add ports
        self.cmd_in = self.add_input_port("CmdIn", "CommandMessage")
        self.tlm_out = self.add_output_port("TlmOut", "TelemetryMessage")

        # Create rate groups
        self.fast_context = self.add_rate_group("1Hz", 1.0)
        self.slow_context = self.add_rate_group("0.1Hz", 0.1)

        # Register handlers in specific contexts
        self.cmd_in.register_handler(
            self._handle_command,
            self.fast_context
        )

        # Add periodic tasks
        self.fast_context.add_task(self._fast_task)
        self.slow_context.add_task(self._slow_task)

    def _handle_command(self, cmd: CommandMessage):
        print(f"Handling command {cmd.command_id} in fast context")

    def _fast_task(self):
        """Task that runs at 1Hz"""
        telemetry = TelemetryMessage(
            channel_id=1,
            value=time.time(),
            timestamp=time.time()
        )
        self.tlm_out.emit(telemetry)

    def _slow_task(self):
        """Task that runs at 0.1Hz"""
        print("Slow task executing...")

def main():
    # Create assembly
    assembly = Assembly()

    # Create and add component
    example_comp = ExampleComponent()
    assembly.add_component(example_comp)

    # Start assembly
    assembly.start()

    try:
        # Send some commands
        for i in range(5):
            example_comp.cmd_in.invoke(
                CommandMessage(i, {"param": f"value{i}"})
            )
            time.sleep(1.0)

    finally:
        assembly.stop()

if __name__ == "__main__":
    main()
