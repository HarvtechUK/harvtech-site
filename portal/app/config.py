"""
App configuration, read from environment variables.

Auth is optional ONLY for local learning: if ENTRA_CLIENT_ID isn't set,
the app runs in "open" mode (no login) against the in-memory store. As
soon as ENTRA_CLIENT_ID is present (i.e. in the deployed Container App),
authentication is enforced. Same config-driven switch idea as the
data-layer backend.

The catch with a switch like that is it can fail OPEN: lose one
environment variable in production and the login quietly disappears.
check_safe_to_start() below closes that gap. It runs before the app
is built and refuses to start at all in a configuration that would
expose real data.
"""

import os

# The fallback session secret. Fine for a laptop; in production it would
# let anyone who has read this file forge a signed-in session cookie.
DEV_SESSION_SECRET = "dev-only-insecure-change-me"


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
    session_secret: str = os.environ.get("SESSION_SECRET", DEV_SESSION_SECRET)

    # --- Data ---
    # Same variable store.py uses to pick Cosmos over the in-memory store.
    cosmos_endpoint: str = os.environ.get("COSMOS_ENDPOINT", "")

    @property
    def auth_enabled(self) -> bool:
        """Auth is on whenever a client id is configured."""
        return bool(self.entra_client_id)

    @property
    def uses_real_data(self) -> bool:
        """True when the app is wired to Cosmos rather than throwaway in-memory data."""
        return bool(self.cosmos_endpoint)


class UnsafeConfiguration(RuntimeError):
    """Raised at startup when the configuration would expose real data."""


def check_safe_to_start(config: Settings) -> None:
    """Fail closed: refuse to start rather than serve real data unsafely.

    Raising here stops uvicorn before it accepts a single request. On
    Container Apps that means the new revision never becomes healthy, so
    the previous (correctly configured) revision keeps serving traffic.
    A misconfiguration becomes a failed deploy instead of an open portal.
    """
    if config.uses_real_data and not config.auth_enabled:
        raise UnsafeConfiguration(
            "COSMOS_ENDPOINT is set but ENTRA_CLIENT_ID is not: refusing to "
            "serve real data without sign-in. Set the ENTRA_* variables, or "
            "unset COSMOS_ENDPOINT to run open mode on the in-memory store."
        )
    if config.auth_enabled and config.session_secret == DEV_SESSION_SECRET:
        raise UnsafeConfiguration(
            "Sign-in is enabled but SESSION_SECRET is the development default, "
            "so session cookies could be forged. Set SESSION_SECRET to a long "
            "random value."
        )


settings = Settings()
