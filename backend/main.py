from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from routers import content, session, interaction, sync, voice

load_dotenv()

app = FastAPI(title='Socratiq Backend v3')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)

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