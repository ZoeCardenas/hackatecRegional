from fastapi import APIRouter, Depends
from ..core.deps import current_db, current_user
from ..models.assessment import Dass21Submit, AssessmentRepo
from ..services.scoring_dass21 import compute_score

router = APIRouter()

@router.post("/dass21", summary="Aplicar y puntuar DASS-21")
async def dass21_submit(payload: Dass21Submit, db=Depends(current_db), user=Depends(current_user)):
    score = compute_score(payload)
    repo = AssessmentRepo(db)
    _id = await repo.save(user_id=user["sub"], score=score)
    return {"assessment_id": _id, "score": score.model_dump()}

@router.get("/history", summary="Historial de DASS-21 (últimos)")
async def dass21_history(limit: int = 6, db=Depends(current_db), user=Depends(current_user)):
    repo = AssessmentRepo(db)
    return await repo.history(user_id=user["sub"], limit=limit)
