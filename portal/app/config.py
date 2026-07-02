"""
App configuration, read from environment variables.

Everything auth-related is optional: if ENTRA_CLIENT_ID isn't set, the
app runs in "open" mode (no login) — handy for local development and the
in-memory learning setup. As soon as ENTRA_CLIENT_ID is present (i.e. in
the deployed Container App), authentication is enforced. Same
config-driven switch idea as the data-layer backend.
"""

import os


class Settings:
    # --- Sign in with Microsoft (Entra multi-tenant app) ---
    entra_client_id: str = os.environ.get("ENTRA_CLIENT_ID", "")
    entra_client_secret: str = os.environ.get("ENTRA_CLIENT_SECRET", "")
    # /organizations = any Microsoft work/school tenant (not personal
    # accounts). This is what makes it multi-tenant "sign in with your
    # own Office 365".
    entra_authority: str = os.environ.get(
        "ENTRA_AUTHORITY", "https://login.microsoftonline.com/organizations"
    )
    # Must exactly match a redirect URI registered on the app.
    redirect_uri: str = os.environ.get(
        "ENTRA_REDIRECT_URI", "http://localhost:8000/auth/callback"
    )
    # Signs the session cookie. Set a strong random value in production.
    session_secret: str = os.environ.get("SESSION_SECRET", "dev-only-insecure-change-me")

    @property
    def auth_enabled(self) -> bool:
        """Auth is on whenever a client id is configured."""
        return bool(self.entra_client_id)


settings = Settings()
