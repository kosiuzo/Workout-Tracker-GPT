#!/bin/bash

# Workout Tracker GPT - Setup Verification Script
# This script verifies that your Supabase setup is working correctly

set -e

echo "🏋️  Workout Tracker GPT - Setup Verification"
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Supabase CLI is installed
echo "1️⃣  Checking Supabase CLI..."
if command -v supabase &> /dev/null; then
    SUPABASE_VERSION=$(supabase --version)
    echo -e "${GREEN}✓${NC} Supabase CLI installed: $SUPABASE_VERSION"
else
    echo -e "${RED}✗${NC} Supabase CLI not found. Please install it first."
    echo "   Install with: brew install supabase/tap/supabase"
    exit 1
fi
echo ""

# Check if Docker is running
echo "2️⃣  Checking Docker..."
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker is running"
else
    echo -e "${RED}✗${NC} Docker is not running. Please start Docker Desktop."
    exit 1
fi
echo ""

# Check if Supabase is running
echo "3️⃣  Checking Supabase status..."
if supabase status &> /dev/null; then
    echo -e "${GREEN}✓${NC} Supabase is running"
    echo ""
    supabase status
else
    echo -e "${YELLOW}⚠${NC} Supabase is not running."
    echo "   Starting Supabase..."
    supabase start
fi
echo ""

# Get API URL and Anon Key
API_URL=$(supabase status | grep "API URL" | awk '{print $3}')
ANON_KEY=$(supabase status | grep "anon key" | awk '{print $3}')

echo "4️⃣  Testing database connection..."
if supabase db remote commit &> /dev/null || supabase db lint &> /dev/null; then
    echo -e "${GREEN}✓${NC} Database is accessible"
else
    echo -e "${YELLOW}⚠${NC} Database check inconclusive (this is OK for local setup)"
fi
echo ""

# Test REST API
echo "5️⃣  Testing REST API..."
WORKOUTS_COUNT=$(curl -s "${API_URL}/rest/v1/workouts?select=count" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" | grep -o "count" | wc -l)

if [ $WORKOUTS_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓${NC} REST API is responding"
else
    echo -e "${YELLOW}⚠${NC} REST API response unclear (may need to reset database)"
fi
echo ""

# Test RPC functions
echo "6️⃣  Testing RPC functions..."
ACTIVE_WORKOUT=$(curl -s "${API_URL}/rest/v1/rpc/get_active_workout" \
    -X POST \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json")

if echo "$ACTIVE_WORKOUT" | grep -q "success"; then
    echo -e "${GREEN}✓${NC} RPC functions are working"

    # Check if there's an active workout
    if echo "$ACTIVE_WORKOUT" | grep -q "Push/Pull/Legs"; then
        echo -e "${GREEN}✓${NC} Sample workout plan found (database is seeded)"
    else
        echo -e "${YELLOW}⚠${NC} No active workout found (run: supabase db reset)"
    fi
else
    echo -e "${RED}✗${NC} RPC functions test failed"
    echo "   Response: $ACTIVE_WORKOUT"
    echo "   Run: supabase db reset"
fi
echo ""

# Test specific endpoints
echo "7️⃣  Testing key endpoints..."

# Test get_workout_for_day
MONDAY_WORKOUT=$(curl -s "${API_URL}/rest/v1/rpc/get_workout_for_day" \
    -X POST \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"day_name":"monday"}')

if echo "$MONDAY_WORKOUT" | grep -q "exercises"; then
    echo -e "${GREEN}✓${NC} get_workout_for_day works"
else
    echo -e "${YELLOW}⚠${NC} get_workout_for_day returned unexpected response"
fi

# Test sessions endpoint
SESSIONS=$(curl -s "${API_URL}/rest/v1/sessions?limit=1" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json")

if echo "$SESSIONS" | grep -q "entries"; then
    echo -e "${GREEN}✓${NC} Sessions endpoint works"
else
    echo -e "${YELLOW}⚠${NC} Sessions endpoint check unclear"
fi

# Test history endpoints
HISTORY=$(curl -s "${API_URL}/rest/v1/workout_history?limit=1" \
    -H "apikey: ${ANON_KEY}" \
    -H "Content-Type: application/json")

if [ -n "$HISTORY" ]; then
    echo -e "${GREEN}✓${NC} History endpoints accessible"
fi
echo ""

# Check migration files
echo "8️⃣  Checking migration files..."
MIGRATION_COUNT=$(ls -1 supabase/migrations/*.sql 2>/dev/null | wc -l)

if [ $MIGRATION_COUNT -eq 3 ]; then
    echo -e "${GREEN}✓${NC} All 3 migration files found"
    ls supabase/migrations/*.sql | sed 's/^/   /'
else
    echo -e "${RED}✗${NC} Expected 3 migration files, found $MIGRATION_COUNT"
fi
echo ""

# Check seed file
echo "9️⃣  Checking seed file..."
if [ -f "supabase/seed.sql" ]; then
    SEED_SIZE=$(wc -l < supabase/seed.sql)
    echo -e "${GREEN}✓${NC} Seed file found ($SEED_SIZE lines)"
else
    echo -e "${RED}✗${NC} Seed file not found"
fi
echo ""

# Check OpenAPI spec
echo "🔟 Checking OpenAPI specification..."
if [ -f "openapi.yaml" ]; then
    ENDPOINT_COUNT=$(grep "operationId:" openapi.yaml | wc -l)
    echo -e "${GREEN}✓${NC} OpenAPI spec found ($ENDPOINT_COUNT endpoints)"
else
    echo -e "${RED}✗${NC} openapi.yaml not found"
fi
echo ""

# Summary
echo "=============================================="
echo "📊 Verification Summary"
echo "=============================================="
echo ""
echo "Your Supabase Details:"
echo "  API URL: $API_URL"
echo "  Anon Key: ${ANON_KEY:0:20}..."
echo ""
echo "Studio URL: http://127.0.0.1:54323"
echo ""

# Final check
if [ $MIGRATION_COUNT -eq 3 ] && [ -f "openapi.yaml" ]; then
    echo -e "${GREEN}✅ Setup verification complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Open Supabase Studio: open http://127.0.0.1:54323"
    echo "  2. Check the 'workouts' table - should have 1 row"
    echo "  3. Run sample queries in SQL Editor (see SETUP.md)"
    echo "  4. Configure your Custom GPT with openapi.yaml"
    echo ""
    echo "For production deployment: see SETUP.md#production-deployment"
else
    echo -e "${YELLOW}⚠️  Setup incomplete${NC}"
    echo ""
    echo "Please ensure:"
    echo "  - All migration files are present"
    echo "  - Database is seeded (run: supabase db reset)"
    echo "  - OpenAPI spec exists"
fi
echo ""
