# app/routes/directory.py
"""
Wrapper del directorio que reutiliza TherapistRepo con parámetros más “amigables”.
Sirve como alias público; /therapists/search ya existe pero esto alinea el contrato “/directory”.
"""
from fastapi import APIRouter, Depends, Query
from ..core.deps import current_db
from ..models.therapist import TherapistRepo

router = APIRouter()

@router.get("/search", summary="Buscar terapeutas por especialidad/región/convenio")
async def directory_search(
    q: str | None = Query(default=None, description="Texto: especialidad, región o nombre"),
    specialty: str | None = None,
    region: str | None = None,
    convenio: bool | None = None,
    limit: int = 20,
    db=Depends(current_db),
):
    repo = TherapistRepo(db)

    # Si viene q y NO vienen specialty/region explícitos, usamos q para ambos
    # para activar el OR interno (specialties/regions/name).
    if q and not (specialty or region):
        specialty = q
        region = q

    return await repo.search(specialty, region, convenio, limit=limit)
