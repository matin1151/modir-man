from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field
class RegisterIn(BaseModel): email: str; password: str = Field(min_length=8); full_name: str = Field(min_length=2, max_length=120)
class LoginIn(BaseModel): email: str; password: str
class TokenOut(BaseModel): access_token: str; token_type: str = "bearer"
class ProjectIn(BaseModel): name: str = Field(min_length=1, max_length=180); description: str = ""
class ProjectOut(ProjectIn):
    id: str; status: str
    model_config = ConfigDict(from_attributes=True)
class TaskIn(BaseModel): project_id: str; title: str; assignee_id: str | None = None; due_date: datetime | None = None
class TaskPatch(BaseModel): status: str | None = None; progress: int | None = Field(default=None, ge=0, le=100); due_date: datetime | None = None
class TaskOut(TaskIn):
    id: str; status: str; progress: int
    model_config = ConfigDict(from_attributes=True)
