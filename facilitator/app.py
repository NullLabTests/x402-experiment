from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import os
import time
import random

app = FastAPI()

# Configuration from environment variables
CHAOS_REJECT_VALID = os.getenv("CHAOS_REJECT_VALID", "false").lower() == "true"
CHAOS_SETTLE_FAIL = os.getenv("CHAOS_SETTLE_FAIL", "false").lower() == "true"
CHAOS_DELAY_MS = int(os.getenv("CHAOS_DELAY_MS", "0"))

# In-memory ledger for paper trades
ledger = {}

@app.get("/verify")
async def verify():
    """Verify endpoint for x402 payment authorization"""
    if CHAOS_REJECT_VALID:
        return JSONResponse(status_code=403, content={"error": "validation rejected by chaos"})
    return {"status": "ok", "message": "payment authorized"}

@app.post("/settle")
async def settle():
    """Settle endpoint for x402 payment finalization"""
    if CHAOS_SETTLE_FAIL:
        return JSONResponse(status_code=500, content={"error": "settlement failed by chaos"})
    
    delay = CHAOS_DELAY_MS / 1000.0
    if delay > 0:
        time.sleep(delay)
    
    return {"status": "settled", "message": "payment settled successfully"}