# Convora Backend - Minimal FastAPI Service

Install requirements and run the development server:

```bash
python -m pip install -r backend/requirements.txt
uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Health check: GET http://localhost:8000/health
