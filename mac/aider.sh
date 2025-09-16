#. ./aiguard_setup.sh
#export OPENAI_API_KEY=dummy
#export OPENAI_API_BASE=http://localhost:8080/v1
#export OPENROUTER_API_KEY=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

#aider --no-git --no-auto-commits --no-show-model-warnings --model openai/mlx-community/GLM-4.5-Air-4bit "$@"
#aider --no-git --no-auto-commits --no-show-model-warnings --model openai/mlx-community/Qwen2.5-7B-Instruct-4bit "$@"
#aider --no-auto-commits --no-show-model-warnings --model openrouter/anthropic/claude-3.7-sonnet
#aider --no-git --no-auto-commits --no-show-model-warnings --model openrouter/deepseek/deepseek-chat "$@"
aider --no-git --no-auto-commits --no-show-model-warnings --model openrouter/deepseek/deepseek-chat "$@"

