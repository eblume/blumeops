#!/bin/sh
set -e

# Auto-generate AUTH_SECRET if not provided
if [ -z "$AUTH_SECRET" ]; then
  AUTH_SECRET="$(node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")"
  export AUTH_SECRET
  echo "AUTH_SECRET was not set — generated a temporary secret for this container."
fi

# Run Prisma migrations (npx -y downloads prisma if not in local node_modules)
npx -y prisma@6.19.0 migrate deploy

# Start the Next.js server
exec node server.js
