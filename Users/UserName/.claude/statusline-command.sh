#!/usr/bin/env bash
input=$(cat)

# StatusBar format: Mod: Opus 4.6 | Thinking: on Effort: hi | Context: 3% | 5h_wnd: 61%
# Colors: green/yellow/red for thinking, effort, context, 5h_wnd

if ! command -v jq &>/dev/null; then
  printf "jq not installed"
  exit 0
fi

# Uncomment to debug available JSON fields:
# echo "$input" > ~/statusline-debug.json

# --- Parse ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
quota_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)
thinking_raw=$(jq -r '.alwaysThinkingEnabled // false' ~/.claude/settings.json 2>/dev/null)

# --- ANSI colors ---
green="\033[32m"
yellow="\033[1;33m"
red="\033[31m"
blink_red="\033[1;5;97;41m"
reset="\033[0m"

# --- Thinking: red=on (costly), green=off (cheap) ---
if [ "$thinking_raw" = "true" ]; then
  thinking_str="${red}on${reset}"
else
  thinking_str="${green}off${reset}"
fi

# --- Effort: red=hi (costly), yellow=med, green=lo (cheap) ---
effort_str=""
if [ -n "$effort" ]; then
  case "$effort" in
    hi*) effort_str=" Effort: ${red}${effort}${reset}" ;;
    med*|mid*) effort_str=" Effort: ${yellow}${effort}${reset}" ;;
    lo*) effort_str=" Effort: ${green}${effort}${reset}" ;;
    *) effort_str=" Effort: ${effort}" ;;
  esac
fi

# --- Context: green <50%, yellow 50-80%, red 80%+ ---
context_str=""
if [ -n "$used" ]; then
  used_int=$(echo "$used" | awk '{printf "%d", $1}')
  if [ "$used_int" -ge 80 ]; then
    context_str="${red}${used_int}%${reset}"
  elif [ "$used_int" -ge 50 ]; then
    context_str="${yellow}${used_int}%${reset}"
  else
    context_str="${green}${used_int}%${reset}"
  fi
else
  context_str="..."
fi

# --- 5h_wnd: green <50%, yellow 50-80%, red 80%+, blink 100%+ ---
wnd_str=""
if [ -n "$quota_pct" ]; then
  q_int=$(echo "$quota_pct" | awk '{printf "%d", $1}')
  if [ "$q_int" -ge 100 ]; then
    wnd_str="${blink_red}EXTRA${reset}"
  elif [ "$q_int" -ge 90 ]; then
    wnd_str="${blink_red}${q_int}%${reset}"
  elif [ "$q_int" -ge 80 ]; then
    wnd_str="${red}${q_int}%${reset}"
  elif [ "$q_int" -ge 50 ]; then
    wnd_str="${yellow}${q_int}%${reset}"
  else
    wnd_str="${green}${q_int}%${reset}"
  fi
fi

# --- Build output ---
out="Mod: ${model} | Thinking: ${thinking_str}${effort_str} | Context: ${context_str}"
if [ -n "$wnd_str" ]; then
  out="${out} | 5h_wnd: ${wnd_str}"
fi

echo -ne "$out"
