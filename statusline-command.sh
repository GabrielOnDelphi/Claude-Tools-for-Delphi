#!/usr/bin/env bash
input=$(cat)


# Customized StatusBar. Shows model, effort, context window.
# Example:  "Sonnet 4.6 (thinking: medium) | Context: 3% used (97% remaining) | Tokens: 32000 / 1000000"

# Guard: check jq is available
if ! command -v jq &>/dev/null; then
  printf "Status line error: jq not installed (winget install jqlang.jq)"
  exit 0
fi

used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
api_window=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
window=1000000
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

if [ -z "$used" ]; then
  if [ -n "$effort" ]; then
    printf "%s (thinking: %s) | Context: awaiting first response | Window: %s tokens" "$model" "$effort" "$window"
  else
    printf "%s | Context: awaiting first response | Window: %s tokens" "$model" "$window"
  fi
else
  # Derive actual tokens from API percentage (includes system prompt, tools, cache, etc.)
  total_tokens=$(echo "$used $api_window" | awk '{printf "%d", $1 * $2 / 100}')

  # Recompute percentages against the real 1M window
  used_int=$(echo "$total_tokens $window" | awk '{printf "%d", $1 * 100 / $2}')
  remaining_int=$((100 - used_int))

  if [ "$used_int" -ge 80 ]; then
    color="\033[31m"
  elif [ "$used_int" -ge 50 ]; then
    color="\033[33m"
  else
    color="\033[32m"
  fi
  reset="\033[0m"

  if [ -n "$effort" ]; then
    printf "%s (thinking: %s) | Context: ${color}%s%% used${reset} (%s%% remaining) | Tokens: %s / %s" \
      "$model" \
      "$effort" \
      "$used_int" \
      "$remaining_int" \
      "$total_tokens" \
      "$window"
  else
    printf "%s | Context: ${color}%s%% used${reset} (%s%% remaining) | Tokens: %s / %s" \
      "$model" \
      "$used_int" \
      "$remaining_int" \
      "$total_tokens" \
      "$window"
  fi
fi
