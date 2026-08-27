import os
from pathlib import Path
from urllib.parse import quote_plus

from dotenv import load_dotenv

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
INSTANCE_DIR = BASE_DIR / "instance"
INSTANCE_DIR.mkdir(parents=True, exist_ok=True)


class Config:
    BASE_DIR = BASE_DIR
    INSTANCE_DIR = INSTANCE_DIR
    DB_HOST = os.getenv("DB_HOST")
    DB_PORT = int(os.getenv("DB_PORT", "3306"))
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")
    DB_NAME = os.getenv("DB_NAME")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
    CORS_ORIGINS = os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5000,http://127.0.0.1:3000,http://127.0.0.1:5000",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = (
        os.getenv("SQLALCHEMY_TRACK_MODIFICATIONS", "False").lower()
        in ("1", "true", "yes")
    )

    @property
    def SQLALCHEMY_DATABASE_URI(self):
        mysql_ready = (
            bool(self.DB_HOST)
            and bool(self.DB_USER)
            and bool(self.DB_NAME)
            and self.DB_PASSWORD is not None
        )

        if mysql_ready:
            db_user = quote_plus(self.DB_USER)
            db_password = quote_plus(self.DB_PASSWORD)
            return (
                f"mysql+pymysql://{db_user}:{db_password}"
                f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}?charset=utf8mb4"
            )

        sqlite_path = (self.INSTANCE_DIR / "rapidcare.db").resolve()
        return f"sqlite:///{sqlite_path}"


config = Config()