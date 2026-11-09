import uuid
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from .db import Base
def uid(): return str(uuid.uuid4())
class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255)); full_name: Mapped[str] = mapped_column(String(120))
    personal_tenant_id: Mapped[str] = mapped_column(String(36), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
class Membership(Base):
    __tablename__ = "memberships"; __table_args__ = (UniqueConstraint("tenant_id", "user_id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid)
    tenant_id: Mapped[str] = mapped_column(String(36), index=True); user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True); role: Mapped[str] = mapped_column(String(30), default="member")
class Project(Base):
    __tablename__ = "projects"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid); tenant_id: Mapped[str] = mapped_column(String(36), index=True)
    name: Mapped[str] = mapped_column(String(180)); description: Mapped[str] = mapped_column(Text, default=""); status: Mapped[str] = mapped_column(String(30), default="active"); created_by: Mapped[str] = mapped_column(String(36))
class Task(Base):
    __tablename__ = "tasks"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid); tenant_id: Mapped[str] = mapped_column(String(36), index=True); project_id: Mapped[str] = mapped_column(ForeignKey("projects.id"), index=True)
    title: Mapped[str] = mapped_column(String(180)); status: Mapped[str] = mapped_column(String(30), default="todo"); progress: Mapped[int] = mapped_column(Integer, default=0); assignee_id: Mapped[str | None] = mapped_column(String(36), nullable=True); due_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=uid); tenant_id: Mapped[str] = mapped_column(String(36), index=True); actor_id: Mapped[str] = mapped_column(String(36)); action: Mapped[str] = mapped_column(String(80)); entity_type: Mapped[str] = mapped_column(String(40)); entity_id: Mapped[str] = mapped_column(String(36)); created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
