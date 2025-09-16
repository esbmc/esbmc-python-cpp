from mlx_lm import load, generate

def interactive_chat():
    print("Loading model...")
    model, tokenizer = load("mlx-community/GLM-4.5-Air-4bit")
    print("Model loaded! Type 'quit', 'exit', or 'bye' to end the conversation.\n")

    # Keep track of conversation history
    messages = []

    while True:
        # Get user input
        user_input = input("You: ").strip()

        # Check for exit commands
        if user_input.lower() in ['quit', 'exit', 'bye']:
            print("Goodbye!")
            break

        # Skip empty inputs
        if not user_input:
            continue

        # Add user message to conversation history
        messages.append({"role": "user", "content": user_input})

        # Apply chat template if available
        if tokenizer.chat_template is not None:
            prompt = tokenizer.apply_chat_template(
                messages, add_generation_prompt=True
            )
        else:
            # Fallback if no chat template
            prompt = user_input

        print("Assistant: ", end="", flush=True)

        try:
            # Generate response
            response = generate(
                model,
                tokenizer,
                prompt=prompt,
                verbose=True,  # Shows tokens as they're generated
                max_tokens=32000
            )

            print(response)

            # Add assistant response to conversation history
            messages.append({"role": "assistant", "content": response})

        except KeyboardInterrupt:
            print("\nGeneration interrupted.")
            continue
        except Exception as e:
            print(f"Error generating response: {e}")
            continue

        print()  # Add blank line for readability

if __name__ == "__main__":
    interactive_chat()
