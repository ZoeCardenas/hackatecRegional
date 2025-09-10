"""
Cálculo de puntuaciones DASS-21.
Reglas y umbrales: ajusta según guía clínica que adoptes.
"""
from .typing import RiskLevel
from ..models.assessment import Dass21Submit, Dass21Score

# Índices de items por subescala (ejemplo típico DASS-21)
DEP_IDX = [2,4,8,9,12,15,19]
ANX_IDX = [1,3,6,7,10,13,14]
STR_IDX = [0,5,11,16,17,18,20]

def compute_score(payload: Dass21Submit) -> Dass21Score:
    answers = payload.answers
    D = sum(answers[i] for i in DEP_IDX) * 2
    A = sum(answers[i] for i in ANX_IDX) * 2
    S = sum(answers[i] for i in STR_IDX) * 2
    total = D + A + S
    risk = _risk_from_scores(D, A, S, total)
    return Dass21Score(D=D, A=A, S=S, total=total, risk_level=risk)

def _risk_from_scores(D: int, A: int, S: int, total: int) -> RiskLevel:
    """
    Umbrales orientativos:
    - <20 bajo, 20–33 medio, 34–48 alto, >48 crítico (total)
    Ajusta a tu protocolo clínico.
    """
    if total < 20: return 0
    if total <= 33: return 1
    if total <= 48: return 2
    return 3
