from fastapi import APIRouter, Depends, Query
from ..core.deps import current_db, current_user
from ..models.therapist import TherapistCreate, TherapistRepo, TherapistPublic

router = APIRouter()

@router.post("", response_model=TherapistPublic, summary="Alta de terapeuta (portal admin)")
async def create_therapist(payload: TherapistCreate, db=Depends(current_db), user=Depends(current_user)):
    # Autorización básica: solo admin/terapeuta podrían registrar (ajusta a tu política)
    if user["role"] not in ("admin", "terapeuta"):
        from fastapi import HTTPException, status
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado")
    repo = TherapistRepo(db)
    return await repo.create(payload)

@router.get("/search", response_model=list[TherapistPublic], summary="Buscar en el directorio")
async def search(
    specialty: str | None = Query(default=None),
    region: str | None = Query(default=None),
    convenio: bool | None = Query(default=None),
    db=Depends(current_db)
):
    repo = TherapistRepo(db)
    return await repo.search(specialty, region, convenio)
