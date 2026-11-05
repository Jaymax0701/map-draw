# Map Draw

**Map. Measure. Plan. Manage.**

Map Draw is a collaborative, multi-purpose GIS and spatial planning platform for individuals, businesses and organisations. It helps users visualise, measure, analyse and manage geographic information, from simple site measurements to land development, infrastructure planning and industrial projects.

## Technology
- React + Vite + TypeScript
- MapLibre GL JS for interactive maps
- Turf.js for client-side spatial calculations
- Supabase (PostgreSQL + PostGIS, Auth and Storage)
- Vercel for deployment

## Development status
Early foundation stage. Authentication, organisation/project access control, GIS editing and persistence are planned in staged releases.

## Getting started

```bash
npm install
npm run dev
```

Copy `.env.example` to `.env.local` and configure the Supabase project before enabling backend features.

## Security principles
- Organisation and project access must be enforced by PostgreSQL Row Level Security.
- Never expose Supabase service-role credentials in the browser.
- Keep uploaded project documents in private storage buckets.
- Do not store confidential production data until access policies and deployment controls have been reviewed.

## License
To be determined.

## Basemap note

The current development preview uses OpenStreetMap's public raster tile endpoint for demonstration. That public endpoint is not a production tile hosting service and must not be treated as one. Before public or commercial deployment, select a tile provider or self-hosted service, review its attribution, licensing, caching and usage terms, and configure the MapLibre style accordingly.

## Current scope

The current UI is an early workspace shell. Drawing, measurement persistence, authentication screens, organisation/project management and production basemap configuration are not yet implemented. Do not enter sensitive or operational data in this preview.
