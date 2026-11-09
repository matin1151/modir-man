import os
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./test_kartabel.db"
from fastapi.testclient import TestClient
from backend.app.main import app

def test_health():
    with TestClient(app) as client:
        assert client.get('/health').json()['status'] == 'ok'

def test_register_and_project_is_tenant_scoped():
    with TestClient(app) as client:
        response = client.post('/api/v1/auth/register', json={'email':'a@example.com','password':'password123','full_name':'آزمایشی'})
        assert response.status_code == 201
        token = response.json()['access_token']
        from backend.app.models import User
        from backend.app.db import SessionLocal
        import asyncio
        async def get_tenant():
            async with SessionLocal() as db:
                from sqlalchemy import select
                return (await db.scalar(select(User).where(User.email=='a@example.com'))).personal_tenant_id
        tenant = asyncio.run(get_tenant())
        headers={'Authorization':f'Bearer {token}'}
        created = client.post(f'/api/v1/projects?tenant_id={tenant}', json={'name':'پروژه اول'}, headers=headers)
        assert created.status_code == 201
        assert client.get('/api/v1/projects?tenant_id=other', headers=headers).status_code == 403
        task = client.post(f'/api/v1/tasks?tenant_id={tenant}', json={'project_id': created.json()['id'], 'title': 'کار اول'}, headers=headers)
        assert task.status_code == 201
        assert len(client.get(f'/api/v1/tasks?tenant_id={tenant}', headers=headers).json()) == 1
        second = client.post('/api/v1/auth/register', json={'email':'b@example.com','password':'password123','full_name':'کاربر دوم'})
        other_headers = {'Authorization': f"Bearer {second.json()['access_token']}"}
        assert client.get(f'/api/v1/tasks?tenant_id={tenant}', headers=other_headers).status_code == 403
        assert client.patch(f"/api/v1/tasks/{task.json()['id']}?tenant_id={tenant}", json={'status':'done'}, headers=other_headers).status_code == 403
        assert client.patch(f"/api/v1/tasks/{task.json()['id']}?tenant_id={tenant}", json={'status':'invalid'}, headers=headers).status_code == 422
