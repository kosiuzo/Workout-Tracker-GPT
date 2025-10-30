# Workout Tracker GPT

> A conversational workout tracking system powered by Supabase and OpenAI's Custom GPT. Track workouts, log sessions, and analyze progress through natural language.

[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com)

## Features

✅ **Flexible Workout Templates** - JSONB-based structure supports any workout split
✅ **Conversational Logging** - Natural language session tracking via Custom GPT
✅ **Progress Analytics** - Automatic aggregation of volume, PRs, and trends
✅ **Smart Updates** - Surgical JSON editing for precise weight/rep modifications
✅ **Single Active Plan** - Always know "what's my workout today?"
✅ **Production Ready** - RLS-enabled, scalable schema, comprehensive RPC functions

## Quick Start

```bash
# Start local Supabase
supabase start

# Apply migrations and seed data
supabase db reset

# Open Supabase Studio
open http://127.0.0.1:54323
```

**See [SETUP.md](./docs/SETUP.md) for complete installation guide.**

## Architecture

```
Custom GPT (Natural Language)
         ↓
OpenAPI 3.1 Specification
         ↓
Supabase REST API + RPC Functions
         ↓
PostgreSQL + JSONB Storage
```

**Read [ARCHITECTURE.md](./docs/ARCHITECTURE.md) for system design details.**

## Project Structure

```
Workout-Tracker-GPT/
├── supabase/
│   ├── migrations/
│   │   ├── 20250101000000_create_workout_tracker_schema.sql
│   │   ├── 20250101000001_create_rpc_functions.sql
│   │   └── 20250101000002_create_json_manipulation_functions.sql
│   ├── seed.sql                    # Sample Push/Pull/Legs plan
│   └── config.toml                 # Supabase configuration
├── docs/
│   ├── ARCHITECTURE.md             # System design documentation
│   ├── SETUP.md                    # Installation & deployment guide
│   └── implementation-notes/       # Implementation details and tooling
├── openapi-gpt-optimized.yaml      # GPT-optimized API spec
├── openapi-all-endpoints.yaml      # Complete API reference
└── README.md                       # This file
```

## Database Schema

### Core Tables

**`workouts`** - Workout templates with flexible JSONB structure
```json
{
  "monday": [
    {"exercise": "Bench Press", "sets": 4, "reps": 8, "weight": 185}
  ]
}
```

**`sessions`** - Actual workout logs with set-by-set details
```json
[
  {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185},
  {"exercise": "Bench Press", "set": 2, "reps": 7, "weight": 185}
]
```

**`exercise_history`** - Daily aggregated totals per exercise
**`workout_history`** - Daily aggregated totals per workout

### Key RPC Functions

| Function | Purpose |
|----------|---------|
| `set_active_workout(uuid)` | Activate a workout plan |
| `get_workout_for_day(day_name)` | Get today's exercises |
| `calc_all_history(date)` | Aggregate session data |
| `update_workout_day_weight(...)` | Update template weight |
| `get_recent_progress(days_back)` | Progress summary |
| `get_exercise_progress(exercise)` | Exercise trend analysis |

**See [ARCHITECTURE.md](./docs/ARCHITECTURE.md#rpc-functions) for complete function reference.**

## Usage Examples

### Via Custom GPT

```
You: "What's my workout for today?"
GPT: Shows Monday's exercises from active plan

You: "Log my session: bench press 185x8, 185x7, 185x6"
GPT: Creates session with 3 sets, calculates history

You: "Show my progress this week"
GPT: Summarizes total volume, sets, exercises

You: "I'm ready to increase bench press to 195"
GPT: Updates workout template for next session
```

### Get OpenAPI Specification

The REST API auto-generates an OpenAPI 2.0 (Swagger) specification based on your database schema:

```bash
# Download the OpenAPI spec
curl 'https://your-project.supabase.co/rest/v1/' \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  > swagger_2.0.yml

# For local development
curl 'http://127.0.0.1:54321/rest/v1/' \
  -H "apikey: YOUR_LOCAL_ANON_KEY" \
  -H "Authorization: Bearer YOUR_LOCAL_ANON_KEY" \
  > swagger_2.0.yml
```

Note: This returns OpenAPI 2.0 format. Convert to 3.x using [Swagger Editor](https://editor.swagger.io/) if needed.

### Via REST API

```bash
# Get active workout
curl "https://your-project.supabase.co/rest/v1/rpc/get_active_workout" \
  -X POST \
  -H "apikey: YOUR_ANON_KEY"

# Log a session
curl "https://your-project.supabase.co/rest/v1/sessions" \
  -X POST \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workout_id": "uuid-here",
    "date": "2025-01-15",
    "entries": [
      {"exercise": "Bench Press", "set": 1, "reps": 8, "weight": 185}
    ]
  }'
```

## Deployment

### Local Development
```bash
supabase start
supabase db reset
```

### Production
```bash
supabase login
supabase link --project-ref your-ref
supabase db push
```

**Full deployment guide: [SETUP.md](./docs/SETUP.md#production-deployment)**

## Custom GPT Setup

1. Create Supabase project and get API credentials
2. Update [openapi-gpt-optimized.yaml](./openapi-gpt-optimized.yaml) with your project URL
3. Create Custom GPT at [chat.openai.com/gpts/editor](https://chat.openai.com/gpts/editor)
4. Import OpenAPI spec and configure API key authentication
5. Test with natural language prompts

**Complete walkthrough: [SETUP.md](./docs/SETUP.md#custom-gpt-configuration)**

## Tech Stack

- **Backend**: Supabase (PostgreSQL + REST API)
- **Database**: PostgreSQL 17 with JSONB
- **API**: Supabase REST + Custom RPC Functions
- **AI**: OpenAI Custom GPT with OpenAPI 3.1
- **Local Dev**: Supabase CLI + Docker

## Key Design Decisions

**Why JSONB for workouts?**
Flexibility. Users can add supersets, tempo, notes, rest times without schema migrations.

**Why incremental aggregation?**
Performance. Calculate history only for changed dates, not full table scans.

**Why RPC functions?**
Encapsulation. Complex operations (aggregation, JSON updates) run server-side with transactional safety.

**Why single active workout?**
UX simplicity. "What's my workout today?" always has one answer.

## Roadmap

- [ ] Progressive overload suggestions
- [ ] Workout template library
- [ ] Exercise PR tracking
- [ ] Multi-user support
- [ ] Analytics dashboard
- [ ] Mobile-optimized interface

## Contributing

This is a personal project, but suggestions are welcome! Open an issue or submit a PR.

## License

MIT License - see [LICENSE](./LICENSE)

## Resources

- [Supabase Documentation](https://supabase.com/docs)
- [OpenAPI 3.1 Specification](https://swagger.io/specification/)
- [Custom GPT Guide](https://help.openai.com/en/articles/8554397-creating-a-gpt)
- [PostgreSQL JSONB](https://www.postgresql.org/docs/current/datatype-json.html)

---

**Built with ❤️ for lifters who love data-driven training.**
