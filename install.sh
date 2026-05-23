#!/bin/bash
# ============================================================
#
#   ██╗  ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
#   ██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
#   █████╔╝ ██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝
#   ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝
#   ██║  ██╗██║  ██║╚██████╔╝██╔╝ ██╗   ██║
#   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
#
#   Kroxy Panel — One-Command Installer
#   Black & White Theme | Heliactyl Base
# ============================================================
# NO set -e — every error is handled manually so nothing
# silently exits mid-install.

RESET='\033[0m'; BOLD='\033[1m'; WHITE='\033[1;37m'
GRAY='\033[0;37m'; DIM='\033[2m'; RED='\033[0;31m'
GREEN='\033[0;32m'; YELLOW='\033[1;33m'

step() { echo -e "\n${WHITE}${BOLD}[•] $1${RESET}"; }
ok()   { echo -e "  ${GREEN}✓${RESET}  $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail() { echo -e "\n${RED}${BOLD}[✗] $1${RESET}\n"; exit 1; }
dim()  { echo -e "  ${DIM}$1${RESET}"; }
ask()  { echo -e "\n${WHITE}${BOLD}$1${RESET}"; }

INSTALL_DIR="/opt/kroxy"
SERVICE_NAME="kroxy"
ALREADY_INSTALLED=false

# ── Banner ─────────────────────────────────────────────────
clear
echo -e "${WHITE}${BOLD}"
cat << 'BANNER'

  ██╗  ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
  ██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
  █████╔╝ ██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝
  ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝
  ██║  ██╗██║  ██║╚██████╔╝██╔╝ ██╗   ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

BANNER
echo -e "${RESET}${GRAY}  Kroxy Panel Installer — Black & White Edition${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
sleep 0.4

# ── Root check ─────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  fail "Run as root: sudo bash install.sh"
fi

# ── Already installed check ────────────────────────────────
if [ -f "$INSTALL_DIR/app.js" ]; then
  ALREADY_INSTALLED=true
  warn "Kroxy already found at $INSTALL_DIR — skipping dependency install."
fi

# ── User input ─────────────────────────────────────────────
ask "→ Pterodactyl panel URL (e.g. https://panel.yourdomain.com):"
read -rp "  URL: " PANEL_URL
if [ -z "$PANEL_URL" ]; then fail "Panel URL cannot be empty."; fi
# Strip trailing slash
PANEL_URL="${PANEL_URL%/}"

ask "→ Your admin email:"
read -rp "  Email: " ADMIN_EMAIL
if [ -z "$ADMIN_EMAIL" ]; then fail "Admin email cannot be empty."; fi

ask "→ Your admin username (Pterodactyl username for admin panel login):"
read -rp "  Username: " ADMIN_USERNAME
if [ -z "$ADMIN_USERNAME" ]; then fail "Admin username cannot be empty."; fi

ask "→ Port for Kroxy (press Enter for default 3001):"
read -rp "  Port: " APP_PORT
APP_PORT="${APP_PORT:-3001}"

ask "→ Discord OAuth Client ID:"
read -rp "  Client ID: " DISCORD_CLIENT_ID
if [ -z "$DISCORD_CLIENT_ID" ]; then fail "Discord Client ID cannot be empty."; fi

ask "→ Discord OAuth Client Secret:"
read -rp "  Client Secret: " DISCORD_CLIENT_SECRET
if [ -z "$DISCORD_CLIENT_SECRET" ]; then fail "Discord Client Secret cannot be empty."; fi

ask "→ Discord Bot Token (optional — press Enter to skip):"
read -rp "  Bot Token: " DISCORD_BOT_TOKEN
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-placeholder}"

ask "→ Session secret (press Enter to auto-generate):"
read -rp "  Secret: " SESSION_SECRET
if [ -z "$SESSION_SECRET" ]; then
  SESSION_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 48)
  ok "Session secret auto-generated."
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo -e "  ${WHITE}${BOLD}Summary${RESET}"
dim "  Panel URL   : $PANEL_URL"
dim "  Admin Email : $ADMIN_EMAIL"
dim "  Admin User  : $ADMIN_USERNAME"
dim "  Port        : $APP_PORT"
dim "  Install Dir : $INSTALL_DIR"
dim "  API Key     : set manually in settings.json after install"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo ""
ask "→ Proceed? (y/N):"
read -rp "  " CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [ "$CONFIRM_LOWER" != "y" ] && [ "$CONFIRM_LOWER" != "yes" ]; then
  echo -e "\n${GRAY}  Cancelled.${RESET}\n"; exit 0
fi

# ── Dependencies ───────────────────────────────────────────
if [ "$ALREADY_INSTALLED" = false ]; then

  step "Updating packages..."
  apt-get update -qq 2>/dev/null || warn "apt-get update had warnings — continuing."
  apt-get install -y curl git unzip sqlite3 2>/dev/null || warn "Some packages may have warnings — continuing."
  ok "System packages ready."

  step "Installing Node.js 20..."
  NODE_OK=false
  if command -v node > /dev/null 2>&1; then
    NODE_VER=$(node -v 2>/dev/null | cut -d. -f1 | tr -d 'v')
    if [ "$NODE_VER" -ge 18 ] 2>/dev/null; then
      ok "Node.js $(node -v) already present — skipping."
      NODE_OK=true
    fi
  fi
  if [ "$NODE_OK" = false ]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1 || warn "nodesource setup had warnings."
    apt-get install -y nodejs > /dev/null 2>&1 || fail "Node.js install failed."
    ok "Node.js $(node -v) installed."
  fi

  step "Installing PM2..."
  if command -v pm2 > /dev/null 2>&1; then
    ok "PM2 already present — skipping."
  else
    npm install -g pm2 > /dev/null 2>&1 || fail "PM2 install failed."
    ok "PM2 installed."
  fi

else
  step "Skipping dependency install (already installed)."
  NODE_VER=$(node -v 2>/dev/null || echo "not found")
  PM2_VER=$(pm2 -v 2>/dev/null || echo "not found")
  ok "Node.js $NODE_VER"
  ok "PM2 $PM2_VER"
fi

# ── Copy files ─────────────────────────────────────────────
step "Copying Kroxy files..."

pm2 stop "$SERVICE_NAME" > /dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/app.js" ]; then
  cp -r "$SCRIPT_DIR/." "$INSTALL_DIR/" 2>/dev/null || fail "Failed to copy files to $INSTALL_DIR"
  ok "Files copied to $INSTALL_DIR"
else
  fail "app.js not found. Place install.sh in the same folder as the Kroxy panel files."
fi

# ── Write settings.json ────────────────────────────────────
step "Writing settings.json..."

SETTINGS_FILE="$INSTALL_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ] && [ "$ALREADY_INSTALLED" = true ]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak" 2>/dev/null || true
  dim "Backed up old settings → settings.json.bak"
fi

# Write the full valid settings.json — all required fields included
# so app.js does NOT crash on startup with missing keys
cat > "$SETTINGS_FILE" << SETTINGS
{
  "name": "Kroxy",
  "logo": "https://avatars.githubusercontent.com/u/188295803?s=400&v=4",
  "adminUsername": "${ADMIN_USERNAME}",
  "pterodactyl": {
    "domain": "${PANEL_URL}",
    "key": "ptla_REPLACEME"
  },
  "announcements": {
    "enabled": false,
    "message": ""
  },
  "timezone": "UTC",
  "version": "1.0.0",
  "testing": false,
  "website": {
    "port": ${APP_PORT},
    "secret": "${SESSION_SECRET}"
  },
  "linkvertise": {
    "userid": "50000",
    "dailyLimit": 1,
    "coins": 10
  },
  "database": "sqlite://database.sqlite",
  "api": {
    "email": {
      "enabled": false,
      "resend": ""
    },
    "client": {
      "accountSwitcher": false,
      "api": {
        "enabled": true,
        "code": "${SESSION_SECRET}"
      },
      "j4r": {
        "enabled": false,
        "ads": []
      },
      "bot": {
        "token": "${DISCORD_BOT_TOKEN}",
        "joinguild": {
          "enabled": false,
          "guildid": ["000000000000000000"]
        },
        "giverole": {
          "enabled": false,
          "guildid": "000000000000000000",
          "roleid": "000000000000000000"
        }
      },
      "passwordgenerator": {
        "signup": true,
        "length": 16
      },
      "allow": {
        "newusers": true,
        "regen": true,
        "server": {
          "create": true,
          "modify": true,
          "delete": true
        },
        "overresourcessuspend": false
      },
      "oauth2": {
        "id": "${DISCORD_CLIENT_ID}",
        "secret": "${DISCORD_CLIENT_SECRET}",
        "link": "${PANEL_URL}",
        "callbackpath": "/callback",
        "prompt": false,
        "ip": {
          "trust x-forwarded-for": true,
          "block": [],
          "duplicate check": false
        }
      },
      "ratelimits": {
        "/callback": 2,
        "/create": 1,
        "/delete": 1,
        "/modify": 1,
        "/updateinfo": 1,
        "/setplan": 2,
        "/admin": 1,
        "/regen": 1,
        "/renew": 1,
        "/api/userinfo": 1
      },
      "packages": {
        "default": "default",
        "list": {
          "default": {
            "ram": 2048,
            "disk": 5120,
            "cpu": 100,
            "servers": 1
          }
        },
        "rolePackages": {
          "roleServer": "",
          "roles": {}
        }
      },
      "locations": {
        "1": {
          "name": "Default",
          "country": "US",
          "region": "US",
          "capacity": 100,
          "node": "Node-1",
          "id": 1,
          "package": null
        }
      },
      "eggs": {
        "paper": {
          "category": "Minecraft Java",
          "display": "Paper",
          "icon": "https://papermc.io/assets/logo/256x.png",
          "minimum": { "ram": 1024, "disk": 1024, "cpu": 100 },
          "maximum": { "ram": null, "disk": null, "cpu": null },
          "info": {
            "egg": 3,
            "docker_image": "ghcr.io/pterodactyl/yolks:java_17",
            "startup": "java -Xms128M -Xmx{{SERVER_MEMORY}}M -Dterminal.jline=false -Dterminal.ansi=true -jar {{SERVER_JARFILE}}",
            "environment": {
              "SERVER_JARFILE": "server.jar",
              "BUILD_NUMBER": "latest"
            },
            "feature_limits": { "databases": 4, "backups": 4 }
          }
        }
      },
      "coins": {
        "enabled": true,
        "name": "Coins",
        "store": {
          "enabled": true,
          "ram":     { "cost": 300, "per": 1024 },
          "disk":    { "cost": 200, "per": 5120 },
          "cpu":     { "cost": 350, "per": 100  },
          "servers": { "cost": 100, "per": 1    }
        }
      }
    },
    "afk": {
      "path": "ws",
      "every": 60,
      "coins": 1,
      "enabled": true
    }
  },
  "antivpn": {
    "status": false,
    "APIKey": "",
    "whitelistedIPs": []
  },
  "servercreation": {
    "cost": 0
  },
  "renewals": {
    "status": false,
    "cost": 10,
    "renew": 24,
    "delay": 1,
    "bypassCost": 50,
    "logs": false
  },
  "whitelist": {
    "status": false,
    "users": []
  },
  "logging": {
    "status": false,
    "webhook": "",
    "actions": {
      "user": {
        "signup": true,
        "create server": true,
        "gifted coins": true,
        "modify server": true,
        "buy servers": true,
        "buy ram": true,
        "buy cpu": true,
        "buy disk": true
      },
      "admin": {
        "set coins": true,
        "add coins": true,
        "set resources": true,
        "set plan": true,
        "create coupon": true,
        "revoke coupon": true,
        "remove account": true,
        "view ip": true
      }
    }
  }
}
SETTINGS

ok "settings.json written (all required fields included)."


# ── Patch app.js — stop crash loop on bad API key ─────────
step "Patching app.js crash loop..."
APP_JS="$INSTALL_DIR/app.js"

# 1. Replace the raw cluster.fork() inside the exit handler with a
#    version that checks the API key first and stops looping if it
#    is still the placeholder value.
PATCH_MARKER="// kroxy-patched"
if ! grep -q "$PATCH_MARKER" "$APP_JS" 2>/dev/null; then
  # Wrap the cluster exit re-fork so it bails on placeholder key
  sed -i "s|setTimeout(() => cluster.fork(), 2000);|$PATCH_MARKER\n    const _s = JSON.parse(require('fs').readFileSync('./settings.json'));\n    if (_s.pterodactyl \&\& _s.pterodactyl.key === 'ptla_REPLACEME') {\n      console.log('\\\\x1b[33m[Kroxy] API key is still ptla_REPLACEME — stopping auto-restart. Set your key then run: pm2 restart kroxy\\\\x1b[0m');\n      return;\n    }\n    setTimeout(() => cluster.fork(), 3000);|" "$APP_JS" 2>/dev/null || true

  # Also replace the initial bare cluster.fork() loop (the numCPUs loop)
  # so it only forks 1 worker instead of one per CPU — prevents flood
  sed -i "s|for (let i = 0; i < numCPUs; i++) {|for (let i = 0; i < 1; i++) { // kroxy: single worker to avoid crash flood|" "$APP_JS" 2>/dev/null || true

  ok "app.js patched — single worker, stops reforking on placeholder key."
else
  ok "app.js already patched."
fi

# ── npm install ────────────────────────────────────────────
step "Installing npm packages..."
cd "$INSTALL_DIR" || fail "Cannot cd to $INSTALL_DIR"
npm install > /dev/null 2>&1 || fail "npm install failed."
ok "npm packages installed."

# ── Start with PM2 ────────────────────────────────────────
step "Starting Kroxy with PM2..."

pm2 delete "$SERVICE_NAME" > /dev/null 2>&1 || true
pm2 start app.js --name "$SERVICE_NAME" > /dev/null 2>&1 || fail "PM2 failed to start. Run: pm2 logs $SERVICE_NAME"
pm2 save > /dev/null 2>&1 || true
pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true
systemctl enable pm2-root > /dev/null 2>&1 || true

ok "Kroxy is running."

# ── Done ──────────────────────────────────────────────────
echo ""
echo -e "${WHITE}${BOLD}"
cat << 'DONE'
  ┌─────────────────────────────────────────────┐
  │          ✓  Kroxy is installed!             │
  └─────────────────────────────────────────────┘
DONE
echo -e "${RESET}"
echo -e "  ${WHITE}${BOLD}Dashboard${RESET}    http://YOUR_SERVER_IP:${APP_PORT}"
echo -e "  ${WHITE}${BOLD}Panel URL${RESET}    ${PANEL_URL}"
echo -e "  ${WHITE}${BOLD}Install Dir${RESET}  ${INSTALL_DIR}"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠  One more step — add your Pterodactyl API key:${RESET}"
echo -e "  ${DIM}  1. nano ${INSTALL_DIR}/settings.json${RESET}"
echo -e "  ${DIM}  2. Replace \"ptla_REPLACEME\" with your Application API key${RESET}"
echo -e "  ${DIM}     (Pterodactyl admin → Application API → Create key)${RESET}"
echo -e "  ${DIM}  3. pm2 restart ${SERVICE_NAME}${RESET}"
echo ""
echo -e "  ${DIM}Commands:  pm2 logs ${SERVICE_NAME}  |  pm2 restart ${SERVICE_NAME}  |  pm2 stop ${SERVICE_NAME}${RESET}"
echo ""
