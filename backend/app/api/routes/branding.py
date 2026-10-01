import os

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.models import BrandingPreset, User
from app.db.session import get_db
from app.schemas.schemas import BrandingPresetIn, BrandingPresetOut
from app.services import storage

router = APIRouter(prefix="/api/branding", tags=["branding"])

ASSET_KINDS = {"logo", "watermark", "intro", "outro"}


@router.get("", response_model=list[BrandingPresetOut])
def list_presets(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(BrandingPreset).filter_by(user_id=user.id).all()


@router.post("", response_model=BrandingPresetOut)
def create_preset(payload: BrandingPresetIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if payload.is_default:
        db.query(BrandingPreset).filter_by(user_id=user.id).update({"is_default": False})
    preset = BrandingPreset(user_id=user.id, **payload.model_dump())
    db.add(preset)
    db.commit()
    db.refresh(preset)
    return preset


@router.patch("/{preset_id}", response_model=BrandingPresetOut)
def update_preset(preset_id: str, payload: BrandingPresetIn, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    preset = db.get(BrandingPreset, preset_id)
    if not preset or preset.user_id != user.id:
        raise HTTPException(404, "Preset not found")
    if payload.is_default:
        db.query(BrandingPreset).filter_by(user_id=user.id).update({"is_default": False})
    for key, value in payload.model_dump().items():
        setattr(preset, key, value)
    db.commit()
    db.refresh(preset)
    return preset


@router.delete("/{preset_id}")
def delete_preset(preset_id: str, user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    preset = db.get(BrandingPreset, preset_id)
    if not preset or preset.user_id != user.id:
        raise HTTPException(404, "Preset not found")
    db.delete(preset)
    db.commit()
    return {"ok": True}


@router.post("/assets/{kind}")
def upload_asset(kind: str, file: UploadFile, user: User = Depends(get_current_user)):
    if kind not in ASSET_KINDS:
        raise HTTPException(400, f"kind must be one of {sorted(ASSET_KINDS)}")
    dest_dir = storage.branding_dir(user.id)
    filename = storage.new_filename(file.filename or f"{kind}.png")
    dest_path = os.path.join(dest_dir, filename)
    with open(dest_path, "wb") as out:
        out.write(file.file.read())
    return {"path": dest_path}
