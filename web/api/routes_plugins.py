from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlmodel import Session, select

from database import get_session
from models import Plugin, PluginRead, Favorite, User
from auth import get_optional_user

router = APIRouter(prefix="/api/plugins", tags=["plugins"])


def _attach_favorited(plugins: List[Plugin], user: Optional[User], session: Session) -> List[PluginRead]:
    if not user:
        return [PluginRead(**p.model_dump(), favorited=False) for p in plugins]
    fav_ids = {
        f.plugin_id
        for f in session.exec(select(Favorite).where(Favorite.user_id == user.id)).all()
    }
    return [PluginRead(**p.model_dump(), favorited=(p.id in fav_ids)) for p in plugins]


@router.get("", response_model=List[PluginRead])
def list_plugins(
    q: Optional[str] = Query(None, description="Search name or manufacturer"),
    plugin_type: Optional[str] = Query(None, alias="type"),
    tags: Optional[str] = Query(None, description="Comma-separated tag filter (OR logic)"),
    is_free: Optional[bool] = Query(None),
    sort: str = Query("name", enum=["name", "manufacturer", "newest"]),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    session: Session = Depends(get_session),
    current_user: Optional[User] = Depends(get_optional_user),
):
    query = select(Plugin)

    if q:
        like = f"%{q}%"
        query = query.where(
            (Plugin.name.ilike(like)) | (Plugin.manufacturer.ilike(like))
        )
    if plugin_type:
        query = query.where(Plugin.plugin_type == plugin_type)
    if is_free is not None:
        query = query.where(Plugin.is_free == is_free)

    if sort == "manufacturer":
        query = query.order_by(Plugin.manufacturer, Plugin.name)
    elif sort == "newest":
        query = query.order_by(Plugin.created_at.desc())
    else:
        query = query.order_by(Plugin.name)

    plugins = session.exec(query.offset(offset).limit(limit)).all()

    # Tag filtering in Python (stored as comma-separated string)
    if tags:
        wanted = {t.strip().lower() for t in tags.split(",")}
        plugins = [
            p for p in plugins
            if p.tags and wanted.intersection(t.strip().lower() for t in p.tags.split(","))
        ]

    return _attach_favorited(plugins, current_user, session)


@router.get("/{plugin_id}", response_model=PluginRead)
def get_plugin(
    plugin_id: str,
    session: Session = Depends(get_session),
    current_user: Optional[User] = Depends(get_optional_user),
):
    plugin = session.get(Plugin, plugin_id)
    if not plugin:
        raise HTTPException(status_code=404, detail="Plugin not found")
    favorited = False
    if current_user:
        fav = session.exec(
            select(Favorite)
            .where(Favorite.user_id == current_user.id, Favorite.plugin_id == plugin_id)
        ).first()
        favorited = fav is not None
    return PluginRead(**plugin.model_dump(), favorited=favorited)
