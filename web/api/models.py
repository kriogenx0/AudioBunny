from sqlmodel import SQLModel, Field, Relationship
from typing import Optional, List
from datetime import datetime
import uuid


# ── Users ──────────────────────────────────────────────────────────────────

class UserBase(SQLModel):
    email: str = Field(unique=True, index=True)
    username: str = Field(unique=True, index=True)


class User(UserBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    hashed_password: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    favorites: List["Favorite"] = Relationship(back_populates="user")


class UserCreate(SQLModel):
    email: str
    username: str
    password: str


class UserRead(SQLModel):
    id: str
    email: str
    username: str
    created_at: datetime


# ── Plugins ────────────────────────────────────────────────────────────────

class PluginBase(SQLModel):
    name: str = Field(index=True)
    manufacturer: str = Field(index=True)
    plugin_type: str = Field(index=True)  # "Audio Unit" | "VST 2" | "VST 3"
    description: Optional[str] = None
    version: Optional[str] = None
    tags: Optional[str] = None           # comma-separated
    thumbnail_url: Optional[str] = None
    download_url: Optional[str] = None   # relative path served by API
    file_size_bytes: Optional[int] = None
    is_free: bool = True
    price_usd: Optional[float] = None


class Plugin(PluginBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    favorites: List["Favorite"] = Relationship(back_populates="plugin")


class PluginRead(PluginBase):
    id: str
    created_at: datetime
    favorited: bool = False  # populated per-request when user is authenticated


# ── Favorites ──────────────────────────────────────────────────────────────

class Favorite(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="user.id", index=True)
    plugin_id: str = Field(foreign_key="plugin.id", index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    user: Optional[User] = Relationship(back_populates="favorites")
    plugin: Optional[Plugin] = Relationship(back_populates="favorites")


# ── Auth tokens ────────────────────────────────────────────────────────────

class Token(SQLModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(SQLModel):
    user_id: Optional[str] = None
