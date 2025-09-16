#!/bin/bash
cd "$(dirname "$0")"

# Kill existing process if running
pkill -f "mlx_lm.server.*GLM-4.5-Air-4bit"

# Start in background with nohup
nohup ./run.sh > llm-mlx.log 2>&1 &

echo "LLM-MLX server started in background on port 8080"
echo "View logs with: tail -f llm-mlx.log"
echo "Stop with: ./stop_daemon.sh"
