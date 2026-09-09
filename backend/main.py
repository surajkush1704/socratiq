import os
import sys

# Ensure current directory is on sys.path for serverless environments (e.g. Vercel)
_current_dir = os.path.dirname(os.path.abspath(__file__))
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)

import logging
import traceback
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

# Suppress verbose logs in production
is_production = os.getenv('ENV', 'development') == 'production'
if is_production:
    logging.getLogger('httpx').setLevel(logging.WARNING)
    logging.getLogger('httpcore').setLevel(logging.WARNING)
    logging.getLogger('uvicorn.access').setLevel(logging.WARNING)

app = FastAPI(
    title='Socratiq Backend v3',
    docs_url=None if is_production else '/docs',
    redoc_url=None if is_production else '/redoc',
    openapi_url=None if is_production else '/openapi.json',
)

# Custom Rate Limit Middleware (X-RateLimit headers and login throttling)
try:
    from middleware.rate_limit import RateLimitMiddleware
    app.add_middleware(RateLimitMiddleware)
except Exception as e:
    print(f'[MAIN] RateLimitMiddleware warning: {e}')

# Restrict CORS in production if ALLOWED_ORIGINS is configured
allowed_origins = ['*']
if is_production:
    env_origins = os.getenv('ALLOWED_ORIGINS')
    if env_origins:
        allowed_origins = [o.strip() for o in env_origins.split(',') if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_methods=['*'],
    allow_headers=['*'],
)

startup_errors = []

for router_name in ['auth', 'content', 'interaction', 'session', 'sync', 'voice']:
    try:
        mod = __import__(f'routers.{router_name}', fromlist=['router'])
        app.include_router(mod.router, prefix=f'/{router_name}', tags=[router_name])
    except Exception as e:
        err_msg = f'Failed to load router {router_name}: {e}\n{traceback.format_exc()}'
        print(f'[MAIN] Error loading router {router_name}: {err_msg}')
        startup_errors.append(err_msg)


@app.get('/')
def root():
    response = {
        'status': 'Socratiq backend running',
        'version': '4.0.0',
        'voice': 'enabled',
    }
    if startup_errors:
        response['startup_errors'] = startup_errors
    return response