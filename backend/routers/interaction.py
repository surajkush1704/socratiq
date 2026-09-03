from fastapi import APIRouter, HTTPException
from models.session import InteractRequest, InteractResponse
from orchestrator import handle_interaction

router = APIRouter()


@router.post('/interact', response_model=InteractResponse)
async def interact(request: InteractRequest):
    try:
        print(f'[INTERACT ROUTER] session={request.session_id[:8]}, '
              f'type={request.interaction_type}')
        response = await handle_interaction(request)
        return response
    except Exception as e:
        print(f'[INTERACT ROUTER] Error: {e}')
        raise HTTPException(status_code=500, detail=str(e))