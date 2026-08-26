import os
from urllib.parse import quote_plus

from dotenv import load_dotenv

load_dotenv()


class Config:
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = int(os.getenv("DB_PORT", "3306"))
    DB_USER = os.getenv("DB_USER", "rapidcare_user")
    DB_PASSWORD = os.getenv("DB_PASSWORD", "")
    DB_NAME = os.getenv("DB_NAME", "rapidcare_db")
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
    SQLALCHEMY_TRACK_MODIFICATIONS = (
        os.getenv("SQLALCHEMY_TRACK_MODIFICATIONS", "False").lower()
        in ("1", "true", "yes")
    )

    @property
    def SQLALCHEMY_DATABASE_URI(self):
        if not self.DB_PASSWORD:
            raise ValueError(
                "DB_PASSWORD is required in the environment. "
                "Create a .env file from .env.example and set a secure password."
            )

        db_user = quote_plus(self.DB_USER)
        db_password = quote_plus(self.DB_PASSWORD)

        return (
            f"mysql+pymysql://{db_user}:{db_password}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}?charset=utf8mb4"
        )


config = Config()