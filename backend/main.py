import logging
import os
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from middleware.rate_limit import RateLimitMiddleware
from routers import auth, content, interaction, session, sync, voice

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
app.add_middleware(RateLimitMiddleware)

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

app.include_router(auth.router, prefix='/auth', tags=['auth'])
app.include_router(content.router, prefix='/content', tags=['content'])
app.include_router(session.router, prefix='/session', tags=['session'])
app.include_router(interaction.router, prefix='/interaction', tags=['interaction'])
app.include_router(sync.router, prefix='/sync', tags=['sync'])
app.include_router(voice.router, prefix='/voice', tags=['voice'])


@app.get('/')
def root():
    return {
        'status': 'Socratiq backend running',
        'version': '4.0.0',
        'voice': 'enabled',
    }