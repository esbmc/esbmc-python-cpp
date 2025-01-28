from multiprocessing import Process, Event
from typing import Dict, List
from enum import Enum
import time
import os
import zmq
import signal

class PortType(Enum):
    COMMAND = "command"
    TELEMETRY = "telemetry"
    EVENT = "event"
    PARAMETER = "parameter"
    SERIAL = "serial"

class ComponentProcess:
    def __init__(self, name: str, port_config: dict):
        self.name = name
        self.port_config = port_config
        self.process = None
        self.stop_event = Event()

    def _initialize_zmq(self):
        """Initialize ZMQ context and sockets within the process"""
        self.context = zmq.Context()
        self.sockets = {}

        for port_name, config in self.port_config.items():
            if config['direction'] == 'in':
                socket = self.context.socket(zmq.PULL)
                socket.bind(f"tcp://127.0.0.1:{config['port']}")
            else:
                socket = self.context.socket(zmq.PUSH)
                socket.connect(f"tcp://127.0.0.1:{config['target_port']}")
            self.sockets[port_name] = socket

    def _cleanup_zmq(self):
        """Cleanup ZMQ resources"""
        for socket in self.sockets.values():
            socket.close()
        self.context.term()

    def _run(self):
        """Process main loop - implemented by subclasses"""
        self._initialize_zmq()
        try:
            while not self.stop_event.is_set():
                self._process_loop()
        finally:
            self._cleanup_zmq()

    def _process_loop(self):
        """Main processing loop - override in subclasses"""
        time.sleep(0.1)

    def start(self):
        """Start the component process"""
        self.process = Process(target=self._run)
        self.process.start()

    def stop(self):
        """Stop the component process"""
        if self.process:
            self.stop_event.set()
            self.process.join(timeout=1)
            if self.process.is_alive():
                self.process.terminate()

class SensorComponent(ComponentProcess):
    def __init__(self):
        port_config = {
            'sensor_data': {
                'direction': 'out',
                'type': PortType.TELEMETRY,
                'target_port': 5555
            }
        }
        super().__init__("sensor", port_config)
        self.reading = 0

    def _process_loop(self):
        message = {
            'timestamp': time.time(),
            'value': self.reading,
            'unit': 'celsius'
        }
        self.sockets['sensor_data'].send_json(message)
        print(f"Sensor (PID: {os.getpid()}) sent reading: {self.reading}")
        self.reading += 1
        time.sleep(1)

class ControllerComponent(ComponentProcess):
    def __init__(self):
        port_config = {
            'sensor_input': {
                'direction': 'in',
                'type': PortType.TELEMETRY,
                'port': 5555
            },
            'command': {
                'direction': 'out',
                'type': PortType.COMMAND,
                'target_port': 5556
            }
        }
        super().__init__("controller", port_config)

    def _process_loop(self):
        try:
            message = self.sockets['sensor_input'].recv_json(flags=zmq.NOBLOCK)
            print(f"Controller (PID: {os.getpid()}) received: {message}")

            # Process sensor data and generate command
            command = {
                'timestamp': time.time(),
                'action': 'ADJUST',
                'parameters': {'value': message['value'] * 2}
            }
            self.sockets['command'].send_json(command)
        except zmq.Again:
            # No message available
            time.sleep(0.1)

class ActuatorComponent(ComponentProcess):
    def __init__(self):
        port_config = {
            'command_input': {
                'direction': 'in',
                'type': PortType.COMMAND,
                'port': 5556
            }
        }
        super().__init__("actuator", port_config)

    def _process_loop(self):
        try:
            message = self.sockets['command_input'].recv_json(flags=zmq.NOBLOCK)
            print(f"Actuator (PID: {os.getpid()}) executing command: {message}")
        except zmq.Again:
            # No message available
            time.sleep(0.1)

class FPrimeTopology:
    def __init__(self):
        self.components = {}

    def add_component(self, component: ComponentProcess):
        self.components[component.name] = component

    def start(self):
        """Start all components"""
        for component in self.components.values():
            component.start()

    def stop(self):
        """Stop all components"""
        for component in self.components.values():
            component.stop()

def main():
    # Handle Ctrl+C gracefully
    def signal_handler(signum, frame):
        print("\nShutting down...")
        topology.stop()
        exit(0)

    signal.signal(signal.SIGINT, signal_handler)

    # Create topology
    topology = FPrimeTopology()

    # Create components
    sensor = SensorComponent()
    controller = ControllerComponent()
    actuator = ActuatorComponent()

    # Add components to topology
    topology.add_component(sensor)
    topology.add_component(controller)
    topology.add_component(actuator)

    try:
        # Start the system
        topology.start()

        # Keep main process running
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print("\nShutting down...")
    finally:
        # Clean shutdown
        topology.stop()

if __name__ == "__main__":
    main()
