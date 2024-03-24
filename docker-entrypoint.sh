#!/bin/sh

# A wrapper script for treating SIGTERM appropriately

# npm migrateandstart
cd packages/backend
npx typeorm migration:run -d ormconfig.js && node --experimental-json-modules ./built/index.js
