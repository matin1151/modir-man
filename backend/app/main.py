from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select
from .auth import current_user, hash_password, issue_token, require_membership, verify_password
from .db import Base, engine, get_db
from .models import AuditLog, Membership, Project, Task, User, uid
from .schemas import *
@asynccontextmanager
async def lifespan(app):
    async with engine.begin() as conn: await conn.run_sync(Base.metadata.create_all)
    yield
app = FastAPI(title="کارتابل API", version="1.0.0", lifespan=lifespan)
@app.get("/health")
async def health(): return {"status": "ok", "service": "kartabel-api"}
@app.post("/api/v1/auth/register", response_model=TokenOut, status_code=201)
async def register(data: RegisterIn, db=Depends(get_db)):
    if await db.scalar(select(User).where(User.email == data.email.lower())): raise HTTPException(409, "ایمیل قبلاً ثبت شده است")
    tenant = uid(); user_id = uid(); user = User(id=user_id, email=data.email.lower(), password_hash=hash_password(data.password), full_name=data.full_name, personal_tenant_id=tenant)
    db.add_all([user, Membership(tenant_id=tenant, user_id=user_id, role="owner")]); await db.commit()
    return TokenOut(access_token=issue_token(user.id))
@app.post("/api/v1/auth/login", response_model=TokenOut)
async def login(data: LoginIn, db=Depends(get_db)):
    user = await db.scalar(select(User).where(User.email == data.email.lower()))
    if not user or not verify_password(data.password, user.password_hash): raise HTTPException(401, "ایمیل یا رمز عبور نادرست است")
    return TokenOut(access_token=issue_token(user.id))
@app.get("/api/v1/me")
async def me(user=Depends(current_user)):
    return {"id": user.id, "full_name": user.full_name, "email": user.email, "personal_tenant_id": user.personal_tenant_id}
@app.get("/api/v1/projects", response_model=list[ProjectOut])
async def projects(tenant_id: str, q: str | None = None, user=Depends(current_user), db=Depends(get_db)):
    await require_membership(user, db, tenant_id); stmt = select(Project).where(Project.tenant_id == tenant_id)
    if q: stmt = stmt.where(Project.name.ilike(f"%{q}%"))
    return list((await db.scalars(stmt.order_by(Project.name))).all())
@app.post("/api/v1/projects", response_model=ProjectOut, status_code=201)
async def create_project(data: ProjectIn, tenant_id: str, user=Depends(current_user), db=Depends(get_db)):
    m = await require_membership(user, db, tenant_id)
    if m.role not in {"owner", "admin", "manager"}: raise HTTPException(403, "نقش شما اجازه ساخت پروژه ندارد")
    item = Project(id=uid(), tenant_id=tenant_id, name=data.name, description=data.description, created_by=user.id)
    db.add(item); db.add(AuditLog(tenant_id=tenant_id, actor_id=user.id, action="project.created", entity_type="project", entity_id=item.id)); await db.commit(); await db.refresh(item); return item
@app.post("/api/v1/tasks", response_model=TaskOut, status_code=201)
async def create_task(data: TaskIn, tenant_id: str, user=Depends(current_user), db=Depends(get_db)):
    membership = await require_membership(user, db, tenant_id)
    if membership.role not in {"owner", "admin", "manager"}: raise HTTPException(403, "نقش شما اجازه ساخت وظیفه ندارد")
    if not await db.scalar(select(Project).where(Project.id == data.project_id, Project.tenant_id == tenant_id)): raise HTTPException(404, "پروژه پیدا نشد")
    if data.assignee_id and not await db.scalar(select(Membership).where(Membership.tenant_id == tenant_id, Membership.user_id == data.assignee_id)): raise HTTPException(422, "مسئول عضو این فضا نیست")
    item = Task(id=uid(), tenant_id=tenant_id, **data.model_dump()); db.add(item); db.add(AuditLog(tenant_id=tenant_id, actor_id=user.id, action="task.created", entity_type="task", entity_id=item.id)); await db.commit(); await db.refresh(item); return item
@app.get("/api/v1/tasks", response_model=list[TaskOut])
async def tasks(tenant_id: str, project_id: str | None = None, status: str | None = None, q: str | None = None, user=Depends(current_user), db=Depends(get_db)):
    await require_membership(user, db, tenant_id)
    stmt = select(Task).where(Task.tenant_id == tenant_id)
    if project_id: stmt = stmt.where(Task.project_id == project_id)
    if status: stmt = stmt.where(Task.status == status)
    if q: stmt = stmt.where(Task.title.ilike(f"%{q}%"))
    return list((await db.scalars(stmt.order_by(Task.due_date, Task.title))).all())
@app.patch("/api/v1/tasks/{task_id}", response_model=TaskOut)
async def patch_task(task_id: str, data: TaskPatch, tenant_id: str, user=Depends(current_user), db=Depends(get_db)):
    membership = await require_membership(user, db, tenant_id); item = await db.scalar(select(Task).where(Task.id == task_id, Task.tenant_id == tenant_id))
    if not item: raise HTTPException(404, "وظیفه پیدا نشد")
    if membership.role not in {"owner", "admin", "manager"} and item.assignee_id != user.id: raise HTTPException(403, "مجوز ویرایش این وظیفه را ندارید")
    if data.status is None and 'status' in data.model_fields_set: raise HTTPException(422, "وضعیت نمی‌تواند خالی باشد")
    for key, value in data.model_dump(exclude_unset=True).items(): setattr(item, key, value)
    db.add(AuditLog(tenant_id=tenant_id, actor_id=user.id, action="task.updated", entity_type="task", entity_id=item.id)); await db.commit(); await db.refresh(item); return item
