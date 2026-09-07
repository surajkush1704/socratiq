from fastapi import APIRouter, HTTPException
from models.session import InteractRequest, InteractResponse
from orchestrator import handle_interaction, get_session
from middleware.cost_guard import (
    enforce_daily_quota,
    validate_text_input,
    MAX_OUTPUT_TOKENS,
)

router = APIRouter()


@router.post('/interact', response_model=InteractResponse)
async def interact(request: InteractRequest):
    try:
        # Validate input length
        validate_text_input(request.user_input, max_chars=2000)

        # Enforce daily AI quota — 200 interactions per user per day
        # Extract uid from session state
        state = get_session(request.session_id)
        if state and state.user_id:
            enforce_daily_quota(
                uid=state.user_id,
                resource='ai_interaction',
                limit=200,
            )

        print(f'[INTERACT ROUTER] session={request.session_id[:8]}, '
              f'type={request.interaction_type}')
        response = await handle_interaction(request)
        return response
    except HTTPException:
        raise
    except Exception as e:
        print(f'[INTERACT ROUTER] Error: {e}')
        raise HTTPException(status_code=500, detail='Interaction failed')