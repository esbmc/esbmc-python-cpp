#!/usr/bin/env python3
"""
Interactive chat interface for GLM-4.5-Air-4bit using MLX
"""

import mlx.core as mx
from mlx_lm import load, generate
import readline
import sys
from typing import List, Dict

class GLMChat:
    def __init__(self, model_path: str = "mlx-community/GLM-4.5-Air-4bit"):
        """Initialize the GLM chat interface"""
        print("Loading model... This may take a moment.")
        self.model, self.tokenizer = load(model_path)
        print(f"Model loaded: {model_path}")

        # Chat history for context
        self.conversation_history: List[Dict[str, str]] = []

        # Generation parameters - using minimal set for compatibility
        self.gen_params = {
            'max_tokens': 512,  # Conservative token limit
        }

    def format_chat_prompt(self, user_input: str) -> str:
        """Format the conversation history into a prompt for GLM"""
        # GLM-4 uses a specific chat format
        prompt = ""

        # Add conversation history
        for msg in self.conversation_history:
            if msg['role'] == 'user':
                prompt += f"[gMASK]<sop><|user|>\n{msg['content']}<|assistant|>\n"
            else:
                prompt += f"{msg['content']}\n"

        # Add current user input
        if self.conversation_history:
            prompt += f"<|user|>\n{user_input}<|assistant|>\n"
        else:
            prompt = f"[gMASK]<sop><|user|>\n{user_input}<|assistant|>\n"

        return prompt

    def generate_response(self, user_input: str) -> str:
        """Generate a response using the GLM model"""
        try:
            # Format the prompt
            formatted_prompt = self.format_chat_prompt(user_input)

            # Generate response with minimal parameters for compatibility
            response = generate(
                self.model,
                self.tokenizer,
                prompt=formatted_prompt,
                max_tokens=512
            )

            # Extract just the new response (remove the prompt)
            if formatted_prompt in response:
                new_response = response[len(formatted_prompt):].strip()
            else:
                new_response = response.strip()

            # Clean up any special tokens that might appear
            new_response = new_response.replace('<|user|>', '').replace('<|assistant|>', '')
            new_response = new_response.replace('[gMASK]', '').replace('<sop>', '')

            return new_response.strip()

        except Exception as e:
            return f"Error generating response: {str(e)}"

    def update_conversation(self, user_input: str, assistant_response: str):
        """Update the conversation history"""
        self.conversation_history.append({"role": "user", "content": user_input})
        self.conversation_history.append({"role": "assistant", "content": assistant_response})

        # Keep conversation history manageable (last 10 exchanges)
        if len(self.conversation_history) > 20:
            self.conversation_history = self.conversation_history[-20:]

    def clear_history(self):
        """Clear conversation history"""
        self.conversation_history = []
        print("Conversation history cleared.")

    def set_temperature(self, temp: float):
        """Temperature adjustment not available in this MLX version"""
        print("Temperature adjustment not supported in this MLX version")

    def show_settings(self):
        """Display current generation settings"""
        print("\nCurrent settings:")
        for key, value in self.gen_params.items():
            print(f"  {key}: {value}")
        print(f"Conversation length: {len(self.conversation_history)} messages")

    def interactive_chat(self):
        """Main interactive chat loop"""
        print("\n" + "="*60)
        print("GLM-4.5-Air Interactive Chat")
        print("="*60)
        print("Commands:")
        print("  /clear    - Clear conversation history")
        print("  /settings - Show current settings")
        print("  /quit     - Exit chat")
        print("  /help     - Show this help")
        print("="*60 + "\n")

        while True:
            try:
                # Get user input
                user_input = input("\n🧑 You: ").strip()

                if not user_input:
                    continue

                # Handle commands
                if user_input.startswith('/'):
                    if user_input.lower() in ['/quit', '/exit', '/q']:
                        print("Goodbye! 👋")
                        break
                    elif user_input.lower() == '/clear':
                        self.clear_history()
                        continue
                    elif user_input.lower() == '/settings':
                        self.show_settings()
                        continue
                    elif user_input.lower() == '/help':
                        print("\nCommands:")
                        print("  /clear    - Clear conversation history")
                        print("  /settings - Show current settings")
                        print("  /quit     - Exit chat")
                        continue
                    else:
                        print("Unknown command. Type /help for available commands.")
                        continue

                # Generate response
                print("🤖 GLM: ", end="", flush=True)
                response = self.generate_response(user_input)
                print(response)

                # Update conversation history
                self.update_conversation(user_input, response)

            except KeyboardInterrupt:
                print("\n\nGoodbye! 👋")
                break
            except Exception as e:
                print(f"\nError: {e}")
                print("Continuing chat...")


def main():
    """Main function"""
    try:
        # Initialize chat
        chat = GLMChat()

        # Start interactive chat
        chat.interactive_chat()

    except Exception as e:
        print(f"Failed to initialize chat: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
