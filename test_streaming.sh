#!/bin/bash

# Test Anthropic API streaming
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-3-7-sonnet-20250219",
    "max_tokens": 100,
    "stream": true,
    "messages": [
      {"role": "user", "content": "Say hello"}
    ]
  }'
