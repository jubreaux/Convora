from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application configuration from environment variables."""
    
    ANTHROPIC_API_KEY: str
    JWT_SECRET: str
    OPENAI_API_KEY: str = ""  # Optional; required for voice mode
    DATABASE_URL: str = "mysql+pymysql://convora:convora_password@mariadb:3306/convora"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings singleton."""
    return Settings()
