# Docker Compose Setup (backend + MariaDB)

Overview
--------
This Compose setup runs the Convora FastAPI backend in a container with a separate MariaDB database container. Data from disk and a named volume are mounted so you can iterate quickly by restarting containers.

What it does
- Builds a local `convora-backend:local` image from `backend/Dockerfile`.
- Starts a `mariadb:latest` database service with auto-initialization.
- Mounts the following from the host into the backend container:
  - `./backend` → `/app/backend` (source code and app package)
  - `./SeedData` → `/app/backend/SeedData` (seed JSON and finetune lines)
  - `./backend/.env` → `/app/backend/.env` (environment variables, includes DATABASE_URL)
- Persists MariaDB data in a Docker named volume `mariadb_data:/var/lib/mysql` (survives container restarts and `docker-compose down`).

Setup
-----
1. Copy the env example and fill in keys:

```bash
cp backend/.env.example backend/.env
# Edit backend/.env and add ANTHROPIC_API_KEY, JWT_SECRET, etc.
# DATABASE_URL should be: mysql+pymysql://convora:convora_password@mariadb:3306/convora
```

2. Ensure the `SeedData` directory exists and contains the JSON files from the repo root. If you maintain seed data elsewhere, copy it into `SeedData/`.

Run (build + start)
-------------------
From the project root run:

```bash
docker-compose down        # Stop any running containers
docker-compose up --build  # Build and start MariaDB and backend
```

The backend will wait for MariaDB to be healthy before starting (via `depends_on`). First run initializes MariaDB (~5-10s), then the backend creates tables and seeds data.

Verify
------
- Backend health: `curl http://localhost:8000/health` should return `{"status":"ok"}`
- MariaDB tables: `docker compose exec mariadb mysql -u root -p convora -e "SHOW TABLES;"` (password: `root`)

Notes & Tips
-----------
- The Compose mount `./backend` means changes to Python files will be visible inside the container. Restart the container to pick up changes.
- `seed_database()` runs on app startup; it will skip if the DB appears seeded (checks for existing data). To reset MariaDB entirely: stop Compose, delete the volume, and restart.
  ```bash
  docker-compose down
  docker volume rm convora_mariadb_data  # Deletes MariaDB data
  docker-compose up --build              # Rebuilds and re-seeds fresh
  ```
- SQLite database file `backend/convora.db` is no longer used; you can delete it if present (`rm backend/convora.db`).
- MariaDB credentials are set in `docker-compose.yml` for development convenience. For production, use Docker secrets or environment files.
- If you prefer automatic Python reloading, change the container start command to use `uvicorn main:app --reload --host 0.0.0.0 --port 8000` (note that `--reload` watches files and can be slower).
- If ports conflict, update `docker-compose.yml` port mappings (backend: `8000:8000`, MariaDB: `3306:3306`).

Troubleshooting
---------------
- Backend fails to connect to MariaDB: Check that `DATABASE_URL` in `backend/.env` matches the Compose service (`mysql+pymysql://convora:convora_password@mariadb:3306/convora`).
- MariaDB doesn't start: Check logs with `docker compose logs mariadb`. First startup may take 5-10s for initialization.
- Permission errors mounting files: ensure your user owns the host files or adjust permissions.
- To inspect MariaDB: `docker compose exec mariadb mysql -u root -p` (password: `root`) then `USE convora; SHOW TABLES;`
