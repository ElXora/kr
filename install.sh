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
# ============================================================

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

# ── Banner ──────────────────────────────────────────────────
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
echo -e "${RESET}${GRAY}  Kroxy Panel Installer${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
sleep 0.4

# ── Root check ──────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  fail "Run as root: sudo bash install.sh"
fi

# ── User input ──────────────────────────────────────────────
ask "→ Panel name (press Enter for default: Kroxy):"
read -rp "  Name: " PANEL_NAME
PANEL_NAME="${PANEL_NAME:-Kroxy}"

ask "→ Pterodactyl panel URL (e.g. https://panel.yourdomain.com):"
read -rp "  URL: " PANEL_URL
if [ -z "$PANEL_URL" ]; then fail "Panel URL cannot be empty."; fi
PANEL_URL="${PANEL_URL%/}"

ask "→ Pterodactyl Application API key (starts with ptla_):"
read -rp "  API Key: " PTERO_KEY
if [ -z "$PTERO_KEY" ]; then fail "API key cannot be empty."; fi

ask "→ Your admin email:"
read -rp "  Email: " ADMIN_EMAIL
if [ -z "$ADMIN_EMAIL" ]; then fail "Admin email cannot be empty."; fi

ask "→ Your admin username (for admin panel login):"
read -rp "  Username: " ADMIN_USERNAME
if [ -z "$ADMIN_USERNAME" ]; then fail "Admin username cannot be empty."; fi

ask "→ Your admin password (for admin panel login):"
read -rsp "  Password: " ADMIN_PASSWORD
echo ""
if [ -z "$ADMIN_PASSWORD" ]; then fail "Admin password cannot be empty."; fi

ask "→ Port for Kroxy (press Enter for default 3001):"
read -rp "  Port: " APP_PORT
APP_PORT="${APP_PORT:-3001}"

ask "→ Discord OAuth Client ID:"
read -rp "  Client ID: " DISCORD_CLIENT_ID
if [ -z "$DISCORD_CLIENT_ID" ]; then fail "Discord Client ID cannot be empty."; fi

ask "→ Discord OAuth Client Secret:"
read -rp "  Client Secret: " DISCORD_CLIENT_SECRET
if [ -z "$DISCORD_CLIENT_SECRET" ]; then fail "Discord Client Secret cannot be empty."; fi

ask "→ Discord Bot Token (press Enter to skip):"
read -rp "  Bot Token: " DISCORD_BOT_TOKEN
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-placeholder}"

ask "→ Dashboard domain (e.g. https://dash.yourdomain.com) — used for Discord OAuth callback:"
read -rp "  Domain: " DASH_DOMAIN
if [ -z "$DASH_DOMAIN" ]; then fail "Dashboard domain cannot be empty."; fi
DASH_DOMAIN="${DASH_DOMAIN%/}"

ask "→ Session secret (press Enter to auto-generate):"
read -rp "  Secret: " SESSION_SECRET
if [ -z "$SESSION_SECRET" ]; then
  SESSION_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 48)
  ok "Session secret auto-generated."
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo -e "  ${WHITE}${BOLD}Summary${RESET}"
dim "  Panel Name  : $PANEL_NAME"
dim "  Panel URL   : $PANEL_URL"
dim "  Dashboard   : $DASH_DOMAIN"
dim "  Admin Email : $ADMIN_EMAIL"
dim "  Admin User  : $ADMIN_USERNAME"
dim "  Admin Pass  : ********"
dim "  Port        : $APP_PORT"
dim "  Install Dir : $INSTALL_DIR"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo ""
ask "→ Proceed? (y/N):"
read -rp "  " CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [ "$CONFIRM_LOWER" != "y" ] && [ "$CONFIRM_LOWER" != "yes" ]; then
  echo -e "\n${GRAY}  Cancelled.${RESET}\n"; exit 0
fi

# ── Dependencies ─────────────────────────────────────────────
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

# ── Copy files ───────────────────────────────────────────────
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

# ── Remove Shadowless / Heliactyl / Xalora branding ──────────
step "Removing Shadowless/Heliactyl/Xalora branding..."

# Rewrite README
cat > "$INSTALL_DIR/README.md" << 'README'
# Kroxy Panel

A modern client panel for Pterodactyl.

## Features
- Resource Management
- Coins (AFK Page Earning, Linkvertise earning)
- Renewal system
- Server management (create, view, edit)
- User system (auth, regen password)
- Store (buy resources with coins)
- Dashboard
- Admin panel (coins, resources, coupons)
- API

## Starting
```
pm2 start app.js --name kroxy
pm2 logs kroxy
pm2 restart kroxy
```
README

# Rewrite package.json name/description
node -e "
const fs = require('fs');
const p = '$INSTALL_DIR/package.json';
const d = JSON.parse(fs.readFileSync(p));
d.name = 'kroxy';
d.description = 'Kroxy client panel for Pterodactyl.';
fs.writeFileSync(p, JSON.stringify(d, null, 2));
" 2>/dev/null || warn "Could not update package.json name."

# Replace branding strings in all JS/EJS files
find "$INSTALL_DIR" -type f \( -name "*.js" -o -name "*.ejs" \) \
  ! -path "*/node_modules/*" \
  ! -name "package-lock.json" | while read -r FILE; do
    sed -i \
      -e 's/Shadowless/Kroxy/g' \
      -e 's/shadowless/kroxy/g' \
      -e 's/ShadowlessDash/Kroxy/g' \
      -e 's/Heliactyl/Kroxy/g' \
      -e 's/heliactyl/kroxy/g' \
      -e 's/Xalora/Kroxy/g' \
      -e 's/xalora/kroxy/g' \
      -e 's/XaloraClient/Kroxy/g' \
      "$FILE" 2>/dev/null || true
done

ok "Branding replaced with Kroxy."

# ── Write settings.json ──────────────────────────────────────
step "Writing settings.json..."

SETTINGS_FILE="$INSTALL_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak" 2>/dev/null || true
  dim "Backed up old settings → settings.json.bak"
fi

cat > "$SETTINGS_FILE" << SETTINGS
{
  "name": "${PANEL_NAME}",
  "logo": "https://avatars.githubusercontent.com/u/188295803?s=400&v=4",
  "adminUsername": "${ADMIN_USERNAME}",
  "adminPassword": "${ADMIN_PASSWORD}",
  "defaultAdmin": {
    "username": "admin",
    "password": "admin123"
  },
  "pterodactyl": {
    "domain": "${PANEL_URL}",
    "key": "${PTERO_KEY}"
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
        "link": "${DASH_DOMAIN}",
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

ok "settings.json written."

# ── npm install ──────────────────────────────────────────────
step "Installing npm packages..."
cd "$INSTALL_DIR" || fail "Cannot cd to $INSTALL_DIR"
npm install > /dev/null 2>&1 || fail "npm install failed."
ok "npm packages installed."

# ── Start with PM2 ───────────────────────────────────────────
step "Starting Kroxy with PM2..."
pm2 delete "$SERVICE_NAME" > /dev/null 2>&1 || true
pm2 start app.js --name "$SERVICE_NAME" > /dev/null 2>&1 || fail "PM2 failed to start. Run: pm2 logs $SERVICE_NAME"
pm2 save > /dev/null 2>&1 || true
pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true
systemctl enable pm2-root > /dev/null 2>&1 || true
ok "Kroxy is running."

# ── Nginx config ─────────────────────────────────────────────
step "Writing Nginx config..."
DOMAIN_CLEAN=$(echo "$DASH_DOMAIN" | sed 's|https\?://||')

if command -v nginx > /dev/null 2>&1; then
  cat > "/etc/nginx/sites-available/kroxy.conf" << NGINX
server {
    listen 80;
    server_name ${DOMAIN_CLEAN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_CLEAN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN_CLEAN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_CLEAN}/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location /afk/ws {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://localhost:${APP_PORT}/afk/ws;
    }
    location / {
        proxy_pass http://localhost:${APP_PORT}/;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
    }
}
NGINX
  ln -sf /etc/nginx/sites-available/kroxy.conf /etc/nginx/sites-enabled/kroxy.conf 2>/dev/null || true
  nginx -t > /dev/null 2>&1 && systemctl reload nginx > /dev/null 2>&1 && ok "Nginx config written and reloaded." || warn "Nginx config written but reload failed — check manually."
else
  warn "Nginx not found — skipping config. Install nginx and use the config in /etc/nginx/sites-available/kroxy.conf manually."
  mkdir -p /etc/nginx/sites-available
  cat > "/etc/nginx/sites-available/kroxy.conf" << NGINX
server {
    listen 80;
    server_name ${DOMAIN_CLEAN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_CLEAN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN_CLEAN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_CLEAN}/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location /afk/ws {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_pass http://localhost:${APP_PORT}/afk/ws;
    }
    location / {
        proxy_pass http://localhost:${APP_PORT}/;
        proxy_buffering off;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
    }
}
NGINX
  dim "Nginx config saved to /etc/nginx/sites-available/kroxy.conf for when you install nginx."
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${WHITE}${BOLD}"
cat << 'DONE'
  ┌─────────────────────────────────────────────┐
  │          ✓  Kroxy is installed!             │
  └─────────────────────────────────────────────┘
DONE
echo -e "${RESET}"
echo -e "  ${WHITE}${BOLD}Dashboard${RESET}    ${DASH_DOMAIN}"
echo -e "  ${WHITE}${BOLD}Direct${RESET}       http://YOUR_SERVER_IP:${APP_PORT}"
echo -e "  ${WHITE}${BOLD}Panel URL${RESET}    ${PANEL_URL}"
echo -e "  ${WHITE}${BOLD}Install Dir${RESET}  ${INSTALL_DIR}"
echo ""
echo -e "  ${WHITE}${BOLD}Admin Login${RESET}"
echo -e "  ${DIM}  Default: admin / admin123${RESET}"
echo -e "  ${DIM}  Custom:  ${ADMIN_USERNAME} / (your password)${RESET}"
echo ""
echo -e "  ${DIM}Commands:  pm2 logs ${SERVICE_NAME}  |  pm2 restart ${SERVICE_NAME}  |  pm2 stop ${SERVICE_NAME}${RESET}"
echo ""
