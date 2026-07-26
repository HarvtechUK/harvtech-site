"""
Sign in with Microsoft — OIDC authorization-code flow via MSAL.

The flow, end to end:
  1. An unauthenticated request hits a protected route → require_user
     bounces the browser to /auth/login.
  2. /auth/login builds a Microsoft sign-in URL and redirects there. The
     user signs in with their own Office 365 account (their MFA, their
     tenant) — we never see a password.
  3. Microsoft redirects back to /auth/callback with a code. We redeem it
     for tokens and read the user's identity claims (oid, tid, email).
  4. AUTHORISATION: authenticating only proves who they are. We then look
     them up in the users store by oid+tid. No record → no access, even
     with a valid Microsoft login. A record → we save a small session and
     let them in.

MSAL's initiate/acquire "auth code flow" helpers handle the fiddly,
security-critical bits for us — PKCE, the state/nonce, token validation —
so we don't hand-roll any of that.
"""

from pathlib import Path

import msal
from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates

from . import store
from .config import settings

router = APIRouter(tags=["auth"])

# The sign-in and access-denied pages are rendered here (not in web.py)
# because they must stay PUBLIC — they're the way in, so they can't sit
# behind the login gate that covers the web router.
templates = Jinja2Templates(directory=Path(__file__).parent / "templates")

# Empty on purpose. We never call Microsoft Graph — we only read the
# validated id_token claims (oid, tid, name, email) — so we don't ask for
# User.Read. MSAL always adds the reserved OIDC scopes (openid, profile,
# offline_access) itself. Fewer scopes = a smaller, less alarming consent
# prompt for client approvers: just "sign you in and read your profile".
_SCOPES: list[str] = []


def _msal_app() -> msal.ConfidentialClientApplication:
    """A confidential client — 'confidential' because it can keep a secret
    (it runs on our server, not in a browser). The secret is how it proves
    its own identity to Microsoft when redeeming the code."""
    return msal.ConfidentialClientApplication(
        client_id=settings.entra_client_id,
        authority=settings.entra_authority,
        client_credential=settings.entra_client_secret,
    )


@router.get("/login")
def login_page(request: Request):
    """The branded sign-in page — a HarvTech page with a 'Sign in with
    Microsoft' button, rather than bouncing visitors straight onto
    Microsoft's login with no context.

    Already signed in (or auth disabled)? Straight to the dashboard.
    """
    if not settings.auth_enabled or request.session.get("user"):
        return RedirectResponse("/", status_code=302)
    return templates.TemplateResponse(request, "login.html", {})


@router.get("/auth/login")
def login(request: Request):
    """Kick off sign-in: build the Microsoft URL and redirect to it."""
    flow = _msal_app().initiate_auth_code_flow(_SCOPES, redirect_uri=settings.redirect_uri)
    # The flow dict carries the state and PKCE verifier we must remember
    # until the callback. Stashing it in the (signed) session ties the
    # callback to this exact browser and request — that's the CSRF defence.
    request.session["auth_flow"] = flow
    return RedirectResponse(flow["auth_uri"], status_code=302)


@router.get("/auth/callback")
def callback(request: Request):
    """Microsoft redirects here with the code; redeem it and sign the user in."""
    flow = request.session.pop("auth_flow", None)
    if not flow:
        # No flow in session (expired, or a stray hit) — start over.
        return RedirectResponse("/auth/login", status_code=302)

    result = _msal_app().acquire_token_by_auth_code_flow(flow, dict(request.query_params))
    if "error" in result:
        raise HTTPException(status_code=400, detail=result.get("error_description", "Sign-in failed."))

    # id_token_claims is the validated identity. oid+tid uniquely and
    # durably identify the person and their home tenant.
    claims = result.get("id_token_claims", {})
    oid = claims.get("oid", "")
    tid = claims.get("tid", "")
    email = claims.get("preferred_username") or claims.get("email") or ""
    name = claims.get("name", "")

    # --- Authorisation gate ---
    user = store.get_user(oid, tid)
    if user is None:
        # Authenticated with a real Microsoft account, but not registered
        # as a portal user. Deny — this is the line that keeps the portal
        # private even though anyone can *authenticate*. Rendered as a
        # branded page (not raw JSON): the person seeing it is likely a
        # client whose record hasn't been set up yet.
        return templates.TemplateResponse(
            request,
            "denied.html",
            {"email": email},
            status_code=status.HTTP_403_FORBIDDEN,
        )

    # Minimal session — enough to authorise later requests without another
    # lookup, and to scope a client_approver to their own client.
    request.session["user"] = {
        "oid": oid,
        "tid": tid,
        "email": email,
        "name": name,
        "role": user.role,
        "client_id": user.client_id,
    }
    return RedirectResponse("/", status_code=302)


@router.get("/auth/logout")
def logout(request: Request):
    """Clear our session. (The Microsoft SSO session is theirs to manage.)"""
    request.session.clear()
    return RedirectResponse("/", status_code=302)


def require_user(request: Request) -> dict | None:
    """Dependency that gates protected routes.

    - Auth disabled (local/dev, no client id): allow through.
    - No session user: redirect the browser to the branded /login page
      (NOT straight to Microsoft — context first, redirect on click).
      Raising an HTTPException with a 307 + Location is how a dependency
      triggers a redirect.
    - Otherwise: return the session user so routes can read role/client.
    """
    if not settings.auth_enabled:
        return None
    user = request.session.get("user")
    if not user:
        raise HTTPException(
            status_code=status.HTTP_307_TEMPORARY_REDIRECT,
            headers={"Location": "/login"},
            detail="Login required.",
        )
    return user
