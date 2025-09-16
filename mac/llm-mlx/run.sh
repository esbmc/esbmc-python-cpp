#!/bin/bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
#mlx_lm.server --model mlx-community/GLM-4.5-Air-4bit --port 8080 --max-tokens 32000 --chat-template-args '{"enable_thinking":true}'
mlx_lm.server --model mlx-community/Qwen2.5-7B-Instruct-4bit --port 8080 --max-tokens 32000 --chat-template-args '{"enable_thinking":true}'
