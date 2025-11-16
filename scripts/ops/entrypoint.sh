#!/bin/bash

# Entrypoint script for VibeZ backend
# Runs tests before starting the server

set -e

echo "Starting VibeZ backend initialization..."

# Run tests if test script exists
if [ -f "package.json" ] && grep -q '"test"' package.json; then
  echo "Running tests..."
  npm test || {
    echo "Tests failed! Aborting startup."
    exit 1
  }
  echo "Tests passed!"
else
  echo "No test script found, skipping tests"
fi

# Start the server
echo "Starting server..."
exec npm start

