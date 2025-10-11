#!/usr/bin/env bash
set -euo pipefail

# =================== Color & UI ===================
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RESET=$'\e[0m'; BOLD=$'\e[1m'; DIM=$'\e[2m'
  C_CYAN=$'\e[38;5;44m'; C_BLUE=$'\e[38;5;33m'
  C_GREEN=$'\e[38;5;46m'; C_YEL=$'\e[38;5;226m'
  C_ORG=$'\e[38;5;214m'; C_PINK=$'\e[38;5;205m'
  C_GREY=$'\e[38;5;245m'; C_RED=$'\e[38;5;196m'
  C_PURPLE=$'\e[38;5;99m'; C_TEAL=$'\e[38;5;81m'
else
  RESET= BOLD= DIM= C_CYAN= C_BLUE= C_GREEN= C_YEL= C_ORG= C_PINK= C_GREY= C_RED= C_PURPLE= C_TEAL=
fi

hr(){ printf "${C_ORG}%s${RESET}\n" "═══════════════════════════════════════════════════════════════"; }
sec(){ printf "\n${C_BLUE}📦 ${BOLD}%s${RESET}\n" "$1"; hr; }
ok(){ printf "${C_GREEN}✔ ${RESET}${BOLD}%s${RESET}\n" "$1"; }
warn(){ printf "${C_ORG}⚠ ${RESET}${BOLD}%s${RESET}\n" "$1"; }
err(){ printf "${C_RED}✘ ${RESET}${BOLD}%s${RESET}\n" "$1"; }
kv(){ printf "   ${C_GREY}${BOLD}%s:${RESET} ${C_TEAL}%s${RESET}\n" "$1" "$2"; }

printf "\n${C_CYAN}${BOLD}🚀 V2Ray Cloud Run — One-Click Deploy${RESET} ${C_YEL}(Trojan / VLESS / gRPC)${RESET}\n"
hr

# =================== Secrets via ENV / .env ===================
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [[ -f .env ]]; then
  # Only fill missing values from .env
  # shellcheck disable=SC1091
  set -a; source ./.env; set +a
  # re-take with fallback but keep inline if already set
  TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-${TELEGRAM_TOKEN}}"
  TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-${TELEGRAM_CHAT_ID}}"
  ok ".env loaded (only for missing vars)"
fi

# =================== Protocol ===================
sec "Protocol"
printf "   ${C_YEL}1) Trojan (WS)     2) VLESS (WS)     3) VLESS (gRPC)${RESET}\n"
echo
read -rp "   Choose [${C_GREEN}default 2]: " _opt || true
case "${_opt:-2}" in
  1) PROTO="trojan"    ;;
  2) PROTO="vless"     ;;
  3) PROTO="vlessgrpc" ;;
  *) PROTO="vless"     ;;
esac
ok "Selected ${PROTO^^}"

# =================== Region chooser ===================
sec "Region"
printf "   1)  🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${C_GREEN}[default]${RESET}\n"
printf "   2)  🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)\n"
printf "   3)  🇺🇸 us-south1 (Dallas, Texas, North America)\n"
printf "   4)  🇺🇸 southamerica-west1 (Santiago, Chile, South America)\n"
printf "   5)  🇺🇸 us-west1 (The Dalles, Oregon, North America)\n"
printf "   6)  🇨🇦 northamerica-northeast2 (Toronto, Ontario, North America)\n"
printf "   7)  🇸🇬 asia-southeast1 (Jurong West, Singapore)\n"
printf "   8)  🇯🇵 asia-northeast1 (Tokyo, Japan)\n"
printf "   9)  🇹🇼 asia-east1 (Changhua County, Taiwan)\n"
printf "   10) 🇭🇰 asia-east2 (Hong Kong)\n"
printf "   11) 🇮🇳 asia-south1 (Mumbai, India)\n"
printf "   12) 🇮🇩 asia-southeast2 (Jakarta, Indonesia)\n"
echo
read -rp "   Choose [1-12, default 1]: " _r || true
case "${_r:-1}" in
  2) REGION="us-east1" ;;
  3) REGION="us-south1" ;;   
  4) REGION="southamerica-west1" ;;
  5) REGION="us-west1" ;;
  6) REGION="northamerica-northeast2" ;;
  7) REGION="asia-southeast1" ;;
  8) REGION="asia-northeast1" ;;
  9) REGION="asia-east1" ;;
  10) REGION="asia-east2" ;;
  11) REGION="asia-south1" ;;
  12) REGION="asia-southeast2" ;;
  *) REGION="us-central1" ;;
esac
ok "Region: ${REGION}"

# =================== CPU chooser ===================
sec "CPU (vCPU)"
printf "   1) 1 vCPU\n"
printf "   2) 2 vCPU ${C_GREEN}[default]${RESET}\n"
printf "   3) 4 vCPU\n"
printf "   4) 6 vCPU\n"
printf "   5) 8 vCPU\n"
echo
read -rp "   Choose [1-5, default 2]: " _c || true
case "${_c:-2}" in
  1) CPU="1" ;;
  3) CPU="4" ;;
  4) CPU="6" ;;
  5) CPU="8" ;;
  *) CPU="2" ;;
esac
ok "CPU: ${CPU} vCPU"

# =================== Memory chooser (start from 1Gi) ===================
sec "Memory"
printf "   1) 1Gi\n"
printf "   2) 2Gi   ${C_GREEN}[default]${RESET}\n"
printf "   3) 4Gi\n"
printf "   4) 8Gi\n"
printf "   5) 16Gi\n"
echo
read -rp "   Choose [1-5, default 2]: " _m || true
case "${_m:-2}" in
  1) MEMORY="1Gi" ;;
  2) MEMORY="2Gi" ;;
  3) MEMORY="4Gi" ;;
  4) MEMORY="8Gi" ;;
  5) MEMORY="16Gi" ;;
  *) MEMORY="2Gi" ;;
esac
ok "Memory: ${MEMORY}"

# =================== Other defaults ===================
SERVICE_NAME="${SERVICE_NAME:-m.googleapis.com}"
SERVICE="${SERVICE:-gcp-ahlflk}"
TIMEOUT="${TIMEOUT:-3600}"
PORT="${PORT:-8080}"

# =================== Keys ===================
TROJAN_PASS="ahlflk"
TROJAN_TAG="GCP TROJAN"
TROJAN_PATH="%2Ftrojan"  # Encoded for URI
TROJAN_WS_PATH="/trojan"  # Decoded for config

VLESS_UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
VLESS_PATH="%2Fvless"     # Encoded
VLESS_WS_PATH="/vless"    # Decoded
VLESS_TAG="GCP VLESS WS"

VLESSGRPC_UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
VLESSGRPC_SVC="ahlflk-grpc"
VLESSGRPC_TAG="GCP VLESS GRPC"

# Set protocol-specific vars
case "$PROTO" in
  trojan)
    WS_PATH="$TROJAN_WS_PATH"
    UUID=""  # Not used
    ;;
  vless)
    WS_PATH="$VLESS_WS_PATH"
    ;;
  vlessgrpc)
    WS_PATH=""  # No WS path for gRPC
    ;;
esac

# =================== Summary ===================
sec "Summary"
kv "Protocol" "${BOLD}${PROTO^^}${RESET}"
kv "ServiceName"  "${BOLD}${SERVICE_NAME}${RESET}"
kv "Service" "${BOLD}${SERVICE}${RESET}"
kv "Region"  "${BOLD}${REGION}${RESET}"
kv "CPU/Mem" "${BOLD}${CPU} vCPU / ${MEMORY}${RESET}"
kv "Timeout" "${BOLD}${TIMEOUT}s${RESET}"
kv "Port"    "${BOLD}${PORT}${RESET}"

# =================== Project ===================
sec "Project"
PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$PROJECT" ]]; then
  err "No active GCP project."
  echo "    👉 gcloud config set project <YOUR_PROJECT_ID>"
  exit 1
fi
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
ok "Loaded Project"
kv "Project" "${BOLD}${PROJECT}${RESET}"
kv "Project No." "${PROJECT_NUMBER}"

# =================== Enable APIs & Build Files ===================
sec "Enable APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com containerregistry.googleapis.com --quiet
ok "APIs Enabled"

# Create Dockerfile and entrypoint.sh for custom build
sec "Preparing Build Files"
cat > Dockerfile <<EOF
FROM v2fly/v2fly-core:latest

RUN apk add --no-cache bash

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EXPOSE $PORT
EOF

cat > entrypoint.sh <<'EOF'
#!/bin/bash

# Default vars if not set
PROTO=${PROTO:-vless}
UUID=${UUID:-3675119c-14fc-46a4-b5f3-9a2c91a7d802}
PASS=${PASS:-ahlflk}
WS_PATH=${WS_PATH:-/vless}
GRPC_SVC=${GRPC_SVC:-ahlflk-grpc}
PORT=${PORT:-8080}

# Build config.json dynamically at runtime
cat > /etc/v2ray/config.json <<BASE
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": $PORT,
    "protocol": "$PROTO",
    "settings": {
BASE

if [[ "$PROTO" == "trojan" ]]; then
  cat >> /etc/v2ray/config.json <<SETTINGS
      "clients": [{"password": "$PASS"}]
SETTINGS
else
  cat >> /etc/v2ray/config.json <<SETTINGS
      "clients": [{"id": "$UUID", "level": 0}],
      "decryption": "none"
SETTINGS
fi

cat >> /etc/v2ray/config.json <<BASE
    },
    "streamSettings": {
      "network": "$( [[ "$PROTO" == "vlessgrpc" ]] && echo "grpc" || echo "ws" )",
BASE

if [[ "$PROTO" == "vlessgrpc" ]]; then
  cat >> /etc/v2ray/config.json <<STREAM
      "grpcSettings": {
        "serviceName": "$GRPC_SVC"
      }
STREAM
else
  cat >> /etc/v2ray/config.json <<STREAM
      "wsSettings": {
        "path": "$WS_PATH"
      }
STREAM
fi

cat >> /etc/v2ray/config.json <<BASE
      "security": "none"
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls"]
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "tag": "direct"
  }]
}
BASE

exec v2ray run -c /etc/v2ray/config.json
EOF
ok "Build files created"

# =================== Deploy with Source Build ===================
sec "Deploying (Building Custom Image)"
ENV_VARS="PROTO=$PROTO,UUID=$VLESS_UUID,PASS=$TROJAN_PASS,WS_PATH=$WS_PATH,GRPC_SVC=$VLESSGRPC_SVC"

gcloud run deploy "$SERVICE" \
  --source . \
  --platform=managed \
  --region="$REGION" \
  --memory="$MEMORY" \
  --cpu="$CPU" \
  --timeout="$TIMEOUT" \
  --allow-unauthenticated \
  --port="$PORT" \
  --set-env-vars "$ENV_VARS" \
  --quiet
ok "Deployed Successfully"

# =================== Canonical URL ===================
CANONICAL_HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
URL_CANONICAL="https://${CANONICAL_HOST}"

sec "Result"
ok "Service Ready"
kv "URL" "${C_CYAN}${BOLD}${URL_CANONICAL}${RESET}"

# =================== Build Client URL ===================
LABEL=""; URI=""
case "$PROTO" in
  trojan)
    URI="trojan://${TROJAN_PASS}@${SERVICE_NAME}:443?path=${TROJAN_PATH}&security=tls&encryption=none&host=${CANONICAL_HOST}&fp=randomized&type=ws&sni=${CANONICAL_HOST}#${TROJAN_TAG}"
    LABEL="TROJAN URL"
    ;;
  vless)
    URI="vless://${VLESS_UUID}@${SERVICE_NAME}:443?path=${VLESS_PATH}&security=tls&encryption=none&host=${CANONICAL_HOST}&fp=randomized&type=ws&sni=${CANONICAL_HOST}#${VLESS_TAG}"
    LABEL="VLESS URL (WS)"
    ;;
  vlessgrpc)
    URI="vless://${VLESSGRPC_UUID}@${SERVICE_NAME}:443?mode=grpc&security=tls&encryption=none&fp=randomized&type=grpc&serviceName=${VLESSGRPC_SVC}&sni=${CANONICAL_HOST}#${VLESSGRPC_TAG}"
    LABEL="VLESS-gRPC URL"
    ;;
esac

sec "Client Key"
printf "   ${C_YEL}${BOLD}%s${RESET}\n" "${LABEL}"
printf "   ${C_ORG}👉 %s${RESET}\n" "${URI}"
hr

# =================== Telegram Option ===================
sec "Telegram Notification"
printf "   ${C_YEL}Configure Telegram to send deployment notification? [y/N]: ${RESET}"
read -r _tg_opt
if [[ "${_tg_opt,,}" == "y" || "${_tg_opt,,}" == "yes" ]]; then
  while [[ -z "${TELEGRAM_TOKEN}" ]]; do
    read -rp $'   '${C_YEL}'Enter Telegram Bot Token: ' _t_token
    if [[ -n "${_t_token}" ]]; then
      TELEGRAM_TOKEN="${_t_token}"
    else
      warn "Token cannot be empty. Please enter a valid token."
    fi
  done
  while [[ -z "${TELEGRAM_CHAT_ID}" ]]; do
    read -rp $'   '${C_YEL}'Enter Telegram Chat ID: ' _t_id
    if [[ -n "${_t_id}" ]]; then
      TELEGRAM_CHAT_ID="${_t_id}"
    else
      warn "Chat ID cannot be empty. Please enter a valid chat ID."
    fi
  done
  ok "Telegram configured successfully"
else
  warn "Telegram notification skipped"
fi

# =================== Telegram Push (only if both envs exist) ===================
if [[ -n "${TELEGRAM_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
  HTML_MSG=$(
    cat <<EOF
<b>✅ Cloud Run Deploy Success</b>
<b>Protocol:</b> ${PROTO^^}
<b>Service:</b> ${SERVICE}
<b>Region:</b> ${REGION}
<b>URL:</b> ${URL_CANONICAL}

<pre><code>${URI}</code></pre>
EOF
  )
  if curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
       -d "chat_id=${TELEGRAM_CHAT_ID}" \
       --data-urlencode "text=${HTML_MSG}" \
       -d "parse_mode=HTML" >/dev/null; then
    ok "Telegram message sent successfully"
  else
    err "Failed to send Telegram message. Please check your token and chat ID."
  fi
fi

printf "\n${C_GREEN}${BOLD}✨ All done. Enjoy!${RESET}\n"