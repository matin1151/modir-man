from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from .config import settings
from .models import User, Membership
from .db import get_db
pwd = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
oauth2 = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
def hash_password(v): return pwd.hash(v)
def verify_password(v, h): return pwd.verify(v, h)
def issue_token(user_id):
    exp = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    return jwt.encode({"sub": user_id, "exp": exp}, settings.jwt_secret, algorithm="HS256")
async def current_user(token: str = Depends(oauth2), db=Depends(get_db)):
    error = HTTPException(status_code=401, detail="اعتبار ورود نامعتبر است")
    try: user_id = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"]).get("sub")
    except JWTError: raise error
    user = await db.get(User, user_id)
    if not user: raise error
    return user
async def require_membership(user, db, tenant_id):
    membership = await db.scalar(select(Membership).where(Membership.user_id == user.id, Membership.tenant_id == tenant_id))
    if not membership: raise HTTPException(403, "دسترسی به این فضای کاری مجاز نیست")
    return membership
