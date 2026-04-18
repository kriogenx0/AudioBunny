from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from database import get_session
from models import Favorite, Plugin, PluginRead, User
from auth import get_current_user

router = APIRouter(prefix="/api/favorites", tags=["favorites"])


def _to_plugin_read(fav: Favorite) -> PluginRead:
    return PluginRead(**fav.plugin.model_dump(), favorited=True)


@router.get("", response_model=List[PluginRead])
def list_favorites(
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    favs = session.exec(
        select(Favorite).where(Favorite.user_id == current_user.id)
    ).all()
    result = []
    for fav in favs:
        plugin = session.get(Plugin, fav.plugin_id)
        if plugin:
            result.append(PluginRead(**plugin.model_dump(), favorited=True))
    return result


@router.post("/{plugin_id}", status_code=status.HTTP_201_CREATED)
def add_favorite(
    plugin_id: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    if not session.get(Plugin, plugin_id):
        raise HTTPException(status_code=404, detail="Plugin not found")
    existing = session.exec(
        select(Favorite).where(
            Favorite.user_id == current_user.id,
            Favorite.plugin_id == plugin_id,
        )
    ).first()
    if existing:
        return {"detail": "Already favorited"}
    session.add(Favorite(user_id=current_user.id, plugin_id=plugin_id))
    session.commit()
    return {"detail": "Added to favorites"}


@router.delete("/{plugin_id}", status_code=status.HTTP_200_OK)
def remove_favorite(
    plugin_id: str,
    session: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    fav = session.exec(
        select(Favorite).where(
            Favorite.user_id == current_user.id,
            Favorite.plugin_id == plugin_id,
        )
    ).first()
    if not fav:
        raise HTTPException(status_code=404, detail="Favorite not found")
    session.delete(fav)
    session.commit()
    return {"detail": "Removed from favorites"}
