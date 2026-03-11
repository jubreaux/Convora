from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import PlainTextResponse
import uvicorn


app = FastAPI(title="Convora Basic API", version="0.1.0")

# Allow local frontends to access this API during development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    """Simple health check endpoint."""
    return {"status": "ok"}


@app.get("/greet/{name}", response_class=PlainTextResponse)
async def greet(name: str):
    """Return a plain-text greeting for the given name."""
    return PlainTextResponse(f"Hello, {name}")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, log_level="info")
