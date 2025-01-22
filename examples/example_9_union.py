# example_9_union.py
from typing import Union
from dataclasses import dataclass

@dataclass
class DriveCommand:
    speed: float
    direction: float

@dataclass
class StopCommand:
    emergency: bool

Command = Union[DriveCommand, StopCommand]

def handle_command(cmd: Command) -> str:
    if isinstance(cmd, DriveCommand):
        return f"Driving at speed {cmd.speed} in direction {cmd.direction}"
    elif isinstance(cmd, StopCommand):
        stop_type = "emergency" if cmd.emergency else "normal"
        return f"Executing {stop_type} stop"

def demonstrate_union_types():
    # Create and handle different commands
    drive_cmd = DriveCommand(speed=5.0, direction=90.0)
    print("Drive command:", handle_command(drive_cmd))

    emergency_stop = StopCommand(emergency=True)
    print("Emergency stop:", handle_command(emergency_stop))

    normal_stop = StopCommand(emergency=False)
    print("Normal stop:", handle_command(normal_stop))

    # Demonstrate type checking
    commands: list[Command] = [drive_cmd, emergency_stop, normal_stop]
    print("\nProcessing command queue:")
    for cmd in commands:
        print(f"Command type: {type(cmd).__name__}")
        print("Response:", handle_command(cmd))

if __name__ == "__main__":
    demonstrate_union_types()
