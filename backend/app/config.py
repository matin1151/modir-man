from pydantic_settings import BaseSettings, SettingsConfigDict
class Settings(BaseSettings):
    database_url: str = "sqlite+aiosqlite:///./kartabel.db"
    jwt_secret: str = "change-me-in-production"
    jwt_expire_minutes: int = 60
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
settings = Settings()
