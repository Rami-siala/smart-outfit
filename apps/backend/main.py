from fastapi import FastAPI
from db import ping_db


app = FastAPI(title="Smart Outfit API")

@app.get("/health")
def health():
    return {"status": "ok"}
@app.get("/db-health")
def db_health():
    return {"db": "ok" if ping_db() else "down"}